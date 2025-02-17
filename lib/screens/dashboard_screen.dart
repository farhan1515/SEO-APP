import 'package:flutter/material.dart';
import 'package:seo_app/screens/chat_list_screen.dart';
import 'package:seo_app/screens/chat_screen.dart';
import 'package:seo_app/screens/profile_screen.dart';
import 'package:seo_app/theme/text_style.dart';
import 'package:seo_app/screens/post_request_screen.dart';
import 'package:seo_app/screens/show_posts_screen.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:seo_app/widgets/show_post_list.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:seo_app/screens/signin_screen.dart'; // Update with your actual path

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final List<String> _selectedPlatforms = [];
  String _selectedTab = 'today';

  void _handleTabSelected(String tab) {
    setState(() {
      _selectedTab = tab;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    

    return Scaffold(
      backgroundColor: Color(0xFFc9dee7),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4B6BFB).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.trending_up_rounded,
                          color: Color(0xFF4B6BFB),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 22),
                      Center(
                        child: Text(
                          'Dashboard',
                          style: lexand.copyWith(
                            fontSize: screenWidth < 360 ? 18 : 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 20,
                      ),
                      Icon(Icons
                          .add_alert), // In DashboardScreen's build method, update the person icon:
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4B6BFB).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.person_2_rounded,
                            color: Color(0xFF4B6BFB),
                            size: 24,
                          ),
                          onPressed: () {
                            // Navigate to ProfileScreen with the current user's ID
                            final user = FirebaseAuth.instance.currentUser;
                            if (user != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ProfileScreen(userId: user.uid),
                                ),
                              );
                            } else {
                              // Handle case where user is not logged in
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('User not logged in!')),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.menu),
                    itemBuilder: (BuildContext context) => [
                      const PopupMenuItem<String>(
                        value: 'logout',
                        child: Text('Logout'),
                      ),
                    ],
                    onSelected: (String value) {
                      if (value == 'logout') {
                        _confirmLogout(context);
                      }
                    },
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Social Media Row
              // Row(
              //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //   children: [
              //     Expanded(
              //       flex: 1,
              //       child: _SocialMediaButton(
              //         title: 'Facebook',
              //         icon: Icon(LucideIcons.facebook, size: 20),
              //         color: const Color(0xFF1877F2),
              //         isSelected: _selectedPlatforms.contains('facebook'),
              //         onToggle: (selected) {
              //           setState(() {
              //             if (selected) {
              //               _selectedPlatforms.add('facebook');
              //             } else {
              //               _selectedPlatforms.remove('facebook');
              //             }
              //           });
              //         },
              //       ),
              //     ),
              //     const SizedBox(width: 8),
              //     Expanded(
              //       flex: 1,
              //       child: _SocialMediaButton(
              //         title: 'Instagram',
              //         icon: Icon(LucideIcons.instagram, size: 20),
              //         color: const Color(0xFFE4405F),
              //         isSelected: _selectedPlatforms.contains('instagram'),
              //         onToggle: (selected) {
              //           setState(() {
              //             if (selected) {
              //               _selectedPlatforms.add('instagram');
              //             } else {
              //               _selectedPlatforms.remove('instagram');
              //             }
              //           });
              //         },
              //       ),
              //     ),
              //     const SizedBox(width: 8),
              //     Expanded(
              //       flex: 1,
              //       child: _SocialMediaButton(
              //         title: 'WhatsApp',
              //         icon: Image.asset(
              //           "assets/icons/whatsapp.png",
              //           height: 20,
              //           width: 20,
              //           fit: BoxFit.contain,
              //         ),
              //         color: const Color(0xFF25D366),
              //         isSelected: _selectedPlatforms.contains('whatsapp'),
              //         onToggle: (selected) {
              //           setState(() {
              //             if (selected) {
              //               _selectedPlatforms.add('whatsapp');
              //             } else {
              //               _selectedPlatforms.remove('whatsapp');
              //             }
              //           });
              //         },
              //       ),
              //     ),
              //   ],
              // ),

              const SizedBox(height: 40),

              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10.0,
                runSpacing: 15.0,
                children: [
                  // Post Button
                  ElevatedButton.icon(
                    onPressed: () {
                      // Navigate to PostRequestScreen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => PostRequestScreen()),
                      );
                    },
                    icon: const Icon(Icons.post_add, color: Colors.white),
                    label: const Text(
                      'Post',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4B6BFB),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),

                  // Chat Button
                  ElevatedButton.icon(
                    onPressed: () {
                      // Navigate to ChatScreen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => ChatScreen(
                                  recipientId:
                                      'recipient_user_id', // Replace with actual recipient's UID
                                  recipientName: 'Recipient Name',
                                )),
                      );
                    },
                    icon: const Icon(Icons.chat, color: Colors.white),
                    label: const Text(
                      'Ask SEO',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4B6BFB),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),

                  // Messages Button
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ChatListScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat, color: Colors.white),
                    label: const Text(
                      'Messages',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4B6BFB),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 40,
              ),
              // Replace the existing ButtonGroup() with:
              ButtonGroup(
                onTabSelected: _handleTabSelected, // Pass callback
              ),

              Expanded(
                child: PostListScreen(
                  selectedPlatforms: _selectedPlatforms,
                  selectedTab: _selectedTab,
                  userId: FirebaseAuth.instance.currentUser!.uid,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialMediaButton extends StatelessWidget {
  final String title;
  final Widget icon;
  final Color color;
  final bool isSelected;
  final Function(bool) onToggle;

  const _SocialMediaButton({
    Key? key,
    required this.title,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTap: () => onToggle(!isSelected),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: constraints.maxWidth,
              minHeight: 40,
            ),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF4db7d7) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color:
                    isSelected ? const Color(0xFF4db7d7) : Colors.grey.shade300,
                width: 1,
              ),
            ),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    child: icon is Image
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: FittedBox(child: icon))
                        : icon,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        title,
                        style: texts.copyWith(
                          fontSize: 16,
                          color: isSelected ? Colors.white : Colors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class ButtonGroup extends StatefulWidget {
  final Function(String) onTabSelected; // Add this callback

  const ButtonGroup({Key? key, required this.onTabSelected}) : super(key: key);

  @override
  _ButtonGroupState createState() => _ButtonGroupState();
}

class _ButtonGroupState extends State<ButtonGroup> {
  int selectedIndex = 0;

  // Map indices to tab identifiers
  final List<String> _tabs = ['today', 'scheduled', 'prior'];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildButton(0, 'All'),
        _buildButton(1, 'Upcoming'),
        _buildButton(2, 'Prior'),
      ],
    );
  }

  Widget _buildButton(int index, String text) {
    return ElevatedButton(
      onPressed: () {
        setState(() {
          selectedIndex = index;
        });
        widget.onTabSelected(_tabs[index]); // Notify parent
      },
      style: ElevatedButton.styleFrom(
        backgroundColor:
            selectedIndex == index ? const Color(0xFF4B6BFB) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: selectedIndex == index ? Colors.white : Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _DashboardOption extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DashboardOption({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: screenWidth < 360 ? 28 : 32,
              ),
            ),
            SizedBox(height: screenWidth < 360 ? 12 : 16),
            Text(
              title,
              style: lexand.copyWith(
                fontSize: screenWidth < 360 ? 14 : 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _confirmLogout(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop(); // Close dialog
              await _performLogout(context);
            },
            child: const Text('Logout'),
          ),
        ],
      );
    },
  );
}

Future<void> _performLogout(BuildContext context) async {
  try {
    // Sign out from Firebase
    await FirebaseAuth.instance.signOut();

    // Sign out from Google if using Google Sign-In
    await GoogleSignIn().signOut();

    // Navigate to login screen and clear stack
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const SignInScreen()),
      (Route<dynamic> route) => false,
    );
  } catch (e) {
    print('Error during logout: $e');
    // Show error message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Logout failed. Please try again.'),
      ),
    );
  }
}
