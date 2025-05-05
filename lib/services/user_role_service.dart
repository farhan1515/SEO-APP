import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserRoleService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get the current user's role
  static Future<String?> getCurrentUserRole() async {
    try {
      final User? currentUser = _auth.currentUser;

      if (currentUser == null) {
        return null;
      }

      final DocumentSnapshot userDoc =
          await _firestore.collection('roles').doc(currentUser.uid).get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        return data['role'] as String?;
      }

      return null;
    } catch (e) {
      print('Error getting user role: $e');
      return null;
    }
  }

  // Check if user has a specific role
  static Future<bool> hasRole(String role) async {
    final userRole = await getCurrentUserRole();
    return userRole == role;
  }

  // Update user role
  static Future<void> updateUserRole(String newRole) async {
    try {
      final User? currentUser = _auth.currentUser;

      if (currentUser == null) {
        throw Exception('No authenticated user found');
      }

      await _firestore.collection('roles').doc(currentUser.uid).update({
        'role': newRole,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating user role: $e');
      rethrow;
    }
  }
}
