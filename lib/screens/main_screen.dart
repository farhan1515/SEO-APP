import 'package:flutter/material.dart';
import 'package:seo_app/screens/home_screen.dart';
import 'package:seo_app/screens/pending_approval_screen.dart';
import 'package:seo_app/screens/chat_list_screen.dart';
import 'package:seo_app/screens/post_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:seo_app/theme/text_style.dart';
import 'package:solar_icons/solar_icons.dart'; // You may need to add this package
import 'package:seo_app/services/notification_service.dart';
import 'package:seo_app/services/unread_count_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  bool _notificationsInitialized = false;

  final List<Widget> _screens = [
    const HomeScreen(),
    const PostScreen(),
    const PendingApprovalsScreen(),
    const ChatListScreen()
  ];

  // Colors based on your specifications
  final Color selectedColor = const Color(0xFF3E1885);
  final Color unselectedColor = const Color(0xFF999999);
  final Color selectedBgColor = const Color(0x263E1885);

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _initializeUnreadCount();
  }

  void _initializeNotifications() async {
    if (!_notificationsInitialized &&
        FirebaseAuth.instance.currentUser != null) {
      print('🔔 [DEBUG] Initializing notifications in MainScreen');
      await NotificationService.initialize();
      if (mounted) {
        setState(() {
          _notificationsInitialized = true;
        });
      }
    }
  }

  void _initializeUnreadCount() {
    // Reset the unread count service when user changes
    UnreadCountService.reset();
    print('📱 [DEBUG] Initialized unread count service');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-check notification initialization when dependencies change
    _initializeNotifications();
  }

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
    final isChatIcon = index == 3; // Chat icon is at index 3

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
            Stack(
              children: [
                Icon(
                  icon,
                  color: isSelected ? selectedColor : unselectedColor,
                  size: 24,
                ),
                if (isChatIcon)
                  StreamBuilder<int>(
                    stream: UnreadCountService.unreadCountStream,
                    builder: (context, snapshot) {
                      final unreadCount = snapshot.data ?? 0;
                      if (unreadCount > 0) {
                        return Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(
                                  0xFFFF3B30), // Red badge color like Instagram
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x29FF3B30),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
              ],
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
