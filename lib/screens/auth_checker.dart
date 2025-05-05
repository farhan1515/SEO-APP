import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seo_app/screens/home_screen.dart';
import 'package:seo_app/screens/post_screen.dart';
import 'package:seo_app/screens/main_screen.dart';
import 'package:seo_app/screens/profile_screen.dart';
import 'package:seo_app/screens/signin_screen.dart';
import 'package:seo_app/screens/role_selection_screen.dart'; // Import the new screen

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
          final userId = snapshot.data!.uid;

          // First check if user has a role assigned
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('roles')
                .doc(userId)
                .get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              // If user document doesn't exist or doesn't have a role, send to role selection
              if (!userSnapshot.hasData ||
                  !userSnapshot.data!.exists ||
                  !userSnapshot.data!.data().toString().contains('role')) {
                return RoleSelectionScreen(userId: userId);
              }

              // Get the user's role
              final userRole = userSnapshot.data!['role'] as String;

              // For non-customer roles, go directly to MainScreen
              if (userRole != 'Customer') {
                return MainScreen();
              }

              // For customers, check if they have a profile
              return FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('profiles')
                    .doc(userId)
                    .collection('profiles')
                    .get(),
                builder: (context, profileSnapshot) {
                  if (profileSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (profileSnapshot.hasError) {
                    return Center(
                        child: Text('Error: ${profileSnapshot.error}'));
                  }

                  // Check if the user has any profiles
                  if (profileSnapshot.hasData &&
                      profileSnapshot.data!.docs.isEmpty) {
                    // No profiles found, navigate to ProfileScreen
                    return ProfileScreen(userId: userId);
                  } else {
                    // Profiles found, navigate to MainScreen
                    return MainScreen();
                  }
                },
              );
            },
          );
        }

        // No user is signed in, navigate to SignInScreen
        return const SignInScreen();
      },
    );
  }
}
