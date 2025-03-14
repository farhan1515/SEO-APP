import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:seo_app/theme/text_style.dart';

import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:seo_app/screens/main_screen.dart';
import 'package:seo_app/services/user_status.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:solar_icons/solar_icons.dart';

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
    return Scaffold(
      body: Stack(
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
                color: const Color(0x4D3E1885), // 30% opacity
                borderRadius: BorderRadius.circular(60),
              ),
            ),
          ),

          // Bottom curved shape
          Stack(
            children: [
              // Bottom-left semi-transparent circle with text
              Positioned(
                bottom: -50,
                left: -70,
                child: Container(
                  width: 456,
                  height: 179,
                  decoration: BoxDecoration(
                    color: const Color(0x4D3E1885), // 30% opacity
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.elliptical(160, 200),
                      bottomLeft: Radius.elliptical(160, 40),
                      topRight: Radius.elliptical(550, 200),
                      bottomRight: Radius.elliptical(550, 40),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 60, bottom: 40),
                    child: Center(
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: const TextStyle(
                            color: Colors
                                .white, // White text for better visibility
                            fontSize: 14,
                          ),
                          children: [
                            TextSpan(
                                text: 'By Logging in, you accept our ',
                                style: poppins),
                            TextSpan(
                                text: 'Terms & Conditions',
                                style:
                                    poppins.copyWith(color: Color(0xFF0099FF))
                                // style:  TextStyle(
                                //   color: Colors.blue,
                                //   fontWeight: FontWeight.bold,
                                //   decoration: TextDecoration
                                //       .underline, // Underline for link effect
                                // ),
                                // You can add a gesture recognizer here for the terms link
                                ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom-right semi-transparent circle
              Positioned(
                bottom: -80,
                right: -80,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: const Color(0x4D3E1885), // 30% opacity
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
            ],
          ),

          // Main content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 60),

                  // Carousel with megaphone image and text
                  CarouselSlider(
                    options: CarouselOptions(
                      height: 260,
                      viewportFraction: 1.0,
                      enlargeCenterPage: false,
                      autoPlay: true,
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
                            children: [
                              Image.asset(
                                item['image']!,
                                height: 180,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(height: 20),
                              Column(
                                children: [
                                  Icon(SolarIconsBold.starFallMinimalistic,
                                      color: Colors.amber, size: 26),
                                  const SizedBox(height: 10),
                                  Text(
                                    item['text']!,
                                    style: mont.copyWith(
                                        color: Color(0xFF3E1885),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      );
                    }).toList(),
                  ),

                  // Carousel indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _carouselItems.asMap().entries.map((entry) {
                      return Container(
                        width: entry.key == _currentCarouselIndex ? 24.0 : 8.0,
                        height: 8.0,
                        margin: const EdgeInsets.symmetric(horizontal: 2.0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: entry.key == _currentCarouselIndex
                              ? const Color(0xFF3E1885)
                              : const Color(0xFFD9D9D9),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // Login Text
                  Text(
                    'Login',
                    style: mont.copyWith(
                        color: Color(0xFF3E1885),
                        fontSize: 48,
                        fontWeight: FontWeight.w600),
                    // style: TextStyle(
                    //   color: Color(0xFF3E1885),
                    //   fontSize: 32,
                    //   fontWeight: FontWeight.bold,
                    // ),
                  ),

                  const SizedBox(height: 8),

                  // Subtext
                  Text(
                    'You are one-step away for surprises',
                    style: mont.copyWith(
                        color: Color.fromRGBO(0, 0, 0, 0.41), fontSize: 14),
                    // style: TextStyle(
                    //   color: Colors.grey,
                    //   fontSize: 14,
                    // ),
                  ),

                  const SizedBox(height: 40),

                  // Google Sign-in button
                  Container(
                    width: double.infinity,
                    height: 76,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(color: Colors.grey.shade300),
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
                            height: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Sign In with Google',
                            style: mont.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF000000)),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Apple Sign-in button
                  Container(
                    width: double.infinity,
                    height: 76,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(
                        color: Color.fromRGBO(0, 0, 0, 0.21), // Border color
                        width: 2, // Border width
                        style: BorderStyle
                            .solid, // Border style (solid, dashed, etc.)
                      ),
                    ),
                    child: TextButton(
                      onPressed: () => _signInWithApple(),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.apple,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Continue with Apple',
                            style: mont.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white),
                            // style: TextStyle(
                            //   color: Colors.white,
                            //   fontSize: 16,
                            //   fontWeight: FontWeight.w500,
                            // ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

 Future<void> _signInWithGoogle(BuildContext context) async {
  try {
    final GoogleSignIn googleSignIn = GoogleSignIn(
      clientId: kIsWeb ? '623745717856-c8k8fjsja7gfmov1j8d8s4fhug0lal3t.apps.googleusercontent.com' : null, // Add web client ID
      scopes: ['email', 'profile'],
    );

    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

    if (googleUser == null) {
      _showSnackbar(context, 'Google Sign-In canceled', Colors.orange);
      return;
    }

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final UserCredential userCredential =
        await FirebaseAuth.instance.signInWithCredential(credential);

    if (userCredential.user != null) {
      await UserStatusService.updateUserStatus();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MainScreen(),
        ),
      );
    }
  } catch (e) {
    print('Error signing in with Google: $e');
    _showSnackbar(context, 'Sign-In failed. Please try again!', Colors.red);
  }
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

      if (userCredential.user != null) {
        await UserStatusService.updateUserStatus();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainScreen(),
          ),
        );
      }
    } catch (e) {
      print('Error signing in with Apple: $e');
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
}

// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:google_sign_in/google_sign_in.dart';
// import 'package:seo_app/screens/dashboard_screen.dart';
// import 'package:seo_app/screens/email_signin_screen.dart';
// import 'package:seo_app/screens/post_request_screen.dart';
// import 'package:seo_app/screens/profile_screen.dart';
// import 'package:seo_app/services/user_status.dart';
// import 'package:seo_app/theme/text_style.dart';
// import 'package:sign_in_with_apple/sign_in_with_apple.dart';

// import 'main_screen.dart';

// class SignInScreen extends StatelessWidget {
//   const SignInScreen({Key? key}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Color(0xFFF7EBFF),
//       body: SafeArea(
//         child: Stack(
//           children: [
//             // Top-left circle
//             Positioned(
//               top: -64,
//               left: -58,
//               child: Container(
//                 width: 200,
//                 height: 200,
//                 decoration: BoxDecoration(
//                   color: const Color(0xFF3E1885),
//                   borderRadius: BorderRadius.circular(100),
//                 ),
//               ),
//             ),

//             // Top-right circle (semi-transparent)
//             Positioned(
//               top: -43,
//               left: 82,
//               child: Container(
//                 width: 120,
//                 height: 120,
//                 decoration: BoxDecoration(
//                   color: const Color(0x4D3E1885), // 30% opacity
//                   borderRadius: BorderRadius.circular(60),
//                 ),
//               ),
//             ),

//             // Bottom-left semi-transparent circle
//             Positioned(
//               bottom: -70,
//               left: -70,
//               child: Container(
//                 width: 456,
//                 height: 179,
//                 decoration: BoxDecoration(
//                   color: const Color(0x4D3E1885), // 30% opacity
//                   borderRadius: BorderRadius.only(
//                     topLeft: Radius.elliptical(160, 200),
//                     bottomLeft: Radius.elliptical(160, 40),
//                     topRight: Radius.elliptical(550, 200),
//                     bottomRight: Radius.elliptical(550, 40),
//                   ),
//                 ),
//               ),
//             ),

//             // Bottom-right semi-transparent circle
//             Positioned(
//               bottom: -80,
//               right: -80,
//               child: Container(
//                 width: 200,
//                 height: 200,
//                 decoration: BoxDecoration(
//                   color: const Color(0x4D3E1885), // 30% opacity
//                   borderRadius: BorderRadius.circular(100),
//                 ),
//               ),
//             ),

//             SingleChildScrollView(
//               child: Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 24.0),
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     const SizedBox(height: 30),
//                     // Logo and App Name - Centered
//                     Center(
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           Container(
//                             width: 40,
//                             height: 40,
//                             decoration: BoxDecoration(
//                               color: const Color(0xFF4CAF50),
//                               shape: BoxShape.circle,
//                               boxShadow: [
//                                 BoxShadow(
//                                   color: Colors.green.withOpacity(0.3),
//                                   spreadRadius: 2,
//                                   blurRadius: 8,
//                                   offset: const Offset(0, 2),
//                                 ),
//                               ],
//                             ),
//                             child: const Icon(
//                               Icons.thumb_up,
//                               color: Colors.white,
//                               size: 24,
//                             ),
//                           ),
//                           const SizedBox(width: 12),
//                           Text(
//                             'SEO Credit',
//                             style: title.copyWith(letterSpacing: 1),
//                           ),
//                         ],
//                       ),
//                     ),
//                     const SizedBox(height: 40),
//                     // Illustration
//                     Container(
//                       width: double.infinity,
//                       height: MediaQuery.of(context).size.height * 0.38,
//                       decoration: BoxDecoration(
//                         borderRadius: BorderRadius.circular(20),
//                       ),
//                       child: Image.asset(
//                         'assets/images/signin_girl.png',
//                         fit: BoxFit.contain,
//                       ),
//                     ),
//                     const SizedBox(height: 24),
//                     // Tagline
//                     Text(
//                       'Relax, let us drive your\ndigital marketing',
//                       textAlign: TextAlign.center,
//                       style: title.copyWith(),
//                     ),
//                     const SizedBox(height: 40),
//                     // Apple Sign In Button
//                     SizedBox(
//                       width: double.infinity,
//                       height: 50,
//                       child: ElevatedButton(
//                         onPressed: () => _signInWithApple(),
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: Colors.black,
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(25),
//                           ),
//                           elevation: 0,
//                         ),
//                         child: Row(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: [
//                             Icon(
//                               Icons.apple,
//                               color: Colors.white,
//                               size: 24,
//                             ),
//                             SizedBox(width: 8),
//                             Text(
//                               'Continue with Apple',
//                               style: title.copyWith(
//                                   fontWeight: FontWeight.w500,
//                                   fontSize: 16,
//                                   color: Colors.white),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                     const SizedBox(height: 16),
//                     // Google and Email Sign In Buttons in Row
//                     Row(
//                       children: [
//                         // Google Sign In Button
//                         Expanded(
//                           child: SizedBox(
//                             height: 50,
//                             child: OutlinedButton(
//                               onPressed: () => _signInWithGoogle(context),
//                               style: OutlinedButton.styleFrom(
//                                 side: const BorderSide(color: Colors.grey),
//                                 backgroundColor: Color(0xFFf1f1f1),
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(25),
//                                 ),
//                               ),
//                               child: Row(
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 children: [
//                                   Image.asset(
//                                     'assets/icons/google_logo.png',
//                                     height: 24,
//                                   ),
//                                   const SizedBox(width: 8),
//                                   Text(
//                                     'Google',
//                                     style: title.copyWith(
//                                       fontWeight: FontWeight.w500,
//                                       fontSize: 16,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                         ),
//                         const SizedBox(width: 16),
//                         // Email Sign In Button
//                         Expanded(
//                           child: SizedBox(
//                             height: 50,
//                             child: OutlinedButton(
//                               onPressed: () => _navigateToEmailSignIn(context),
//                               style: OutlinedButton.styleFrom(
//                                 side: const BorderSide(color: Colors.grey),
//                                 backgroundColor: Color(0xFFf1f1f1),
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(25),
//                                 ),
//                               ),
//                               child: Row(
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 children: [
//                                   Icon(Icons.email_outlined, color: Colors.black87),
//                                   SizedBox(width: 8),
//                                   Text(
//                                     'Email',
//                                     style: title.copyWith(
//                                       fontWeight: FontWeight.w500,
//                                       fontSize: 16,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 16),
//                     // Sign in text
//                     TextButton(
//                       onPressed: () => _navigateToSignIn(context),
//                       child: Text(
//                         'Have an account? Sign in',
//                         style: headsmall.copyWith(),
//                       ),
//                     ),
//                     const SizedBox(height: 24),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

  // Future<void> _signInWithGoogle(BuildContext context) async {
  //   try {
  //     // Initialize Google Sign In
  //     final GoogleSignIn googleSignIn = GoogleSignIn();
  //     final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

  //     if (googleUser == null) {
  //       _showSnackbar(context, 'Google Sign-In canceled', Colors.orange);
  //       return;
  //     }

  //     // Obtain auth details from request
  //     final GoogleSignInAuthentication googleAuth =
  //         await googleUser.authentication;

  //     // Create new credential
  //     final credential = GoogleAuthProvider.credential(
  //       accessToken: googleAuth.accessToken,
  //       idToken: googleAuth.idToken,
  //     );

  //     // Sign in with credential
  //     final UserCredential userCredential =
  //         await FirebaseAuth.instance.signInWithCredential(credential);

  //     // Use pushReplacement instead of push to prevent going back to sign-in screen
  //     if (userCredential.user != null) {
  //       await UserStatusService.updateUserStatus(); // Add this line
  //       Navigator.pushReplacement(
  //         context,
  //         MaterialPageRoute(
  //           builder: (context) => MainScreen(),
  //         ),
  //       );
  //     }
  //   } catch (e) {
  //     print('Error signing in with Google: $e');
  //     _showSnackbar(context, 'Sign-In failed. Please try again!', Colors.red);
  //   }
  // }

//   // Function to show a cute SnackBar
//   void _showSnackbar(BuildContext context, String message, Color color) {
//     final snackBar = SnackBar(
//       content: Text(
//         message,
//         style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
//       ),
//       backgroundColor: color,
//       behavior: SnackBarBehavior.floating,
//       margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//     );

//     ScaffoldMessenger.of(context).showSnackBar(snackBar);
//   }

//   Future<void> _signInWithApple() async {
//     try {
//       final credential = await SignInWithApple.getAppleIDCredential(
//         scopes: [
//           AppleIDAuthorizationScopes.email,
//           AppleIDAuthorizationScopes.fullName,
//         ],
//       );

//       final oAuthCredential = OAuthProvider('apple.com').credential(
//         idToken: credential.identityToken,
//         accessToken: credential.authorizationCode,
//       );

//       final UserCredential userCredential =
//           await FirebaseAuth.instance.signInWithCredential(oAuthCredential);

//       // Handle successful sign in
//       print('Signed in: ${userCredential.user?.displayName}');
//     } catch (e) {
//       print('Error signing in with Apple: $e');
//     }
//   }

//   void _navigateToEmailSignIn(BuildContext context) {
//     Navigator.push(
//       context,
//       MaterialPageRoute(builder: (context) => EmailSignInScreen()),
//     );
//   }

//   void _navigateToSignIn(BuildContext context) {
//     // Navigate to sign in screen
//     // Navigator.pushNamed(context, '/signin');
//   }
// }
