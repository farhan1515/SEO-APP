import 'package:flutter/material.dart';
import 'dart:async';

import 'package:seo_app/theme/text_style.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Navigate to appropriate screen after 3 seconds
    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacementNamed(context, '/auth_checker');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Top-left circle
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

          // Bottom-left semi-transparent circle
          Positioned(
            bottom: -70,
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

          // Center content with logo and text
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                SizedBox(
                    width: 60,
                    height: 60,
                    child: Image.asset(
                      'assets/icons/seo_logo.png',
                    )),

                const SizedBox(height: 16),

                // SEO Credit text
                Text('SEO.Credit', style: mont),

                const SizedBox(height: 8),

                // Tagline
                Text('Your way of thoughts, Our Way of Designs',
                    style: mont.copyWith(
                        color: Color.fromRGBO(0, 0, 0, 0.37),
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Clipper for the left curved shape
class LeftCurvedClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.moveTo(0, size.height);
    path.quadraticBezierTo(
        size.width * 0.6, size.height * 0.2, size.width, size.height * 0.5);
    path.lineTo(size.width, 0);
    path.lineTo(0, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => true;
}
