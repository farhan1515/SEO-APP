import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seo_app/screens/home_screen.dart';
import 'package:seo_app/screens/post_screen.dart';
import 'package:seo_app/screens/main_screen.dart';
import 'package:seo_app/screens/profile_screen.dart';
import 'package:seo_app/screens/signin_screen.dart';

class AuthChecker extends StatelessWidget {
  const AuthChecker({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasData && snapshot.data != null) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('profiles')
                .doc(snapshot.data!.uid)
                .get(),
            builder: (context, profileSnapshot) {
              if (profileSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (profileSnapshot.hasData && profileSnapshot.data!.exists) {
                // Profile is complete, navigate to MainScreen
                return MainScreen();
              } else {
                // Profile is incomplete, navigate to ProfileScreen
                return ProfileScreen(userId: snapshot.data!.uid);
              }
            },
          );
        }

        // No user is signed in, navigate to SignInScreen
        return const SignInScreen();
      },
    );
  }
}
