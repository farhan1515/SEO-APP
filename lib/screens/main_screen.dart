import 'package:flutter/material.dart';
import 'package:seo_app/screens/dashboard_screen.dart';
import 'package:seo_app/screens/history_screen.dart';
import 'package:seo_app/screens/home_screen.dart';
import 'package:seo_app/screens/post_request_screen.dart';
import 'package:seo_app/screens/chat_list_screen.dart';
import 'package:seo_app/screens/post_screen.dart';
import 'package:seo_app/screens/profile_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:seo_app/screens/status_screen.dart';
import 'package:seo_app/theme/text_style.dart';
import 'package:solar_icons/solar_icons.dart'; // You may need to add this package

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const PostScreen(),
    const StatusScreen(),
    ChatListScreen()
  ];

  // Colors based on your specifications
  final Color selectedColor = const Color(0xFF3E1885);
  final Color unselectedColor = const Color(0xFF999999);
  final Color selectedBgColor =
      const Color(0x263E1885); // rgba(62, 24, 133, 0.15)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          _selectedIndex < 2 ? const Color(0xFFc9dee7) : Colors.white,
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 5,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNavItem(0, SolarIconsOutline.home, 'Home'),
              _buildNavItem(1, SolarIconsOutline.addCircle, 'Post'),
              _buildNavItem(2, SolarIconsBold.history, 'Status'),
              _buildNavItem(3, SolarIconsOutline.chatRound, 'Chat'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: isSelected ? selectedBgColor : Colors.transparent,
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? selectedColor : unselectedColor,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: mont.copyWith(
                color: isSelected ? selectedColor : unselectedColor,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
