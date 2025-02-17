// lib/features/auth/screens/signin_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:seo_app/screens/dashboard_screen.dart';
import 'package:seo_app/screens/email_signin_screen.dart';
import 'package:seo_app/screens/post_request_screen.dart';
import 'package:seo_app/screens/profile_screen.dart';
import 'package:seo_app/services/user_status.dart';
import 'package:seo_app/theme/text_style.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7EBFF),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 30),
                // Logo and App Name - Centered
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.3),
                              spreadRadius: 2,
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.thumb_up,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'SEO Credit',
                        style: title.copyWith(letterSpacing: 1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                // Illustration
                Container(
                  width: double.infinity,
                  height: MediaQuery.of(context).size.height * 0.38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Image.asset(
                    'assets/images/signin_girl.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 24),
                // Tagline
                Text(
                  'Relax, let us drive your\ndigital marketing',
                  textAlign: TextAlign.center,
                  style: title.copyWith(),
                  // style: TextStyle(
                  //   fontSize: 24,
                  //   fontWeight: FontWeight.w600,
                  // ),
                ),
                const SizedBox(height: 40),
                // Apple Sign In Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => _signInWithApple(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.apple,
                          color: Colors.white,
                          size: 24,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Continue with Apple',
                          style: title.copyWith(
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                              color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Google and Email Sign In Buttons in Row
                Row(
                  children: [
                    // Google Sign In Button
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          onPressed: () => _signInWithGoogle(context),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.grey),
                            backgroundColor: Color(0xFFf1f1f1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/icons/google_logo.png',
                                height: 24,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Google',
                                style: title.copyWith(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Email Sign In Button
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          onPressed: () => _navigateToEmailSignIn(context),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.grey),
                            backgroundColor: Color(0xFFf1f1f1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.email_outlined, color: Colors.black87),
                              SizedBox(width: 8),
                              Text(
                                'Email',
                                style: title.copyWith(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 16,
                                ),
                                // style: TextStyle(
                                //   color: Colors.black87,
                                //   fontSize: 16,
                                // ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Sign in text
                TextButton(
                  onPressed: () => _navigateToSignIn(context),
                  child: Text(
                    'Have an account? Sign in',
                    style: headsmall.copyWith(),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // In signin_screen.dart, update the _signInWithGoogle method:

  Future<void> _signInWithGoogle(BuildContext context) async {
    try {
      // Initialize Google Sign In
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        _showSnackbar(context, 'Google Sign-In canceled', Colors.orange);
        return;
      }

      // Obtain auth details from request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in with credential
      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      // Use pushReplacement instead of push to prevent going back to sign-in screen
      if (userCredential.user != null) {
        await UserStatusService.updateUserStatus(); // Add this line
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ProfileScreen(
              userId: userCredential.user!.uid, // Pass the user ID
            ),
          ),
        );
      }
    } catch (e) {
      print('Error signing in with Google: $e');
      _showSnackbar(context, 'Sign-In failed. Please try again!', Colors.red);
    }
  }

// Function to show a cute SnackBar
  void _showSnackbar(BuildContext context, String message, Color color) {
    final snackBar = SnackBar(
      content: Text(
        message,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  Future<void> _signInWithApple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oAuthCredential = OAuthProvider('apple.com').credential(
        idToken: credential.identityToken,
        accessToken: credential.authorizationCode,
      );

      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(oAuthCredential);

      // Handle successful sign in
      print('Signed in: ${userCredential.user?.displayName}');
    } catch (e) {
      print('Error signing in with Apple: $e');
    }
  }

  void _navigateToEmailSignIn(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EmailSignInScreen()),
    );
  }

  void _navigateToSignIn(BuildContext context) {
    // Navigate to sign in screen
    // Navigator.pushNamed(context, '/signin');
  }
}
