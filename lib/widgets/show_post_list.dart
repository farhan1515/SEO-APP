import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seo_app/screens/chat_screen.dart';
import 'package:seo_app/screens/post_detail_screen.dart';
import 'package:seo_app/theme/text_style.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Custom Marquee Widget for auto-scrolling text
class MarqueeWidget extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Duration scrollDuration;
  final Duration pauseDuration;
  final double velocity;

  const MarqueeWidget({
    Key? key,
    required this.text,
    required this.style,
    this.scrollDuration = const Duration(seconds: 10),
    this.pauseDuration = const Duration(seconds: 2),
    this.velocity = 50.0,
  }) : super(key: key);

  @override
  State<MarqueeWidget> createState() => _MarqueeWidgetState();
}

class _MarqueeWidgetState extends State<MarqueeWidget>
    with TickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isScrolling = false;
  Timer? _periodicTimer;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animationController = AnimationController(
      duration: widget.scrollDuration,
      vsync: this,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScrolling();

      // Add a periodic check to ensure scrolling continues
      _periodicTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
        if (mounted && !_isScrolling) {
          _startScrolling();
        }
      });
    });
  }

  void _startScrolling() {
    if (!mounted) return;

    Future.delayed(widget.pauseDuration, () {
      if (!mounted) return;

      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll > 0) {
        setState(() {
          _isScrolling = true;
        });

        // Reset animation controller for the next cycle
        _animationController.reset();

        _animation = Tween<double>(
          begin: 0.0,
          end: maxScroll,
        ).animate(CurvedAnimation(
          parent: _animationController,
          curve: Curves.linear,
        ));

        _animation.addListener(() {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_animation.value);
          }
        });

        _animationController.forward().then((_) {
          if (mounted) {
            setState(() {
              _isScrolling = false;
            });
            _scrollController.jumpTo(0);
            // Always restart the cycle to ensure continuous scrolling
            _startScrolling();
          }
        }).catchError((error) {
          // If there's an error, still restart the cycle
          if (mounted) {
            _scrollController.jumpTo(0);
            _startScrolling();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        );
        textPainter.layout();

        final textWidth = textPainter.width;
        final containerWidth = constraints.maxWidth;

        // Only show marquee if text is wider than container
        if (textWidth <= containerWidth) {
          return Text(
            widget.text,
            style: widget.style,
            overflow: TextOverflow.ellipsis,
          );
        }

        return SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics:
              const NeverScrollableScrollPhysics(), // Disable manual scrolling
          child: Text(
            widget.text,
            style: widget.style,
          ),
        );
      },
    );
  }
}

class PostListScreen extends StatefulWidget {
  final String selectedTab; // 'today', 'scheduled', or 'prior'
  final String userId;
  final Map<String, dynamic>? filters;

  const PostListScreen({
    Key? key,
    required this.selectedTab,
    required this.userId,
    this.filters,
  }) : super(key: key);

  @override
  State<PostListScreen> createState() => _PostListScreenState();
}

