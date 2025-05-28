import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:seo_app/screens/post_detail_screen.dart';
import 'package:seo_app/theme/text_style.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:seo_app/screens/signin_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:seo_app/widgets/show_post_list.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with AutomaticKeepAliveClientMixin {
  final List<String> _selectedPlatforms = [];
  final ValueNotifier<String> _selectedTab =
      ValueNotifier('scheduled'); // Changed from 'today' to 'scheduled'
  List<Map<String, dynamic>> _upcomingPosts = [];

  @override
  bool get wantKeepAlive => true; // Preserve state when switching tabs

  @override
  void initState() {
    super.initState();
    _fetchUpcomingPosts();
  }

  Future<void> _fetchUpcomingPosts() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final now = DateTime.now();
    final postsSnapshot = await FirebaseFirestore.instance
        .collection('post_requests')
        .where('scheduled_date', isGreaterThanOrEqualTo: now.toIso8601String())
        .orderBy('scheduled_date')
        .get();

    if (mounted) {
      setState(() {
        _upcomingPosts = postsSnapshot.docs.map((doc) => doc.data()).toList();
      });
    }
  }

  void _handleTabSelected(String tab) {
    _selectedTab.value = tab; // Update ValueNotifier
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFc9dee7),
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
                    mainAxisAlignment: MainAxisAlignment.end,
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
                      const SizedBox(width: 60),
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

              Text(
                "Upcoming",
                style: lexand.copyWith(),
              ),

              // Upcoming Posts Carousel
              SizedBox(
                height: 200,
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('post_requests')
                      .where('scheduled_date',
                          isGreaterThanOrEqualTo:
                              DateTime.now().toIso8601String())
                      .orderBy('scheduled_date')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    } else if (!snapshot.hasData ||
                        snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Text(
                          'No upcoming posts',
                          style: lexand.copyWith(),
                        ),
                      );
                    } else {
                      final posts = snapshot.data!.docs
                          .map((doc) => doc.data() as Map<String, dynamic>)
                          .toList();
                      return ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: posts.length,
                        itemBuilder: (context, index) {
                          final post = posts[index];
                          return _buildPostCard(context, post);
                        },
                      );
                    }
                  },
                ),
              ),

              ButtonGroup(
                onTabSelected: _handleTabSelected,
              ),
              const SizedBox(height: 10),

              Expanded(
                child: ValueListenableBuilder<String>(
                  valueListenable: _selectedTab,
                  builder: (context, selectedTab, child) {
                    return PostListScreen(
                      selectedTab: selectedTab,
                      userId: FirebaseAuth.instance.currentUser!.uid,
                    );
                  },
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
    double size = MediaQuery.of(context).size.width * 0.12; // Responsive size

    return Tooltip(
      message: title,
      child: GestureDetector(
        onTap: () => onToggle(!isSelected),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.grey[100],
            shape: BoxShape.circle,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.2),
                      blurRadius: 8,
                      spreadRadius: 2,
                    )
                  ]
                : null,
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
              width: 2,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: size * 0.4, // Adjusted size for better centering
                height: size * 0.4,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: icon,
                ),
              ),
              if (isSelected)
                Positioned(
                  top: size * 0.08,
                  right: size * 0.08,
                  child: Container(
                    width: size * 0.25,
                    height: size * 0.25,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ButtonGroup extends StatefulWidget {
  final Function(String) onTabSelected;

  const ButtonGroup({Key? key, required this.onTabSelected}) : super(key: key);

  @override
  _ButtonGroupState createState() => _ButtonGroupState();
}

class _ButtonGroupState extends State<ButtonGroup> {
  int selectedIndex = 1;
  final List<String> _tabs = ['today', 'scheduled', 'prior'];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildButton(0, 'All'),
        _buildButton(1, 'Upcoming'),
        _buildButton(2, 'Prior'),
      ],
    );
  }

  Widget _buildButton(int index, String text) {
    bool isSelected = selectedIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedIndex = index;
        });
        widget.onTabSelected(_tabs[index]);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? Color.fromRGBO(62, 24, 133, 0.15)
              : Color(0xFFF6F6F6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: lexand.copyWith(
            color: isSelected ? const Color(0xFF3E1885) : Color(0xFFCECECE),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

String _formatScheduledDateTime(String scheduledDate, String scheduledTime) {
  try {
    // Parse the scheduled date
    final date = DateTime.parse(scheduledDate);

    // Parse the scheduled time
    final timeFormat =
        DateFormat('HH:mm'); // Assuming scheduled_time is in "HH:mm" format
    final timeOfDay = timeFormat.parse(scheduledTime);

    // Combine date and time
    final combinedDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      timeOfDay.hour,
      timeOfDay.minute,
    );

    // Format the combined DateTime
    return DateFormat('MMM dd, yyyy - hh:mm a').format(combinedDateTime);
  } catch (e) {
    print('Error formatting scheduled date and time: $e');
    return 'Invalid Date/Time';
  }
}

Widget _buildPostCard(BuildContext context, Map<String, dynamic> post) {
  return GestureDetector(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PostDetailScreen(
            post: {
              'title': post['title'] ?? 'No Title',
              'description': post['description'] ?? '',
              'highlight_text': post['highlighted_text'],
              'image_base64': post['image_base64'],
              'posted_by': post['user_name'] ?? 'Anonymous',
              'created_at': post['scheduled_date'] ??
                  DateTime.now().toString(), // Ensure valid date
              'platforms': post['platforms'] ?? [],
              'user_id': post['user_id'] ?? 'Anonymous',
              'user_name': post['user_name'] ?? 'Anonymous',
              'id': post['id'] ?? '', // Add ID if available
            },
          ),
        ),
      );
    },
    child: Container(
      constraints: const BoxConstraints(maxWidth: 500),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left side - Image
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: post['image_base64'] != null
                      ? Image.memory(
                          base64Decode(post['image_base64']),
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: Icon(LucideIcons.image,
                                size: 40, color: Colors.grey),
                          ),
                        ),
                ),
              ),
            ),

            // Middle Section - Title, Description, and Scheduled Date
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Title and Description
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post['title'] ?? 'No Title',
                          style: lexand.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          post['description'] ?? 'No Description',
                          style: lexand.copyWith(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),

                    // Scheduled Date
                    Text(
                      'Scheduled: ${_formatScheduledDateTime(post['scheduled_date'], post['scheduled_time'])}',
                      style: lexand.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Right Section - Platform Icons in a Vertical Column
            Container(
              width: 60, // Fixed width for the platform icons column
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: (post['platforms'] as List<dynamic>? ?? [])
                        .map<Widget>(
                          (platform) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: _getPlatformIcon(platform),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _getPlatformIcon(String platform) {
  switch (platform.toLowerCase()) {
    case 'facebook':
      return Icon(LucideIcons.facebook, size: 20);
    case 'instagram':
      return Icon(LucideIcons.instagram, size: 20);
    case 'whatsapp':
      return Image.asset(
        "assets/icons/whatsapp.png",
        height: 20,
        width: 20,
      );
    default:
      return Icon(LucideIcons.link, size: 20);
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
