import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seo_app/screens/post_detail_screen.dart';
import 'package:seo_app/theme/text_style.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:lucide_icons_flutter/lucide_icons.dart';

class PostListScreen extends StatefulWidget {
  final List<String> selectedPlatforms;
  final String selectedTab;
  final String userId;

  const PostListScreen({
    Key? key,
    required this.selectedPlatforms,
    required this.selectedTab,
    required this.userId,
  }) : super(key: key);

  @override
  State<PostListScreen> createState() => _PostListScreenState();
}

class _PostListScreenState extends State<PostListScreen> {
  late Stream<QuerySnapshot> _postsStream;
  List<DocumentSnapshot> _cachedPosts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _setupPostsStream();
  }

  @override
  void didUpdateWidget(PostListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedPlatforms != widget.selectedPlatforms ||
        oldWidget.selectedTab != widget.selectedTab ||
        oldWidget.userId != widget.userId) {
      _setupPostsStream();
    }
  }

  void _setupPostsStream() {
    setState(() {
      _isLoading = true;
    });

    _postsStream = _getPostsStream();

    // Load initial data
    _postsStream.first.then((snapshot) {
      if (mounted) {
        setState(() {
          _cachedPosts = snapshot.docs;
          _isLoading = false;
        });
      }
    });
  }

  Stream<QuerySnapshot> _getPostsStream() {
    if (widget.selectedTab == 'prior') {
      return FirebaseFirestore.instance
          .collection('post_requests')
          .where('user_id', isEqualTo: widget.userId)
          .orderBy('created_at', descending: true)
          .snapshots();
    } else {
      return FirebaseFirestore.instance
          .collection('post_requests')
          .orderBy('created_at', descending: true)
          .snapshots();
    }
  }

  List<DocumentSnapshot> _filterPostsByPlatform(List<DocumentSnapshot> docs) {
    if (widget.selectedPlatforms.isEmpty) {
      return docs;
    }

    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final platforms = List<String>.from(data['platforms'] ?? []);
      return widget.selectedPlatforms.any((platform) =>
          platforms.contains(platform.toLowerCase()));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: _postsStream,
          builder: (context, snapshot) {
            // Show loading indicator only on initial load
            if (_isLoading) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            // Handle errors
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }

            // Update cache when new data arrives
            if (snapshot.hasData) {
              _cachedPosts = snapshot.data!.docs;
            }

            // Filter posts by platform
            final filteredDocs = _filterPostsByPlatform(_cachedPosts);

            // Show "no posts" message when appropriate
            if (filteredDocs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.selectedPlatforms.isEmpty
                          ? Icons.article_outlined
                          : Icons.filter_list,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.selectedPlatforms.isEmpty
                          ? 'No posts yet'
                          : 'No posts found for selected platforms',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              itemCount: filteredDocs.length,
              itemBuilder: (context, index) {
                final doc = filteredDocs[index];
                final data = doc.data() as Map<String, dynamic>;

                String timeAgo = '';
                if (data['created_at'] != null) {
                  final timestamp = data['created_at'] as Timestamp;
                  final dateTime = timestamp.toDate();
                  timeAgo = timeago.format(dateTime);
                }

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PostDetailScreen(
                          post: {
                            'title': data['title'] ?? 'Untitled',
                            'description': data['description'] ?? '',
                            'highlight_text': data['highlighted_text'],
                            'image_base64': data['image_base64'],
                            'posted_by': data['user_name'] ?? 'Anonymous',
                            'created_at':
                                data['created_at']?.toDate().toString() ??
                                    DateTime.now().toString(),
                            'platforms': data['platforms'] ?? [],
                            'user_id': data['user_id'] ?? 'Anonymous',
                            'user_name': data['user_name'] ?? 'Anonymous',
                            'id': doc.id,
                          },
                        ),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 1,
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (data['image_base64'] != null)
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: Container(
                                width: double.infinity, // Take full width
                                child: _buildImage(data['image_base64']),
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['title'] ?? 'Untitled',
                                style: texts.copyWith(
                                    color: const Color(0xFF001d35),
                                    fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                data['description'] ?? '',
                                style: texts.copyWith(
                                    color: const Color(0xFF545454),
                                    fontSize: 13),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              if (data['highlighted_text'] != null)
                                Text(
                                  data['highlighted_text'],
                                  style: texts.copyWith(
                                      color: const Color(0xFF545454),
                                      fontSize: 12),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'BY: ${data['user_name'] ?? 'Anonymous'}',
                                      style: texts.copyWith(
                                          fontSize: 12,
                                          color: const Color(0xFFff9500)),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    timeAgo,
                                    style: texts.copyWith(
                                      color: const Color(0xFF23a93b)
                                          .withOpacity(0.5),
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (data['platforms'] != null &&
                                  data['platforms'].isNotEmpty)
                                Wrap(
                                  spacing: 8,
                                  children:
                                      (data['platforms'] as List<dynamic>)
                                          .map<Widget>((platform) {
                                    return _getPlatformIcon(platform);
                                  }).toList(),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildImage(String imageBase64) {
    try {
      return Image.memory(
        base64Decode(imageBase64),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorWidget();
        },
      );
    } catch (e) {
      return _buildErrorWidget();
    }
  }

  Widget _buildErrorWidget() {
    return Container(
      color: Colors.grey[300],
      child: const Center(
        child: Icon(
          Icons.image_not_supported,
          color: Colors.grey,
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
}