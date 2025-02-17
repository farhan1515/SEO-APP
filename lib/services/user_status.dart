// lib/services/user_status.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserStatusService {
  static Future<void> updateUserStatus() async {
    if (FirebaseAuth.instance.currentUser != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .set({
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }
}