class _PostListScreenState extends State<PostListScreen>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  List<DocumentSnapshot> _posts = [];
  bool _isLoading = true;
  bool _isMounted = false;
  Map<String, String> _profileNames = {};
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  bool get wantKeepAlive => true; // Preserve state when switching tabs

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _fetchPosts();
  }

  @override
  void didUpdateWidget(PostListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedTab != widget.selectedTab ||
        oldWidget.userId != widget.userId ||
        oldWidget.filters != widget.filters) {
      _fetchPosts(); // Fetch posts if tab, user, or filters change
    }
  }

  @override
  void dispose() {
    _isMounted = false;
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchPosts() async {
    if (!_isMounted) return;

    setState(() {
      _isLoading = true;
      _posts = [];
      _profileNames = {};
    });

    try {
      // Base query
      Query<Map<String, dynamic>> query =
          FirebaseFirestore.instance.collection('post_requests');

      // Apply tab-specific filtering first
      final now = DateTime.now().toIso8601String();
      switch (widget.selectedTab) {
        case 'today':
          // Show all posts, sorted by created_at descending
          query = query.orderBy('created_at', descending: true);
          break;
        case 'scheduled':
          // Show only upcoming posts
          query = query
              .where('scheduled_date', isGreaterThanOrEqualTo: now)
              .orderBy('scheduled_date', descending: true);
          break;
        case 'prior':
          // Show all posts for the logged-in user, sorted by created_at descending
          query = query
              .where('user_id', isEqualTo: widget.userId)
              .orderBy('created_at', descending: true);
          break;
      }

      // Apply filters if they exist
      if (widget.filters != null && widget.filters!.isNotEmpty) {
        final filterType = widget.filters!['filterType'];
        print(
            'Applying filter type: $filterType with filters: ${widget.filters}');
        switch (filterType) {
          case 'profile_name':
            if (widget.filters!['profileName'] != null) {
              print(
                  'Filtering by profile name: ${widget.filters!['profileName']}');
              query = query.where('profile_name',
                  isEqualTo: widget.filters!['profileName']);
            }
            break;
          case 'title':
            if (widget.filters!['title'] != null &&
                widget.filters!['title'].isNotEmpty) {
              final searchText = widget.filters!['title'].toLowerCase();
              query = query
                  .where('title_lowercase', isGreaterThanOrEqualTo: searchText)
                  .where('title_lowercase', isLessThan: '$searchText\uf8ff');
            }
            break;
          case 'scheduled_date':
            if (widget.filters!['date'] != null) {
              final date = widget.filters!['date'] as DateTime;
              final startOfDay = DateTime(date.year, date.month, date.day);
              final endOfDay = startOfDay.add(const Duration(days: 1));
              query = query
                  .where('scheduled_date',
                      isGreaterThanOrEqualTo: startOfDay.toIso8601String())
                  .where('scheduled_date',
                      isLessThan: endOfDay.toIso8601String());
            }
            break;
        }
      }

      // Fetch the posts
      final snapshot = await query.get();

      // Log the number of documents retrieved
      print(
          'Fetched ${snapshot.docs.length} posts for tab: ${widget.selectedTab}');

      // Apply additional client-side filtering for title if needed
      List<DocumentSnapshot> filteredDocs = snapshot.docs;
      if (widget.filters != null &&
          widget.filters!['filterType'] == 'title' &&
          widget.filters!['title'] != null &&
          widget.filters!['title'].isNotEmpty) {
        final searchText = widget.filters!['title'].toLowerCase();
        filteredDocs = filteredDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final title = data['title']?.toString().toLowerCase() ?? '';
          return title.contains(searchText);
        }).toList();
      }

      // Fetch profile names for each post
      final postsWithProfiles = await Future.wait(filteredDocs.map((doc) async {
        final data = doc.data() as Map<String, dynamic>;
        String profileName = data['profile_name'] ?? 'No Profile';
        print('Post ${doc.id} has profile_name: "$profileName"');
        return {
          'doc': doc,
          'profileName': profileName,
        };
      }));

      if (_isMounted) {
        setState(() {
          _posts = postsWithProfiles
              .map((e) => e['doc'] as DocumentSnapshot)
              .toList();
          _profileNames = Map.fromIterable(
            postsWithProfiles,
            key: (e) => (e['doc'] as DocumentSnapshot).id,
            value: (e) => e['profileName'] as String,
          );
          _isLoading = false;
        });
        _animationController.forward();
      }
    } catch (e) {
      if (_isMounted) {
        setState(() {
          _isLoading = false;
        });
      }
      print('Error fetching posts: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading posts: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Loading posts...',
              style: poppins.copyWith(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (_posts.isEmpty) {
      String message = 'No posts found';
      if (widget.filters != null && widget.filters!.isNotEmpty) {
        final filterType = widget.filters!['filterType'];
        switch (filterType) {
          case 'profile_name':
            message =
                'No posts found for profile: ${widget.filters!['profileName']}';
            break;
          case 'title':
            message = 'No posts found matching: ${widget.filters!['title']}';
            break;
          case 'scheduled_date':
            message = 'No posts found for the selected date';
            break;
        }
      }

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.filters != null && widget.filters!.isNotEmpty
                  ? Icons.search_off
                  : Icons.article_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: poppins.copyWith(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            if (widget.filters != null && widget.filters!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Try adjusting your filters',
                  style: poppins.copyWith(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        double width = constraints.maxWidth;
        bool isMobile = width < 600;
        bool isTablet = width >= 600 && width < 1100;
        bool isDesktop = width >= 1100;

        // Use mobile layout for desktop/laptop
        double mainContentMaxWidth = isTablet ? 800 : double.infinity;
        double horizontalPadding = isTablet ? 20 : 0;
        double flyerImageHeight = isTablet ? 160 : 180;

        Widget listContent = ListView.separated(
          padding: const EdgeInsets.only(left: 12, right: 12, top: 4),
          itemCount: _posts.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final doc = _posts[index];
            final data = doc.data() as Map<String, dynamic>;
            final profileName = _profileNames[doc.id] ?? 'No Profile';

            String timeRemaining = '';
            if (data['scheduled_date'] != null &&
                data['scheduled_time'] != null) {
              try {
                final scheduledDateTime =
                    DateTime.parse(data['scheduled_date']);
                final scheduledTime =
                    data['scheduled_time'].toString().split(':');
                final scheduledDateTimeWithTime = DateTime(
                  scheduledDateTime.year,
                  scheduledDateTime.month,
                  scheduledDateTime.day,
                  int.parse(scheduledTime[0]),
                  int.parse(scheduledTime[1]),
                );

                final now = DateTime.now();
                final difference = scheduledDateTimeWithTime.difference(now);

                if (difference.isNegative) {
                  timeRemaining = 'Date Over';
                } else {
                  final days = difference.inDays;
                  final hours = difference.inHours % 24;

                  if (days > 0) {
                    timeRemaining =
                        '$days ${days == 1 ? 'day' : 'days'} $hours ${hours == 1 ? 'hr' : 'hrs'} to go';
                  } else {
                    timeRemaining = '$hours ${hours == 1 ? 'hr' : 'hrs'} to go';
                  }
                }
              } catch (e) {
                timeRemaining = 'Scheduled';
              }
            } else {
              timeRemaining = 'Not scheduled';
            }

            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 300 + (index * 100)),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: child,
                );
              },
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PostDetailScreen(
                      post: {
                        'title': data['title'] ?? 'Untitled',
                        'description': data['description'] ?? '',
                        'highlight_text': data['highlighted_text'],
                        'image_base64': data['image_base64'],
                        'posted_by': data['user_name'] ?? 'Anonymous',
                        'created_at': data['created_at'] is Timestamp
                            ? (data['created_at'] as Timestamp)
                                .toDate()
                                .toString()
                            : data['created_at']?.toString() ??
                                DateTime.now().toString(),
                        'platforms': data['platforms'] ?? [],
                        'user_id': data['user_id'] ?? 'Anonymous',
                        'user_name': data['user_name'] ?? 'Anonymous',
                        'id': doc.id,
                        'scheduled_date': data['scheduled_date'],
                        'scheduled_time': data['scheduled_time'],
                        'scheduled_timezone': data['scheduled_timezone'],
                        'recurring_schedule': data['recurring_schedule'],
                        'profile_id': data['profile_id'],
                        'profile_name': profileName,
                        'reference_link': data['reference_link'],
                        'flyer_base64': data['flyer_base64']
                      },
                    ),
                  ),
                ),
                child: Card(
                  elevation: 2,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (data['flyer_base64'] != null)
                        Hero(
                          tag: 'post-image-${doc.id}',
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                height: flyerImageHeight,
                                width: double.infinity,
                                child: _buildImageWithHeight(
                                    data['flyer_base64'], flyerImageHeight),
                              ),
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  flex: 2,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'For: $profileName',
                                      style: poppins.copyWith(
                                        color: Colors.blue[800],
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  flex: 1,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: timeRemaining == 'Posted'
                                          ? Colors.green.withOpacity(0.1)
                                          : Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: MarqueeWidget(
                                      text: timeRemaining,
                                      style: poppins.copyWith(
                                        color: timeRemaining == 'Posted'
                                            ? Colors.green[800]
                                            : Colors.orange[800],
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      scrollDuration:
                                          const Duration(seconds: 5),
                                      pauseDuration: const Duration(seconds: 1),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              data['title'] ?? 'Untitled',
                              style: poppins.copyWith(
                                color: const Color(0xFF001d35),
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            if (data['description'] != null &&
                                data['description'].isNotEmpty)
                              Text(
                                data['description'],
                                style: poppins.copyWith(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Colors.grey[200],
                                  child: Text(
                                    (data['user_name'] ?? 'A')[0].toUpperCase(),
                                    style: poppins.copyWith(
                                      color: const Color(0xFFff9500),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data['user_name'] ?? 'Anonymous',
                                        style: poppins.copyWith(
                                          fontSize: 14,
                                          color: const Color(0xFFff9500),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (data['platforms'] != null &&
                                    data['platforms'].isNotEmpty)
                                  Row(
                                    children: (data['platforms']
                                            as List<dynamic>)
                                        .take(3)
                                        .map<Widget>((platform) => Padding(
                                              padding: const EdgeInsets.only(
                                                  left: 8),
                                              child: _getPlatformIcon(platform),
                                            ))
                                        .toList(),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );

        // Apply layout based on screen size
        if (isTablet) {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: mainContentMaxWidth),
                child: listContent,
              ),
            ),
          );
        } else {
          // Mobile and desktop/laptop: use mobile layout without additional constraints
          return listContent;
        }
      },
    );
  }

  Widget _buildImage(String imageBase64) {
    try {
      return Image.memory(
        base64Decode(imageBase64),
        fit: BoxFit.fill,
        width: double.infinity,
        height: 200,
        errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
      );
    } catch (e) {
      return _buildErrorWidget();
    }
  }

  Widget _buildImageWithHeight(String imageBase64, double height) {
    try {
      return Image.memory(
        base64Decode(imageBase64),
        fit: BoxFit.fill,
        width: double.infinity,
        height: height,
        errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
      );
    } catch (e) {
      return _buildErrorWidget();
    }
  }

  Widget _buildErrorWidget() {
    return Container(
      height: 180,
      color: Colors.grey[200],
      child: const Center(
        child: Icon(
          Icons.image_not_supported,
          color: Colors.grey,
          size: 40,
        ),
      ),
    );
  }

  Widget _getPlatformIcon(String platform) {
    final color = Colors.grey[600];
    switch (platform.toLowerCase()) {
      case 'facebook':
        return Icon(LucideIcons.facebook, size: 20, color: color);
      case 'instagram':
        return Icon(LucideIcons.instagram, size: 20, color: color);
      case 'whatsapp':
        return Image.asset(
          "assets/icons/whatsapp.png",
          height: 20,
          width: 20,
          color: color,
        );
      default:
        return Icon(LucideIcons.link, size: 20, color: color);
    }
  }
}
