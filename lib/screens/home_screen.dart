import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:seo_app/screens/dashboard_screen.dart';
import 'package:seo_app/screens/post_detail_screen.dart';
import 'package:seo_app/screens/profile_screen.dart';
import 'package:seo_app/theme/text_style.dart';
import 'package:seo_app/widgets/show_post_list.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:carousel_slider/carousel_slider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _upcomingPosts = [];
  int _currentCarouselIndex = 0;
  String _selectedTab = 'today'; // Default tab

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

    setState(() {
      _upcomingPosts = postsSnapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  String _formatScheduledDateTime(String date, String time) {
    try {
      final dateObj = DateTime.parse(date);
      final month = _getMonthShortName(dateObj.month);
      return '$month ${dateObj.day.toString().padLeft(2, '0')}\n${dateObj.year}';
    } catch (e) {
      return '$date $time';
    }
  }

  String _getMonthShortName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }

  void _onTabSelected(String tab) {
    setState(() {
      _selectedTab = tab;
    });
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final String? displayName = user?.displayName;
    final String? photoURL = user?.photoURL;

    return Scaffold(
      backgroundColor: Color(0xFFFFFFFF),
      body: Stack(
        children: [
          // Carousel section
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              children: [
                Expanded(
                  child: CarouselSlider(
                    options: CarouselOptions(
                      height: MediaQuery.of(context).size.height,
                      viewportFraction: 1.0,
                      autoPlay: true,
                      enlargeCenterPage: false,
                      onPageChanged: (index, reason) {
                        setState(() {
                          _currentCarouselIndex = index;
                        });
                      },
                    ),
                    items: _upcomingPosts.map((post) {
                      return _buildCarouselItem(context, post);
                    }).toList(),
                  ),
                ),
                // Indicator dots
                if (_upcomingPosts.isNotEmpty) const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _upcomingPosts.length,
                    (index) => Container(
                      width: index == _currentCarouselIndex ? 20 : 10,
                      height: 10,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                            index == _currentCarouselIndex ? 2 : 5),
                        color: index == _currentCarouselIndex
                            ? Colors.white
                            : Colors.white.withOpacity(0.4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // Top profile section
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
                        IconButton(
                          icon: Icon(SolarIconsOutline.heart),
                          onPressed: () {},
                          color: Colors.black,
                        ),
                        IconButton(
                          icon: Icon(SolarIconsOutline.settings),
                          onPressed: () {
                            // Navigate to ProfileScreen
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProfileScreen(
                                  userId:
                                      FirebaseAuth.instance.currentUser!.uid,
                                ),
                              ),
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

          // Explore Feed section
          Positioned(
            top: 330,
            left: 10,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  ' Feed',
                  style: mont.copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF3E1885),
                  ),
                ),
                //  DropdownButton(items: [], onChanged: (T? value) {  }, ),
                Image.asset(
                  'assets/icons/seo_logo.png', // Replace with your image path
                  height: 40, // Adjust size as needed
                  width: 40,
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ),

          // ButtonGroup and PostListScreen section
          Positioned(
            top: 400, // Adjust this value based on your layout
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              children: [
                ButtonGroup(
                  onTabSelected: _onTabSelected,
                ),
                // const SizedBox(height: 10),
                Expanded(
                  child: PostListScreen(
                    selectedPlatforms: [], // Pass selected platforms if any
                    selectedTab: _selectedTab,
                    userId: FirebaseAuth.instance.currentUser!.uid,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarouselItem(BuildContext context, Map<String, dynamic> post) {
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
        width: MediaQuery.of(context).size.width,
        height: 310, // Set the height to 310
        child: Stack(
          children: [
            // Background image
            Container(
              width: double.infinity,
              height: 310, // Set the height to 310
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade900,
                image: post['image_base64'] != null
                    ? DecorationImage(
                        image: MemoryImage(base64Decode(post['image_base64'])),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          Colors.black.withOpacity(0.3),
                          BlendMode.darken,
                        ),
                      )
                    : null,
              ),
            ),

            // Content overlay positioned within the 310 height
            Positioned(
              top: 150,
              left: 0,
              right: 0,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                    backgroundBlendMode: BlendMode.darken,
                  ),
                  child: ClipRRect(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 26, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // UPCOMING tag
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.shade700,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'UPCOMING',
                              style: mont.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Event details
                          Text(
                            post['title'] ?? 'No Title',
                            style: mont.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            post['description'] ?? 'No Description',
                            style: mont.copyWith(
                              fontSize: 12,
                              color: Color.fromRGBO(255, 255, 255, 0.77),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _formatScheduledDateTime(
                              post['scheduled_date'] ?? '',
                              post['scheduled_time'] ?? '',
                            ),
                            style: mont.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
