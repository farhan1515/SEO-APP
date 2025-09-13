import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
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
  bool _isFetchingProfiles = false;

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
      debugPrint('🔍 Starting to fetch profiles for filter...');

      // Method 1: Try cloud function approach (works for SEO Managers)
      try {
        debugPrint('🌟 Trying cloud function approach...');
        final callable =
            FirebaseFunctions.instance.httpsCallable('getAllBusinessProfiles');
        final result = await callable.call();
        final profiles = result.data['profiles'] as List<dynamic>?;

        if (profiles != null && profiles.isNotEmpty) {
          final profileNames = profiles
              .map((profile) => profile['name'] as String? ?? '')
              .where((name) => name.isNotEmpty)
              .toSet()
              .toList();

          debugPrint(
              '✅ Cloud function returned ${profileNames.length} profiles');
          debugPrint('📋 Profile names: $profileNames');
          return profileNames;
        }
      } catch (cloudError) {
        debugPrint('⚠️ Cloud function failed: $cloudError');
      }

      // Method 2: Try direct Firestore collectionGroup query
      debugPrint('🔄 Trying direct Firestore query...');
      final profilesSnapshot =
          await FirebaseFirestore.instance.collectionGroup('profiles').get();

      debugPrint('📊 Found ${profilesSnapshot.docs.length} profile documents');

      final profileNames = <String>[];

      for (var doc in profilesSnapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          debugPrint('📄 Processing doc ${doc.id}: ${data.keys}');

          final businessDetails =
              data['businessDetails'] as Map<String, dynamic>?;
          if (businessDetails != null) {
            final name = businessDetails['name'] as String?;
            if (name != null && name.trim().isNotEmpty) {
              profileNames.add(name.trim());
              debugPrint('✅ Added profile: "$name"');
            } else {
              debugPrint('❌ Empty name in doc ${doc.id}');
            }
          } else {
            debugPrint('❌ No businessDetails in doc ${doc.id}');
          }
        } catch (docError) {
          debugPrint('❌ Error processing document ${doc.id}: $docError');
        }
      }

      final uniqueProfileNames = profileNames.toSet().toList();
      debugPrint(
          '🎯 Direct query result: ${uniqueProfileNames.length} unique profiles');
      debugPrint('📋 Profile names: $uniqueProfileNames');

      return uniqueProfileNames;
    } catch (e) {
      debugPrint('💥 ERROR fetching profile names: $e');
      debugPrint('📝 Error type: ${e.runtimeType}');
      if (e.toString().contains('permission')) {
        debugPrint(
            '🚫 PERMISSION DENIED - Firestore rules need to be updated!');
        debugPrint('💡 Try deploying: firebase deploy --only firestore:rules');
      }
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          double width = constraints.maxWidth;
          bool isMobile = width < 600;
          bool isTablet = width >= 600 && width < 1100;
          bool isDesktop = width >= 1100;

          // Mobile-like dimensions for all platforms
          double carouselHeight = 220; // Reduced from 220
          double profileSectionHeight = 60; // Reduced from 70
          double profileAvatarRadius = 20; // Reduced from 23
          double profileFontSize = 16; // Reduced from 18
          double feedHeaderTop = carouselHeight - 6; // Adjusted positioning
          double postListTop = feedHeaderTop + 65; // Adjusted positioning

          Widget mainContent = Stack(
            children: [
              // Carousel section - now more compact
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: carouselHeight,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _isLoading,
                    builder: (context, isLoading, _) {
                      if (isLoading) {
                        return _buildLoadingCarousel(carouselHeight);
                      }
                      return ValueListenableBuilder<List<Map<String, dynamic>>>(
                        valueListenable: _upcomingPostsNotifier,
                        builder: (context, upcomingPosts, _) {
                          if (upcomingPosts.isEmpty) {
                            return _buildEmptyCarousel(carouselHeight);
                          }
                          return CarouselSlider(
                            options: CarouselOptions(
                              height: carouselHeight,
                              viewportFraction: 1.0,
                              autoPlay: true,
                              enlargeCenterPage: false,
                              onPageChanged: (index, reason) {
                                _currentCarouselIndexNotifier.value = index;
                              },
                            ),
                            items: upcomingPosts.map((post) {
                              return Builder(
                                builder: (context) {
                                  return _buildCarouselItem(
                                      post, carouselHeight);
                                },
                              );
                            }).toList(),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),

              // Top profile section - now more compact
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  height: profileSectionHeight,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(28),
                      bottomRight: Radius.circular(28),
                    ),
                  ),
                  child: Row(
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
                              radius: profileAvatarRadius,
                              backgroundImage: photoURL != null
                                  ? NetworkImage(photoURL)
                                  : null,
                              child: photoURL == null
                                  ? const Icon(Icons.person,
                                      color: Colors.white, size: 18)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Hi, ${displayName?.split(' ')[0] ?? 'User'}!',
                            style: mont.copyWith(
                                fontSize: profileFontSize,
                                color: Colors.black,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          // IconButton(
                          //   icon: const Icon(SolarIconsOutline.heart),
                          //   onPressed: () => Navigator.push(
                          //     context,
                          //     MaterialPageRoute(
                          //         builder: (context) =>
                          //             PendingApprovalsScreen()),
                          //   ),
                          //   color: Colors.black,
                          //   iconSize: 20,
                          //   constraints: const BoxConstraints(
                          //     minWidth: 36,
                          //     minHeight: 36,
                          //   ),
                          // ),
                          IconButton(
                            icon: const Icon(SolarIconsOutline.settings),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => SettingScreen()),
                            ),
                            color: Colors.black,
                            iconSize: 20,
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Explore Feed section
              Positioned(
                top: feedHeaderTop,
                left: 10,
                right: 20,
                child: _buildFeedHeader(),
              ),

              // ButtonGroup and PostListScreen section
              Positioned(
                top: postListTop,
                left: 0,
                right: 0,
                bottom: 0,
                child: Column(
                  children: [
                    ButtonGroup(
                        onTabSelected: _onTabSelected,
                        isLargeScreen: false), // Always use mobile style
                    Expanded(child: _buildPostList(userId)),
                  ],
                ),
              ),
            ],
          );

          // On desktop/laptop, constrain width to 400px and center (reduced from 430px)
          if (isDesktop) {
            return Center(
              child: Container(
                width: 400,
                color: Colors.white,
                child: mainContent,
              ),
            );
          } else if (isTablet) {
            return Center(
              child: Container(
                width: 500, // Reduced from 800
                color: Colors.white,
                child: mainContent,
              ),
            );
          } else {
            // Mobile: use full width
            return mainContent;
          }
        },
      ),
    );
  }

  Widget _buildLoadingCarousel(double height) {
    return Container(
      height: height,
      color: Colors.deepPurple.shade900,
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyCarousel(double height) {
    return Container(
      height: height,
      color: Colors.deepPurple.shade900,
      child: Center(
        child: Text(
          'No upcoming posts with approved flyers',
          style: mont.copyWith(color: Colors.white, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildPostsCarouselResponsive(double carouselHeight) {
    // Use ValueListenableBuilder to listen for post updates
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: _upcomingPostsNotifier,
      builder: (context, posts, _) {
        if (_isLoading.value) {
          return Center(child: CircularProgressIndicator());
        }
        if (posts.isEmpty) {
          return Center(child: Text('No upcoming posts'));
        }
        return CarouselSlider(
          options: CarouselOptions(
            height: carouselHeight,
            viewportFraction: 0.9,
            enlargeCenterPage: true,
            autoPlay: posts.length > 1,
          ),
          items: posts.map((post) {
            return Builder(
              builder: (context) {
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post['title'] ?? 'No Title',
                          style: mont.copyWith(
                            fontSize: carouselHeight * 0.10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          post['description'] ?? '',
                          style: mont.copyWith(
                            fontSize: carouselHeight * 0.07,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Spacer(),
                        Text(
                          _formatScheduledDateTime(post['scheduled_date'] ?? '',
                              post['scheduled_time'] ?? ''),
                          style: mont.copyWith(
                            fontSize: carouselHeight * 0.08,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }).toList(),
        );
      },
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
            items: posts.map((post) => _buildCarouselItem(post, 290)).toList(),
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

  Widget _buildProfileSectionResponsive(
      BuildContext context, double avatarSize, double fontSize) {
    final user = FirebaseAuth.instance.currentUser;
    return Row(
      children: [
        CircleAvatar(
          radius: avatarSize / 2,
          backgroundImage:
              user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
          child: user?.photoURL == null
              ? Icon(Icons.person, size: avatarSize * 0.6)
              : null,
        ),
        SizedBox(width: avatarSize * 0.4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user?.displayName ?? 'User',
                style: mont.copyWith(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                user?.email ?? '',
                style: mont.copyWith(
                    fontSize: fontSize * 0.7, color: Colors.grey[600]),
              ),
            ],
          ),
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
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(35),
            bottomRight: Radius.circular(35),
          ),
        ),
        child: Column(
          children: [
            // SizedBox(
            //   height: 18,
            // ),
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
                        radius: 23,
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
                    // IconButton(
                    //   icon: const Icon(SolarIconsOutline.heart),
                    //   onPressed: () => Navigator.push(
                    //     context,
                    //     MaterialPageRoute(
                    //         builder: (context) => PendingApprovalsScreen()),
                    //   ),
                    //   color: Colors.black,
                    // ),
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

  Widget _buildFeedHeaderResponsive(double tabFontSize) {
    return ButtonGroup(
      onTabSelected: (tab) {
        _onTabSelected(tab);
      },
    );
  }

  Widget _buildFeedHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              ' Feed',
              style: mont.copyWith(
                fontSize: 26, // Slightly reduced
                fontWeight: FontWeight.bold,
                color: const Color(0xFF3E1885),
              ),
            ),
            ValueListenableBuilder<Map<String, dynamic>>(
              valueListenable: _filtersNotifier,
              builder: (context, filters, _) {
                if (filters.isNotEmpty && filters['filterType'] != null) {
                  return Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.filter_alt,
                            size: 14, color: Colors.orange.shade700),
                        SizedBox(width: 4),
                        Text(
                          'Filtered',
                          style: mont.copyWith(
                            fontSize: 12,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return SizedBox.shrink();
              },
            ),
          ],
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ElevatedButton.icon(
            icon: const Icon(SolarIconsOutline.filter,
                color: Colors.white, size: 18), // Reduced icon size
            label: Text(
              _isFetchingProfiles ? 'Loading...' : 'Filter',
              style: mont.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13, // Slightly reduced
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3E1885),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8), // Reduced padding
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _isFetchingProfiles
                ? null
                : () async {
                    if (_isFetchingProfiles) return;

                    setState(() {
                      _isFetchingProfiles = true;
                    });

                    try {
                      debugPrint(
                          '🔘 Filter button pressed - fetching profiles...');
                      final allProfileNames = await _fetchAllProfileNames();
                      debugPrint(
                          '🔘 Passing ${allProfileNames.length} profiles to dialog');

                      if (mounted) {
                        showDialog(
                          context: context,
                          builder: (context) => FilterDialog(
                            onApplyFilters: (filters) {
                              debugPrint('🔘 Filters applied: $filters');
                              _filtersNotifier.value = filters;
                            },
                            allProfileNames: allProfileNames,
                          ),
                        );
                      }
                    } finally {
                      if (mounted) {
                        setState(() {
                          _isFetchingProfiles = false;
                        });
                      }
                    }
                  },
          ),
        )
      ],
    );
  }

  Widget _buildPostListResponsive() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Center(child: Text('Not logged in'));
    return _buildPostList(user.uid);
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

  Widget _buildCarouselItem(Map<String, dynamic> post, double carouselHeight) {
    // Determine which flyer image to show:
    // Always show the original flyer_base64 unless updated_flyer_base64 is present and approved
    String? flyerBase64ToShow = post['flyer_base64'];
    if (post['flyer_approval_status'] == 'approved' &&
        post['updated_flyer_base64'] != null &&
        post['updated_flyer_base64'].toString().isNotEmpty) {
      flyerBase64ToShow = post['updated_flyer_base64'];
    }

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
              'flyer_base64': post['flyer_base64'],
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
              'reference_link': post['reference_link'] ?? '',
            },
          ),
        ),
      ),
      child: Container(
        width: double.infinity,
        height: carouselHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Flyer image with proper fitting, no blur on the image itself
            if (flyerBase64ToShow != null && flyerBase64ToShow.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(0),
                child: Image.memory(
                  base64Decode(flyerBase64ToShow.split(',').last),
                  width: double.infinity,
                  height: carouselHeight,
                  fit: BoxFit.fill,
                  color: Colors.black.withOpacity(0.3),
                  colorBlendMode: BlendMode.darken,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.deepPurple.shade900,
                    child: const Icon(Icons.broken_image, color: Colors.white),
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                height: carouselHeight,
                color: Colors.deepPurple.shade900,
              ),

            // Content overlay - match old code: blur only on overlay, sigma 2, gradient + white bg
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 1, sigmaY: 1),
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
                          horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.shade700,
                              borderRadius: BorderRadius.circular(16),
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
                          const SizedBox(height: 12),
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
  final bool isLargeScreen;

  const ButtonGroup({
    Key? key,
    required this.onTabSelected,
    this.isLargeScreen = false,
  }) : super(key: key);

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
