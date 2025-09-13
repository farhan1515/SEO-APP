// lib/services/user_status.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

class UserStatusService {
  static Timer? _statusTimer;
  static bool _isActive = false;

  static Future<void> updateUserStatus() async {
    if (FirebaseAuth.instance.currentUser != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .set({
        'lastActive': FieldValue.serverTimestamp(),
        'isOnline': true,
      }, SetOptions(merge: true));
    }
  }

  static void startActiveStatusTracking() {
    if (_statusTimer != null) return; // Prevent multiple timers

    _isActive = true;
    updateUserStatus(); // Update immediately

    // Update status more frequently on web (every 30 seconds)
    final duration = kIsWeb ? Duration(seconds: 30) : Duration(minutes: 1);

    _statusTimer = Timer.periodic(duration, (timer) {
      if (_isActive) {
        updateUserStatus();
      }
    });
  }

  static void stopActiveStatusTracking() {
    _isActive = false;
    _statusTimer?.cancel();
    _statusTimer = null;

    // Mark user as offline when stopping tracking
    _setOfflineStatus();
  }

  static void markUserActive() {
    _isActive = true;
    updateUserStatus();
  }

  static void markUserInactive() {
    _isActive = false;
  }

  static Future<void> _setOfflineStatus() async {
    if (FirebaseAuth.instance.currentUser != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .set({
          'lastActive': FieldValue.serverTimestamp(),
          'isOnline': false,
        }, SetOptions(merge: true));
      } catch (e) {
        // Silently handle error when setting offline status
        print('Error setting offline status: $e');
      }
    }
  }
}
