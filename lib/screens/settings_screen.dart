import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:seo_app/screens/home_screen.dart';
import 'package:seo_app/screens/profile_list_screen.dart';
import 'package:seo_app/screens/profile_screen.dart';

import 'package:seo_app/screens/signin_screen.dart';
import 'package:seo_app/services/user_role_service.dart';
import 'package:seo_app/theme/text_style.dart';
import 'package:solar_icons/solar_icons.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  bool allowNotifications = true;
  String? userRole;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    setState(() {
      isLoading = true;
    });

    try {
      final role = await UserRoleService.getCurrentUserRole();
      setState(() {
        userRole = role;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading user role: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final String? displayName = user?.displayName;
    final String? photoURL = user?.photoURL;
    final String userId = user?.uid ?? '';

    return Scaffold(
      backgroundColor: Color(0xFFD3BDFC),
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
              ),
              child: Container(
                height: 90,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(35),
                    bottomRight: Radius.circular(35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 25,
                          backgroundImage:
                              photoURL != null ? NetworkImage(photoURL) : null,
                          child: photoURL == null
                              ? Icon(Icons.person, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Hi, ${displayName?.split(' ')[0] ?? 'User'}!',
                          style: mont.copyWith(
                            fontSize: 18,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        // IconButton(
                        //   icon: Icon(Icons.favorite_border),
                        //   onPressed: () {},
                        //   color: Colors.black,
                        // ),
                        IconButton(
                          icon: Icon(Icons.settings),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => SettingScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 70,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: Color(0xFFD3BDFC),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons
                                .arrow_back_ios_rounded, // Sleek back arrow icon
                            color: Color(0xFF3E1885),
                            size: 20,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Settings',
                              style: mont.copyWith(
                                  color: Color(0xFF3E1885),
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Customize your app experience',
                              style: mont.copyWith(
                                  color: Color(0xFF3E1885),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w300),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 190,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ProfileListScreen(userId: userId),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundImage: photoURL != null
                                  ? NetworkImage(photoURL)
                                  : null,
                              child: photoURL == null
                                  ? Icon(Icons.person, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName ?? 'John Doe',
                                    style: mont.copyWith(
                                      fontSize: 18,
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '01/02/2024',
                                    style: mont.copyWith(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'General',
                      style: mont.copyWith(
                        fontSize: 20,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Row(
                    //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    //   children: [
                    //     Text(
                    //       'Allow notifications',
                    //       style: mont.copyWith(
                    //         fontSize: 16,
                    //         color: Colors.black,
                    //       ),
                    //     ),
                    //     Switch(
                    //       value: allowNotifications,
                    //       onChanged: (bool value) {
                    //         setState(() {
                    //           allowNotifications = value;
                    //         });
                    //       },
                    //     ),
                    //   ],
                    // ),
                    const SizedBox(height: 20),
                    // Role information card
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF0277BD), Color(0xFF00BCD4)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF3E1885).withOpacity(0.3),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.badge_outlined,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Your Role',
                                  style: mont.copyWith(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  isLoading
                                      ? 'Loading...'
                                      : userRole ?? 'Role not set',
                                  style: mont.copyWith(
                                    fontSize: 20,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () => _confirmLogout(context),
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF3E1885), Color(0xFF6B48C8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF3E1885).withOpacity(0.3),
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.logout_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                'Logout',
                                style: mont.copyWith(
                                  fontSize: 18,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                SolarIconsOutline.logout,
                                color: Colors.white,
                                size: 22,
                              ),
                              // Replace onPressed with GestureDetector
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Now let's make a beautiful confirmation dialog
  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top icon
                Container(
                  height: 80,
                  width: 80,
                  decoration: BoxDecoration(
                    color: Color(0xFFFFE9E0),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    SolarIconsOutline.logout,
                    size: 40,
                    color: Color(0xFFF56556),
                  ),
                ),
                SizedBox(height: 24),

                // Title
                Text(
                  'Logout Confirmation',
                  style: mont.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3E1885),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12),

                // Message
                Text(
                  'Are you sure you want to logout from your account?',
                  style: mont.copyWith(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),

                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Cancel button
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: mont.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),

                    // Logout button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // Close dialog
                          _performLogout(context); // Perform logout
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFF56556),
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Logout',
                          style: mont.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

// Fixed logout function to ensure it only needs one attempt
  Future<void> _performLogout(BuildContext context) async {
    // Store the navigator state to be used later regardless of context changes
    final navigatorState = Navigator.of(context);
    final scaffoldMessengerState = ScaffoldMessenger.of(context);

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Center(
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF3E1885)),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Logging out...',
                    style: mont.copyWith(
                      fontSize: 14,
                      color: Color(0xFF3E1885),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    try {
      // Sign out from Firebase
      await FirebaseAuth.instance.signOut();

      // Sign out from Google if using Google Sign-In
      try {
        final GoogleSignIn googleSignIn = GoogleSignIn();
        if (await googleSignIn.isSignedIn()) {
          await googleSignIn.signOut();
        }
      } catch (e) {
        print('Google Sign-In error: $e');
        // Continue with navigation even if Google sign-out fails
      }

      // Navigate to login screen and clear stack
      // We use the previously stored navigator state
      navigatorState.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => SignInScreen()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      print('Error during logout: $e');

      // Try to close the loading dialog if it's still showing
      try {
        navigatorState.pop();
      } catch (dialogError) {
        print('Error closing dialog: $dialogError');
      }

      // Show error message with the beautiful SnackBar
      // We use the previously stored scaffold messenger state
      scaffoldMessengerState.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                SolarIconsOutline.dangerTriangle,
                color: Colors.white,
                size: 20,
              ),
              SizedBox(width: 12),
              Text(
                'Logout failed. Please try again.',
                style: mont.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFFF56556),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: Duration(seconds: 3),
          margin: EdgeInsets.all(16),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      );
    }
  }
}
