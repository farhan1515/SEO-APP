import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seo_app/screens/post_detail_screen.dart';
import 'package:seo_app/screens/post_request_screen.dart';
import 'package:seo_app/theme/text_style.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:lucide_icons_flutter/lucide_icons.dart';

class PostListScreen extends StatelessWidget {
  final List<String> selectedPlatforms;
  final String selectedTab;
  final String userId;

  const PostListScreen({
    Key? key,
    required this.selectedPlatforms,
    required this.selectedTab,
    required this.userId,
  }) : super(key: key);

  void _navigateToEditScreen(
      BuildContext context, String docId, Map<String, dynamic> data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostRequestScreen(
          postId: docId,
          existingData: data,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: _getPostsStream(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.article_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No posts yet',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            }

            // Filter posts based on selected platforms
            final filteredDocs = selectedPlatforms.isEmpty
                ? snapshot.data!.docs
                : snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final platforms =
                        List<String>.from(data['platforms'] ?? []);
                    return selectedPlatforms.any((platform) =>
                        platforms.contains(platform.toLowerCase()));
                  }).toList();

            if (filteredDocs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.filter_list,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No posts found for selected platforms',
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
                            'id': doc.id, // Add document ID to post data
                          },
                        ),
                      ),
                    );
                  },
                  child: Card(
                    color: Colors.white,
                    margin: const EdgeInsets.all(6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            child: data['image_base64'] != null
                                ? Padding(
                                    padding: const EdgeInsets.all(6.0),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.memory(
                                        base64Decode(data['image_base64']),
                                        height: 120,
                                        width: 120,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Container(
                                            height: 120,
                                            width: 120,
                                            color: Colors.grey[300],
                                            child: const Icon(
                                                Icons.image_not_supported,
                                                color: Colors.grey),
                                          );
                                        },
                                      ),
                                    ),
                                  )
                                : ClipRRect(
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(16),
                                      bottomLeft: Radius.circular(16),
                                    ),
                                    child: Container(
                                      height: 120,
                                      width: 120,
                                      color: Colors.grey[300],
                                      child: const Icon(
                                          Icons.image_not_supported,
                                          color: Colors.grey),
                                    ),
                                  ),
                          ),
                          Expanded(
                            child: Padding(
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
                                  const Spacer(),
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
                                ],
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 12,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  children: (data['platforms']
                                              as List<dynamic>? ??
                                          [])
                                      .map<Widget>(
                                        (platform) => Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 4),
                                          child: _getPlatformIcon(platform),
                                        ),
                                      )
                                      .toList(),
                                ),
                                // if (data['user_id'] == userId)
                                //   IconButton(
                                //     icon: const Icon(Icons.edit,
                                //         color: Colors.blue),
                                //     onPressed: () => _navigateToEditScreen(
                                //         context, doc.id, data),
                                //     padding: EdgeInsets.zero,
                                //     constraints: const BoxConstraints(),
                                //     iconSize: 20,
                                //   ),
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
          },
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

  Stream<QuerySnapshot> _getPostsStream() {
    if (selectedTab == 'prior') {
      return FirebaseFirestore.instance
          .collection('post_requests')
          .where('user_id', isEqualTo: userId)
          .orderBy('created_at', descending: true)
          .snapshots();
    } else {
      // Default stream for "Today" and "Scheduled"
      return FirebaseFirestore.instance
          .collection('post_requests')
          .orderBy('created_at', descending: true)
          .snapshots();
    }
  }
}
