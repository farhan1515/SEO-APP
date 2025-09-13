import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:seo_app/screens/auth_checker.dart';
import 'package:seo_app/theme/text_style.dart';
import 'package:seo_app/screens/main_screen.dart';
import 'package:seo_app/services/user_status.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:solar_icons/solar_icons.dart';
import 'dart:io' show Platform;

class SignInScreen extends StatefulWidget {
  const SignInScreen({Key? key}) : super(key: key);

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  int _currentCarouselIndex = 0;

  final List<Map<String, String>> _carouselItems = [
    {
      'image': 'assets/images/inform.png',
      'text': 'The Best SEO app of the globe',
    },
    {
      'image': 'assets/images/signin_girl.png',
      'text': 'Boost your online presence',
    },
    {
      'image': 'assets/icons/horn.png',
      'text': 'Track your performance in real-time',
    },
    {
      'image': 'assets/icons/seo_logo.png',
      'text': 'Reach your target audience',
    },
  ];

  @override
  Widget build(BuildContext context) {
    // Prevent showing SignInScreen if already signed in
    if (FirebaseAuth.instance.currentUser != null) {
      Future.microtask(() {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AuthChecker()),
        );
      });
      return const SizedBox.shrink();
    }

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          double width = constraints.maxWidth;
          double height = constraints.maxHeight;

          // Responsive configurations - Much smaller for desktop/laptop
          double maxContentWidth;
          EdgeInsets contentPadding;
          double titleFontSize;
          double subtitleFontSize;
          double carouselHeight;
          double carouselImageHeight;
          double buttonHeight;
          double topSpacing;
          double afterCarouselSpacing;
          double afterLoginSpacing;
          double bottomSpacing;

          bool isMobile = width < 600;
          bool isTablet = width >= 600 && width < 1100;
          bool isDesktop = width >= 1100;

          if (isDesktop) {
            maxContentWidth = 440;
            contentPadding = const EdgeInsets.symmetric(horizontal: 48.0);
            titleFontSize = 42; // Reduced from 56
            subtitleFontSize = 14; // Reduced from 20
            carouselHeight = 200; // Significantly reduced from 280
            carouselImageHeight = 150; // Significantly reduced from 180
            buttonHeight = 65; // Reduced from 90
            topSpacing = 40; // Reduced from 80
            afterCarouselSpacing = 25; // Reduced from 40
            afterLoginSpacing = 24; // Reduced from 48
            bottomSpacing = 100; // Reduced bottom spacing
          } else if (isTablet) {
            maxContentWidth = 540;
            contentPadding = const EdgeInsets.symmetric(horizontal: 22.0);
            titleFontSize = 36; // Reduced from 48
            subtitleFontSize = 15; // Reduced from 16
            carouselHeight = 220; // Reduced from 240
            carouselImageHeight = 150; // Reduced from 150
            buttonHeight = 60; // Reduced from 76
            topSpacing = 35; // Reduced from 60
            afterCarouselSpacing = 18; // Reduced from 30
            afterLoginSpacing = 20; // Reduced from 36
            bottomSpacing = 90; // Reduced bottom spacing
          } else {
            // Mobile - keep original values
            maxContentWidth = double.infinity;
            contentPadding = const EdgeInsets.symmetric(horizontal: 16.0);
            titleFontSize = 36;
            subtitleFontSize = 14;
            carouselHeight = 200;
            carouselImageHeight = 120;
            buttonHeight = 60;
            topSpacing = 60;
            afterCarouselSpacing = 20;
            afterLoginSpacing = 24;
            bottomSpacing = 140;
          }

          return SizedBox(
            width: width,
            height: height,
            child: Stack(
              children: [
                // Background decorations
                _buildBackgroundDecorations(width, height, isMobile),

                // Main content (scrollable) - Center the content
                SafeArea(
                  child: Center(
                    child: Container(
                      width: !isMobile ? maxContentWidth : double.infinity,
                      child: Padding(
                        padding: contentPadding,
                        child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(height: topSpacing),

                              // Carousel with images and text
                              SizedBox(
                                height: carouselHeight,
                                child: CarouselSlider(
                                  options: CarouselOptions(
                                    height: carouselHeight,
                                    viewportFraction: 1.0,
                                    enlargeCenterPage: false,
                                    autoPlay: true,
                                    autoPlayInterval:
                                        const Duration(seconds: 3),
                                    onPageChanged: (index, reason) {
                                      setState(() {
                                        _currentCarouselIndex = index;
                                      });
                                    },
                                  ),
                                  items: _carouselItems.map((item) {
                                    return Builder(
                                      builder: (BuildContext context) {
                                        return Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Expanded(
                                              child: Image.asset(
                                                item['image']!,
                                                fit: BoxFit.contain,
                                                width: double.infinity,
                                                errorBuilder: (context, error,
                                                    stackTrace) {
                                                  return Icon(
                                                    Icons.image,
                                                    size: carouselHeight * 0.6,
                                                    color: Colors.grey,
                                                  );
                                                },
                                              ),
                                            ),
                                            SizedBox(height: 8),
                                            Icon(
                                              SolarIconsBold
                                                  .starFallMinimalistic,
                                              color: Colors.amber,
                                              size: isMobile
                                                  ? 20
                                                  : (isTablet ? 22 : 24),
                                            ),
                                            SizedBox(height: 6),
                                            Text(
                                              item['text']!,
                                              style: mont.copyWith(
                                                color: const Color(0xFF3E1885),
                                                fontSize: subtitleFontSize,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              textAlign: TextAlign.center,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  }).toList(),
                                ),
                              ),

                              // Carousel indicators
                              const SizedBox(height: 28),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children:
                                    _carouselItems.asMap().entries.map((entry) {
                                  return Container(
                                    width: entry.key == _currentCarouselIndex
                                        ? 24.0
                                        : 8.0,
                                    height: 8.0,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 2.0),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                      color: entry.key == _currentCarouselIndex
                                          ? const Color(0xFF3E1885)
                                          : const Color(0xFFD9D9D9),
                                    ),
                                  );
                                }).toList(),
                              ),

                              SizedBox(height: afterCarouselSpacing),

                              // Login Text
                              Text(
                                'Login',
                                style: mont.copyWith(
                                  color: const Color(0xFF3E1885),
                                  fontSize: titleFontSize,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),

                              const SizedBox(height: 6),

                              // Subtext
                              Text(
                                'You are one-step away for surprises',
                                style: mont.copyWith(
                                  color: const Color.fromRGBO(0, 0, 0, 0.41),
                                  fontSize: subtitleFontSize,
                                ),
                              ),

                              SizedBox(height: afterLoginSpacing),

                              // Google Sign-in button
                              Container(
                                width: double.infinity,
                                height: buttonHeight,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(50),
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                ),
                                child: TextButton(
                                  onPressed: () => _signInWithGoogle(context),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Image.asset(
                                        'assets/icons/google_logo.png',
                                        height: isMobile
                                            ? 20
                                            : (isTablet ? 22 : 24),
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Icon(
                                            Icons.account_circle,
                                            size: isMobile
                                                ? 20
                                                : (isTablet ? 22 : 24),
                                            color: Colors.grey,
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Sign In with Google',
                                        style: mont.copyWith(
                                          fontSize: subtitleFontSize,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF000000),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Bottom spacing
                              SizedBox(height: bottomSpacing),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBackgroundDecorations(
      double width, double height, bool isMobile) {
    return Stack(
      children: [
        // Top left purple circle
        Positioned(
          top: -64,
          left: -58,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: const Color(0xFF3E1885),
              borderRadius: BorderRadius.circular(100),
            ),
          ),
        ),

        // Top-right circle (semi-transparent)
        Positioned(
          top: -43,
          left: 82,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0x4D3E1885),
              borderRadius: BorderRadius.circular(60),
            ),
          ),
        ),

        // Bottom curved shape with terms text - only for mobile
        if (isMobile)
          Positioned(
            bottom: -50,
            left: -70,
            child: Container(
              width: width + 140,
              height: 179,
              decoration: BoxDecoration(
                color: const Color(0x4D3E1885),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.elliptical(160, 200),
                  bottomLeft: Radius.elliptical(160, 40),
                  topRight: Radius.elliptical(550, 200),
                  bottomRight: Radius.elliptical(550, 40),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.only(left: 30, bottom: 40, right: 30),
                child: Center(
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      children: [
                        TextSpan(
                          text: 'By Logging in, you accept our ',
                          style: poppins,
                        ),
                        TextSpan(
                          text: 'Terms & Conditions',
                          style: poppins.copyWith(
                            color: const Color(0xFF0099FF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Bottom-right circle
        Positioned(
          bottom: -80,
          right: -80,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: const Color(0x4D3E1885),
              borderRadius: BorderRadius.circular(100),
            ),
          ),
        ),

        // Terms and conditions for tablet and desktop - fixed at bottom
        if (!isMobile)
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: width >= 1100 ? 48 : 32),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                //  color: const Color(0x1A3E1885),
                borderRadius: BorderRadius.circular(12),
              ),
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: poppins.copyWith(
                    color: const Color(0xFF3E1885),
                    fontSize: width >= 1100 ? 14 : 13,
                  ),
                  children: [
                    const TextSpan(text: 'By Logging in, you accept our '),
                    TextSpan(
                      text: 'Terms & Conditions',
                      style: poppins.copyWith(
                        color: const Color(0xFF0099FF),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _signInWithGoogle(BuildContext context) async {
    try {
      // Check if Google Sign-In is supported on this device
      if (!_isGoogleSignInSupported()) {
        _showSnackbar(context, 'Google Sign-In is not supported on this device',
            Colors.red);
        return;
      }

      // Show loading indicator
      _showSnackbar(context, 'Signing in with Google...', Colors.blue);

      // Check if we're on Android and show specific message
      if (!kIsWeb && Platform.isAndroid) {
        print('Attempting Google Sign-In on Android...');
      }

      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: kIsWeb
            ? '623745717856-c8k8fjsja7gfmov1j8d8s4fhug0lal3t.apps.googleusercontent.com'
            : null,
        scopes: ['email', 'profile'],
        // Add these configurations for better mobile support
        signInOption: SignInOption.standard,
      );

      // Check if user is already signed in and sign out if needed
      if (await googleSignIn.isSignedIn()) {
        print('User already signed in, signing out first...');
        await googleSignIn.signOut();
      }

      print('Initiating Google Sign-In...');
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        if (mounted) {
          _showSnackbar(context, 'Google Sign-In canceled', Colors.orange);
        }
        return;
      }

      print('Google Sign-In successful, getting authentication...');
      // Hide the loading message
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      print('Authentication successful, creating Firebase credential...');
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print('Signing in to Firebase...');
      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      if (userCredential.user != null && mounted) {
        print('Firebase sign-in successful, updating user status...');
        await UserStatusService.updateUserStatus();
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const AuthChecker(),
            ),
          );
        }
      }
    } catch (e) {
      print('Error signing in with Google: $e');
      print('Error type: ${e.runtimeType}');
      print('Error details: ${e.toString()}');

      // Hide any existing snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      // Show detailed error message
      String errorMessage = 'Sign-In failed. Please try again!';

      if (e.toString().contains('network_error')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else if (e.toString().contains('sign_in_canceled')) {
        errorMessage = 'Sign-in was canceled.';
      } else if (e.toString().contains('sign_in_failed')) {
        errorMessage = 'Sign-in failed. Please try again.';
      } else if (e.toString().contains('play_services_not_available')) {
        errorMessage =
            'Google Play Services not available. Please update your device.';
      } else if (e.toString().contains('invalid_account')) {
        errorMessage =
            'Invalid account. Please try with a different Google account.';
      } else if (e.toString().contains('developer_error')) {
        errorMessage = 'Configuration error. Please contact support.';
      } else if (e.toString().contains('internal_error')) {
        errorMessage = 'Internal error. Please try again later.';
      }

      if (mounted) {
        _showSnackbar(context, errorMessage, Colors.red);
      }
    }
  }

  void _showSnackbar(BuildContext context, String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  // Check if device supports Google Sign-In
  bool _isGoogleSignInSupported() {
    if (kIsWeb) return true;
    if (Platform.isAndroid) return true;
    if (Platform.isIOS) return true;
    return false;
  }
}
