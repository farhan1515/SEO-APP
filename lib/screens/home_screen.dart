import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:seo_app/screens/pending_approval_screen.dart';
import 'package:seo_app/screens/post_detail_screen.dart';
import 'package:seo_app/screens/profile_list_screen.dart';
import 'package:seo_app/screens/settings_screen.dart';
import 'package:seo_app/theme/text_style.dart';
import 'package:seo_app/widgets/filter_dialog.dart';
import 'package:seo_app/widgets/show_post_list.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  final ValueNotifier<List<Map<String, dynamic>>> _upcomingPostsNotifier =
      ValueNotifier<List<Map<String, dynamic>>>([]);
  final ValueNotifier<int> _currentCarouselIndexNotifier =
      ValueNotifier<int>(0);
  final ValueNotifier<String> _selectedTab = ValueNotifier('scheduled');
  final ValueNotifier<Map<String, dynamic>> _filtersNotifier =
      ValueNotifier<Map<String, dynamic>>({});
  final ValueNotifier<bool> _isLoading = ValueNotifier<bool>(true);

  List<String> _availableProfiles = [];
  List<Map<String, dynamic>> _cachedPosts = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    // Load cached data first if available
    if (_cachedPosts.isNotEmpty) {
      _upcomingPostsNotifier.value = _cachedPosts;
      _isLoading.value = false;
    }

    // Then fetch fresh data in background
    await Future.wait([
      _fetchUpcomingPosts(),
      _fetchAllProfileNames(),
    ]);
  }

  Future<List<String>> _fetchAllProfileNames() async {
    try {
      final profilesSnapshot = await FirebaseFirestore.instance
          .collectionGroup('profiles')
          .get(const GetOptions(source: Source.cache))
          .then((value) => value)
          .catchError((_) =>
              FirebaseFirestore.instance.collectionGroup('profiles').get());

      return profilesSnapshot.docs
          .map((doc) => doc.data()['businessDetails']['name'] as String? ?? '')
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList();
    } catch (e) {
      debugPrint('Error fetching profile names: $e');
      return [];
    }
  }

  Future<void> _fetchUpcomingPosts() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final now = DateTime.now().toIso8601String();

      // First try to get from cache
      final cachedSnapshot = await FirebaseFirestore.instance
          .collection('post_requests')
          .where('scheduled_date', isGreaterThanOrEqualTo: now)
          .where('flyer_approval_status', isEqualTo: 'approved')
          .orderBy('scheduled_date')
          .get(const GetOptions(source: Source.cache));

      if (cachedSnapshot.docs.isNotEmpty) {
        _cachedPosts = cachedSnapshot.docs.map((doc) => doc.data()).toList();
        _upcomingPostsNotifier.value = _cachedPosts;
      }

      // Then get from server
      final serverSnapshot = await FirebaseFirestore.instance
          .collection('post_requests')
          .where('scheduled_date', isGreaterThanOrEqualTo: now)
          .where('flyer_approval_status', isEqualTo: 'approved')
          .orderBy('scheduled_date')
          .get();

      if (serverSnapshot.docs.isNotEmpty) {
        _cachedPosts = serverSnapshot.docs.map((doc) => doc.data()).toList();
        _upcomingPostsNotifier.value = _cachedPosts;
      }
    } catch (e) {
      debugPrint('Error fetching posts: $e');
    } finally {
      _isLoading.value = false;
    }
  }

  String _formatScheduledDateTime(String date, String time) {
    try {
      final dateObj = DateTime.parse(date);
      final month = _getMonthShortName(dateObj.month);
      return '$month ${dateObj.day.toString().padLeft(2, '0')} ${dateObj.year}';
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
    _selectedTab.value = tab;
  }

  @override
  void dispose() {
    _upcomingPostsNotifier.dispose();
    _currentCarouselIndexNotifier.dispose();
    _selectedTab.dispose();
    _isLoading.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final User? user = FirebaseAuth.instance.currentUser;
    final String? displayName = user?.displayName;
    final String? photoURL = user?.photoURL;
    final String userId = user?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: Stack(
        children: [
          // Carousel section
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 310,
              child: ValueListenableBuilder<bool>(
                valueListenable: _isLoading,
                builder: (context, isLoading, _) {
                  if (isLoading) {
                    return _buildLoadingCarousel();
                  }
                  return ValueListenableBuilder<List<Map<String, dynamic>>>(
                    valueListenable: _upcomingPostsNotifier,
                    builder: (context, upcomingPosts, _) {
                      if (upcomingPosts.isEmpty) {
                        return _buildEmptyCarousel();
                      }
                      return _buildPostsCarousel(upcomingPosts);
                    },
                  );
                },
              ),
            ),
          ),

          // Top profile section
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildProfileSection(userId, displayName, photoURL),
          ),

          // Explore Feed section
          Positioned(
            top: 300,
            left: 10,
            right: 20,
            child: _buildFeedHeader(),
          ),

          // ButtonGroup and PostListScreen section
          Positioned(
            top: 370,
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              children: [
                ButtonGroup(onTabSelected: _onTabSelected),
                //const SizedBox(height: 8),
                Expanded(child: _buildPostList(userId)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCarousel() {
    return Container(
      height: 290,
      color: Colors.deepPurple.shade900,
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyCarousel() {
    return Container(
      height: 270,
      color: Colors.deepPurple.shade900,
      child: Center(
        child: Text(
          'No upcoming posts with approved flyers',
          style: mont.copyWith(color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildPostsCarousel(List<Map<String, dynamic>> posts) {
    return Column(
      children: [
        Expanded(
          child: CarouselSlider(
            options: CarouselOptions(
              height: 290,
              viewportFraction: 1.0,
              autoPlay: true,
              enlargeCenterPage: false,
              onPageChanged: (index, reason) {
                _currentCarouselIndexNotifier.value = index;
              },
            ),
            items: posts.map((post) => _buildCarouselItem(post)).toList(),
          ),
        ),
        const SizedBox(height: 10),
        ValueListenableBuilder<int>(
          valueListenable: _currentCarouselIndexNotifier,
          builder: (context, currentIndex, _) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                posts.length,
                (index) => Container(
                  width: index == currentIndex ? 20 : 10,
                  height: 10,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(index == currentIndex ? 2 : 5),
                    color: index == currentIndex
                        ? Colors.white
                        : Colors.white.withOpacity(0.4),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildProfileSection(
      String userId, String? displayName, String? photoURL) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 20,
        right: 20,
      ),
      child: Container(
        height: 100,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(35),
            bottomRight: Radius.circular(35),
          ),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 18,
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ProfileListScreen(userId: userId),
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 25,
                        backgroundImage:
                            photoURL != null ? NetworkImage(photoURL) : null,
                        child: photoURL == null
                            ? const Icon(Icons.person, color: Colors.white)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Hi, ${displayName?.split(' ')[0] ?? 'User'}!',
                      style: mont.copyWith(fontSize: 18, color: Colors.black),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(SolarIconsOutline.heart),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => PendingApprovalsScreen()),
                      ),
                      color: Colors.black,
                    ),
                    IconButton(
                      icon: const Icon(SolarIconsOutline.settings),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => SettingScreen()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedHeader() {
    return Row(
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
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ElevatedButton.icon(
            icon: const Icon(SolarIconsOutline.filter,
                color: Colors.white, size: 20),
            label: Text(
              'Filter',
              style: mont.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3E1885),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              final allProfileNames = await _fetchAllProfileNames();
              showDialog(
                context: context,
                builder: (context) => FilterDialog(
                  onApplyFilters: (filters) => _filtersNotifier.value = filters,
                  allProfileNames: allProfileNames,
                ),
              );
            },
          ),
        )
      ],
    );
  }

  Widget _buildPostList(String userId) {
    return ValueListenableBuilder<String>(
      valueListenable: _selectedTab,
      builder: (context, selectedTab, _) {
        return ValueListenableBuilder<Map<String, dynamic>>(
          valueListenable: _filtersNotifier,
          builder: (context, filters, _) {
            return RepaintBoundary(
              child: PostListScreen(
                key: PageStorageKey('$selectedTab-${filters.hashCode}'),
                selectedTab: selectedTab,
                userId: userId,
                filters: filters,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCarouselItem(Map<String, dynamic> post) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PostDetailScreen(
            post: {
              'title': post['title'] ?? 'No Title',
              'description': post['description'] ?? '',
              'highlight_text': post['highlighted_text'],
              'image_base64': post['image_base64'],
              'flyer_base64': post['flyer_base64'], // Added flyer_base64
              'posted_by': post['user_name'] ?? 'Anonymous',
              'created_at': post['created_at'] ?? DateTime.now().toString(),
              'platforms': post['platforms'] ?? [],
              'user_id': post['user_id'] ?? 'Anonymous',
              'user_name': post['user_name'] ?? 'Anonymous',
              'id': post['id'] ?? '',
              'profile_name': post['profile_name'] ?? 'No Profile',
              'scheduled_date': post['scheduled_date'],
              'scheduled_time': post['scheduled_time'],
              'scheduled_timezone': post['scheduled_timezone'],
              'recurring_schedule': post['recurring_schedule'],
              'reference_link':
                  post['reference_link'] ?? '', // Added reference_link
            },
          ),
        ),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width,
        height: 300,
        child: Stack(
          children: [
            // Flyer image with proper handling
            if (post['flyer_base64'] != null &&
                post['flyer_base64'].toString().isNotEmpty)
              Image.memory(
                base64Decode(post['flyer_base64']
                    .split(',')
                    .last), // Handle data URI if needed
                width: double.infinity,
                height: 310,
                fit: BoxFit.cover,
                color: Colors.black.withOpacity(0.3),
                colorBlendMode: BlendMode.darken,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.deepPurple.shade900,
                  child: Icon(Icons.broken_image, color: Colors.white),
                ),
              )
            else
              Container(
                width: double.infinity,
                height: 290,
                color: Colors.deepPurple.shade900,
              ),

            // Content overlay
            Positioned(
              top: 195,
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
                        Colors.black.withOpacity(0.8),
                      ],
                    ),
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  post['title'] ?? 'No Title',
                                  style: mont.copyWith(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                _formatScheduledDateTime(
                                  post['scheduled_date'] ?? '',
                                  post['scheduled_time'] ?? '',
                                ),
                                style: mont.copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
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
        setState(() => selectedIndex = index);
        widget.onTabSelected(_tabs[index]);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color.fromRGBO(62, 24, 133, 0.15)
              : const Color(0xFFF6F6F6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: lexand.copyWith(
            color:
                isSelected ? const Color(0xFF3E1885) : const Color(0xFFCECECE),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
