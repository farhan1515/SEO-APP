import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seo_app/services/notification_service.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> signOut() async {
    try {
      // First cleanup notifications
      await NotificationService.signOut();

      // Then sign out
      await _auth.signOut();

      print('✅ [DEBUG] User signed out successfully');
    } catch (e) {
      print('❌ [DEBUG] Error during sign out: $e');
      rethrow;
    }
  }

  static Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Clean up user data
        await _firestore.collection('users').doc(user.uid).delete();

        // Clean up notifications
        await NotificationService.signOut();

        // Delete the user account
        await user.delete();

        print('✅ [DEBUG] User account deleted successfully');
      }
    } catch (e) {
      print('❌ [DEBUG] Error deleting account: $e');
      rethrow;
    }
  }
}
