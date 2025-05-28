import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add a set to track recently shown notifications to prevent duplicates
  static final Set<String> _recentNotificationIds = {};
  static bool _isInitialized = false;
  static String? _currentUserId;

  static Future<void> initialize() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      print('❌ [DEBUG] No current user, waiting for authentication');
      return;
    }

    // Check if we need to reinitialize for a different user
    if (_currentUserId != currentUser.uid) {
      print('🔔 [DEBUG] New user detected, reinitializing NotificationService');
      _isInitialized = false;
      _currentUserId = currentUser.uid;
    }

    // Prevent multiple initializations for the same user
    if (_isInitialized) {
      print(
          '🔔 [DEBUG] NotificationService already initialized for current user, skipping');
      return;
    }

    print(
        '🔔 [DEBUG] Initializing NotificationService for user: ${currentUser.uid}');

    // Create notification channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Channel',
      description: 'This channel is used for important notifications',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      enableLights: true,
    );

    // Register the channel with the system
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    print('✅ [DEBUG] Android notification channel created');

    // Initialize local notifications
    const initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettingsIOS = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('🔔 [DEBUG] Notification tapped: ${response.payload}');
        if (response.payload != null) {
          final data = jsonDecode(response.payload!);
          _handleNotificationTap(data);
        }
      },
    );

    // Request permission with retry logic
    NotificationSettings? settings;
    int retryCount = 0;
    while (settings == null && retryCount < 3) {
      try {
        settings = await _firebaseMessaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
        print(
            '🔔 [DEBUG] Notification permission status: ${settings.authorizationStatus}');
      } catch (e) {
        print('❌ [DEBUG] Error requesting notification permission: $e');
        retryCount++;
        await Future.delayed(Duration(seconds: 1));
      }
    }

    if (settings == null) {
      print('❌ [DEBUG] Failed to get notification permissions after retries');
      return;
    }

    // Set background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Clean up old user documents and tokens
    await _cleanupOldUserDocuments();

    // Get FCM token with retry logic
    String? token;
    retryCount = 0;
    while (token == null && retryCount < 3) {
      try {
        token = await _firebaseMessaging.getToken();
        if (token != null) {
          print('✅ [DEBUG] Successfully got FCM token: $token');
          await _updateCurrentUserToken();
        } else {
          print('❌ [DEBUG] FCM token is null, retrying...');
        }
      } catch (e) {
        print('❌ [DEBUG] Error getting FCM token: $e');
      }
      if (token == null) {
        retryCount++;
        await Future.delayed(Duration(seconds: 1));
      }
    }

    // Handle token refresh
    _firebaseMessaging.onTokenRefresh.listen((String newToken) {
      print('🔔 [DEBUG] FCM token refreshed: $newToken');
      _updateCurrentUserToken();
    });

    // Handle notification when app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('🔔 [DEBUG] Received foreground message:');
      print('🔔 [DEBUG] Title: ${message.notification?.title}');
      print('🔔 [DEBUG] Body: ${message.notification?.body}');
      print('🔔 [DEBUG] Data: ${message.data}');

      final String notificationId = message.messageId ??
          '${message.notification?.title}_${message.notification?.body}_${DateTime.now().millisecondsSinceEpoch}';

      if (!_recentNotificationIds.contains(notificationId)) {
        _recentNotificationIds.add(notificationId);

        Future.delayed(const Duration(seconds: 5), () {
          _recentNotificationIds.remove(notificationId);
        });

        _showNotification(
          message.notification?.title ?? 'New Notification',
          message.notification?.body ?? '',
          message.data,
        );
      } else {
        print('🔔 [DEBUG] Skipping duplicate notification: $notificationId');
      }
    });

    // Handle notification when app is in background and user taps it
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('🔔 [DEBUG] App opened from background notification:');
      print('🔔 [DEBUG] Title: ${message.notification?.title}');
      print('🔔 [DEBUG] Body: ${message.notification?.body}');
      print('🔔 [DEBUG] Data: ${message.data}');

      _handleNotificationTap(message.data);
    });

    // Check for initial notification
    RemoteMessage? initialMessage =
        await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      print('🔔 [DEBUG] App opened from terminated state:');
      print('🔔 [DEBUG] Title: ${initialMessage.notification?.title}');
      print('🔔 [DEBUG] Body: ${initialMessage.notification?.body}');
      print('🔔 [DEBUG] Data: ${initialMessage.data}');

      _handleNotificationTap(initialMessage.data);
    }

    // Mark as initialized for this user
    _isInitialized = true;
    print(
        '✅ [DEBUG] NotificationService initialization completed for user: ${currentUser.uid}');
  }

  static Future<void> _cleanupOldUserDocuments() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      print('🔔 [DEBUG] Cleaning up old FCM tokens...');

      // Get current user's document
      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();

      // Get current FCM token
      final currentToken = await _firebaseMessaging.getToken();
      if (currentToken == null) {
        print('❌ [DEBUG] Could not get current FCM token');
        return;
      }

      final batch = _firestore.batch();
      var hasUpdates = false;

      if (!userDoc.exists) {
        // Create new user document if it doesn't exist
        batch.set(_firestore.collection('users').doc(currentUser.uid), {
          'userId': currentUser.uid,
          'email': currentUser.email,
          'displayName': currentUser.displayName ?? 'Unknown',
          'fcmToken': currentToken,
          'fcmTokens': [currentToken],
          'lastTokenUpdate': FieldValue.serverTimestamp(),
          'lastActive': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        hasUpdates = true;
        print('🔔 [DEBUG] Creating new user document for: ${currentUser.uid}');
      } else {
        // Update existing user document
        final userData = userDoc.data() as Map<String, dynamic>;
        final existingTokens = List<String>.from(userData['fcmTokens'] ?? []);

        // Remove any invalid/old tokens from other devices
        if (existingTokens.isNotEmpty) {
          // Keep only the current token and remove others for this device
          // This helps prevent token buildup from the same device
          existingTokens.removeWhere((token) =>
              token != currentToken &&
              token.split(':')[0] == currentToken.split(':')[0]);
        }

        // Add current token if not present
        if (!existingTokens.contains(currentToken)) {
          existingTokens.add(currentToken);
        }

        // Update user document with cleaned up tokens
        batch.update(_firestore.collection('users').doc(currentUser.uid), {
          'userId': currentUser.uid,
          'email': currentUser.email,
          'displayName': currentUser.displayName ?? 'Unknown',
          'fcmToken': currentToken,
          'fcmTokens': existingTokens,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
          'lastActive': FieldValue.serverTimestamp(),
        });
        hasUpdates = true;
        print('🔔 [DEBUG] Updated user document with cleaned FCM tokens');
      }

      if (hasUpdates) {
        await batch.commit();
        print('✅ [DEBUG] User document and FCM tokens updated successfully');
      }
    } catch (e) {
      print('❌ [DEBUG] Error cleaning up FCM tokens: $e');
    }
  }

  static Future<void> signOut() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // Remove only the current device's FCM token before signing out
        final currentToken = await _firebaseMessaging.getToken();
        if (currentToken != null) {
          await _firestore.collection('users').doc(currentUser.uid).update({
            'fcmTokens': FieldValue.arrayRemove([currentToken]),
            'lastTokenUpdate': FieldValue.serverTimestamp(),
          });
          print(
              '✅ [DEBUG] Removed current device FCM token for user: ${currentUser.uid}');
        }
      }
      _isInitialized = false;
      _currentUserId = null;
      print('✅ [DEBUG] NotificationService cleanup completed for sign out');
    } catch (e) {
      print('❌ [DEBUG] Error during NotificationService sign out: $e');
    }
  }

  static Future<void> _updateCurrentUserToken() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('❌ [DEBUG] No current user when updating token');
        return;
      }

      String? token = await _firebaseMessaging.getToken();
      if (token == null) {
        print('❌ [DEBUG] Failed to get FCM token');
        return;
      }

      print('🔔 [DEBUG] Updating token for user ${currentUser.uid}: $token');

      // Get user document
      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();

      if (!userDoc.exists) {
        // Create new user document if it doesn't exist
        await _firestore.collection('users').doc(currentUser.uid).set({
          'userId': currentUser.uid,
          'displayName': currentUser.displayName ?? 'Unknown',
          'email': currentUser.email,
          'fcmToken': token,
          'fcmTokens': [token],
          'lastTokenUpdate': FieldValue.serverTimestamp(),
          'lastActive': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Update existing user document
        final userData = userDoc.data() as Map<String, dynamic>;
        final existingTokens = List<String>.from(userData['fcmTokens'] ?? []);

        // Add new token if not present
        if (!existingTokens.contains(token)) {
          existingTokens.add(token);
        }

        await _firestore.collection('users').doc(currentUser.uid).update({
          'fcmToken': token,
          'fcmTokens': existingTokens,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
          'lastActive': FieldValue.serverTimestamp(),
        });
      }

      print(
          '✅ [DEBUG] Token updated successfully for user: ${currentUser.uid}');
    } catch (e) {
      print('❌ [DEBUG] Error updating token: $e');
    }
  }

  static Future<void> sendNotification({
    required String recipientId,
    required String title,
    required String body,
    String type = 'default',
    String? chatId,
    String? senderId,
    String? senderName,
    String? postId,
    String? postTitle,
  }) async {
    print('🔔 [DEBUG] Sending notification:');
    print('🔔 [DEBUG] Recipient: $recipientId');
    print('🔔 [DEBUG] Title: $title');
    print('🔔 [DEBUG] Body: $body');
    print('🔔 [DEBUG] Type: $type');

    try {
      // Check if recipient user exists and has valid tokens
      final userDoc =
          await _firestore.collection('users').doc(recipientId).get();

      if (!userDoc.exists) {
        print('❌ [DEBUG] Error: Recipient user does not exist: $recipientId');
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final fcmTokens = userData['fcmTokens'] as List<dynamic>?;

      print('🔔 [DEBUG] Recipient FCM tokens: $fcmTokens');

      if (fcmTokens == null || fcmTokens.isEmpty) {
        print('❌ [DEBUG] Error: Recipient has no FCM tokens: $recipientId');
        return;
      }

      // Create notification document
      final notificationRef = await _firestore.collection('notifications').add({
        'recipientId': recipientId,
        'title': title,
        'body': body,
        'type': type,
        'chatId': chatId,
        'senderId': senderId,
        'senderName': senderName,
        'postId': postId,
        'postTitle': postTitle,
        'timestamp': FieldValue.serverTimestamp(),
        'created': DateTime.now().millisecondsSinceEpoch,
        'fcmTokens': fcmTokens, // Add FCM tokens to notification document
      });

      print(
          '✅ [DEBUG] Notification document created successfully: ${notificationRef.id}');
    } catch (e) {
      print('❌ [DEBUG] Error sending notification: $e');
      print('❌ [DEBUG] Detailed error info: $e');
    }
  }

  static void _showNotification(
      String title, String body, Map<String, dynamic> data) {
    print('🔔 [DEBUG] Showing local notification:');
    print('🔔 [DEBUG] Title: $title');
    print('🔔 [DEBUG] Body: $body');
    print('🔔 [DEBUG] Data: $data');

    const androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Channel',
      channelDescription: 'This channel is used for important notifications',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      enableLights: true,
      playSound: true,
      color: Color(0xFF4B6BFB),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      _localNotifications.show(
        DateTime.now().millisecond,
        title,
        body,
        notificationDetails,
        payload: jsonEncode(data),
      );
      print('✅ [DEBUG] Local notification displayed successfully');
    } catch (e) {
      print('❌ [DEBUG] Error showing notification: $e');
    }
  }

  static void _handleNotificationTap(Map<String, dynamic> data) {
    print('🔔 [DEBUG] Handling notification tap:');
    print('🔔 [DEBUG] Data: $data');

    // Add your navigation logic here
  }

  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    try {
      // Create a unique ID for this notification
      final String notificationId = message.messageId ??
          '${message.data['title']}_${message.data['body']}_${DateTime.now().millisecondsSinceEpoch}';

      // Skip if we've just handled this
      if (_recentNotificationIds.contains(notificationId)) {
        print('Skipping duplicate background notification: $notificationId');
        return;
      }

      _recentNotificationIds.add(notificationId);

      // Clean up after 5 seconds to prevent memory leaks
      Future.delayed(const Duration(seconds: 5), () {
        _recentNotificationIds.remove(notificationId);
      });

      final data = message.data;
      final type = data['type'] ?? '';
      String title = data['title'] ?? 'New Message';
      String body = data['body'] ?? 'You received a new message';

      switch (type) {
        case 'project':
          title = '📢 New Flyer Update';
          body = '${data['senderName'] ?? 'Someone'} updated the flyer';
          break;
        case 'flyer_approval':
          title = '✅ Flyer Approved';
          body = '${data['senderName'] ?? 'Someone'} approved your flyer';
          break;
        case 'flyer_feedback':
          title = '❌ Flyer Feedback';
          body = '${data['senderName'] ?? 'Someone'} provided feedback';
          break;
        case 'chat':
          title = '💬 New Message';
          body = '${data['senderName'] ?? 'Someone'}: ${data['message'] ?? ''}';
          break;
      }

      await _localNotifications.show(
        message.hashCode,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'Chat Notifications',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: jsonEncode(data),
      );
    } catch (e) {
      print('Error handling background message: $e');
    }
  }

  static Future<void> display(RemoteMessage message) async {
    try {
      print('🔔 [DEBUG] Displaying notification:');
      print('🔔 [DEBUG] Title: ${message.notification?.title}');
      print('🔔 [DEBUG] Body: ${message.notification?.body}');
      print('🔔 [DEBUG] Data: ${message.data}');

      // Create a unique ID for this notification
      final String notificationId = message.messageId ??
          '${message.notification?.title}_${message.notification?.body}_${DateTime.now().millisecondsSinceEpoch}';

      // Skip if we've shown this notification recently
      if (_recentNotificationIds.contains(notificationId)) {
        print('🔔 [DEBUG] Skipping duplicate notification: $notificationId');
        return;
      }

      _recentNotificationIds.add(notificationId);

      // Clean up after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        _recentNotificationIds.remove(notificationId);
      });

      final notification = message.notification;
      final android = message.notification?.android;

      if (notification != null) {
        await _localNotifications.show(
          message.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel',
              'High Importance Notifications',
              channelDescription:
                  'This channel is used for important notifications',
              importance: Importance.max,
              priority: Priority.high,
              icon: android?.smallIcon ?? '@mipmap/ic_launcher',
              color: const Color(0xFF4B6BFB),
              playSound: true,
              enableVibration: true,
              enableLights: true,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          payload: jsonEncode(message.data),
        );
        print('✅ [DEBUG] Local notification displayed successfully');
      }
    } catch (e) {
      print('❌ [DEBUG] Error displaying notification: $e');
    }
  }

  static void navigateFromNotification(RemoteMessage message, Widget child) {
    // Implement your navigation logic here
    // Example: Navigator.push(context, MaterialPageRoute(...))
  }
}

// Handle background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('🔔 [DEBUG] Handling background message: ${message.messageId}');
  print('🔔 [DEBUG] Background message data: ${message.data}');

  // Initialize Firebase if needed
  if (!Firebase.apps.isNotEmpty) {
    await Firebase.initializeApp();
  }

  // Show notification
  await NotificationService.display(message);
}
