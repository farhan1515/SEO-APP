import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UnreadCountService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static int _totalUnreadCount = 0;
  static Stream<int>? _unreadCountStream;

  /// Get the current total unread count
  static int get totalUnreadCount => _totalUnreadCount;

  /// Get a stream of total unread counts
  static Stream<int> get unreadCountStream {
    if (_unreadCountStream == null) {
      _initializeUnreadCountStream();
    }
    return _unreadCountStream!;
  }

  /// Initialize the unread count stream
  static void _initializeUnreadCountStream() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      _unreadCountStream = Stream.value(0);
      return;
    }

    _unreadCountStream = _firestore
        .collection('user_conversations')
        .doc(currentUser.uid)
        .collection('chats')
        .snapshots()
        .map((snapshot) {
      int totalUnread = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final unreadCount = data['unreadCount'] as int? ?? 0;
        totalUnread += unreadCount;
      }
      _totalUnreadCount = totalUnread;
      return totalUnread;
    });
  }

  /// Reset the unread count stream (call when user changes)
  static void reset() {
    _unreadCountStream = null;
    _totalUnreadCount = 0;
  }

  /// Get unread count for a specific chat
  static Future<int> getChatUnreadCount(String chatId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return 0;

    try {
      final doc = await _firestore
          .collection('user_conversations')
          .doc(currentUser.uid)
          .collection('chats')
          .doc(chatId)
          .get();

      if (doc.exists) {
        final data = doc.data();
        return data?['unreadCount'] as int? ?? 0;
      }
      return 0;
    } catch (e) {
      print('Error getting chat unread count: $e');
      return 0;
    }
  }

  /// Mark a specific chat as read
  static Future<void> markChatAsRead(String chatId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      await _firestore
          .collection('user_conversations')
          .doc(currentUser.uid)
          .collection('chats')
          .doc(chatId)
          .update({
        'unreadCount': 0,
        'lastActive': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error marking chat as read: $e');
    }
  }
}
