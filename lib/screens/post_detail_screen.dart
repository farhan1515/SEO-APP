import 'package:flutter/material.dart';
import 'package:seo_app/screens/post_request_screen.dart';
import 'package:seo_app/theme/text_style.dart';
import 'package:seo_app/screens/chat_screen.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'dart:convert';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:seo_app/firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class PostDetailScreen extends StatelessWidget {
  final Map<String, dynamic> post;

  const PostDetailScreen({
    Key? key,
    required this.post,
  }) : super(key: key);

  void _handleChatNavigation(BuildContext context) {
    // Get the user_id and user_name from the post data
    final recipientId = post['user_id']?.toString();
    final recipientName = post['user_name']?.toString();

    // Debug prints to verify the data
    print('Recipient ID: $recipientId');
    print('Recipient Name: $recipientName');

    // Check if current user is logged in
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to chat with the designer'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if trying to chat with self
    if (currentUser.uid == recipientId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot chat with yourself'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Verify recipient data exists
    if (recipientId != null &&
        recipientId.isNotEmpty &&
        recipientName != null &&
        recipientName.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            recipientId: recipientId,
            recipientName: recipientName,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to initiate chat. User details are missing.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToEditScreen(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => PostRequestScreen(
          postId: post['id'], // Make sure you're passing document ID
          existingData: post,
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: const Text('Are you sure you want to delete this post?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context); // Close dialog
                await _deletePost(context); // Pass context here
                Navigator.pop(context); // Close detail screen
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deletePost(BuildContext context) async {
    // Add context parameter
    try {
      await FirebaseFirestore.instance
          .collection('post_requests')
          .doc(post['id'])
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting post: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFc9dee7),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with back button
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios),
                      color: Colors.black87,
                    ),
                    Text(
                      'Post Details',
                      style: lexand.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 40), // For balance
                    if (FirebaseAuth.instance.currentUser?.uid ==
                        post['user_id'])
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _navigateToEditScreen(context),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _confirmDelete(context),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              // Main Content Card
              Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image Section
                    if (post['image_base64'] != null)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        child: Image.memory(
                          base64Decode(post['image_base64']),
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                      ),

                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title
                          Text(
                            post['title'] ?? 'Untitled',
                            style: lexand.copyWith(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Posted by and timestamp
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Posted by ${post['posted_by'] ?? 'Anonymous'}',
                                      style: lexand.copyWith(
                                        fontSize: 14,
                                        color: Colors.black87,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      timeago.format(
                                        DateTime.parse(post['created_at'] ??
                                            DateTime.now().toString()),
                                      ),
                                      style: lexand.copyWith(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Description Section
                          _SectionTitle('Description'),
                          const SizedBox(height: 8),
                          Text(
                            post['description'] ?? 'No description available',
                            style: lexand.copyWith(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 24),

                          // Highlights Section
                          _SectionTitle('Highlights'),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.all(16),
                            // decoration: BoxDecoration(
                            //   color: const Color(0xFF4B6BFB).withOpacity(0.1),
                            //   borderRadius: BorderRadius.circular(12),
                            //   border: Border.all(
                            //     color: const Color(0xFF4B6BFB).withOpacity(0.2),
                            //   ),
                            // ),
                            child: Text(
                              post['highlight_text'] ??
                                  'No highlights available',
                              style: lexand.copyWith(
                                fontSize: 16,
                                color: Colors.black87,
                                height: 1.5,
                              ),
                            ),
                          ),
                          // Text(
                          //   post['user_name'] ?? 'No highlights available',
                          //   style: lexand.copyWith(
                          //     fontSize: 16,
                          //     color: Colors.black87,
                          //     height: 1.5,
                          //   ),
                          // ),
                          if (post['platforms'] != null &&
                              (post['platforms'] as List).isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 16,
                              ),
                              child: Row(
                                children: (post['platforms'] as List<dynamic>)
                                    .map<Widget>((platform) => Padding(
                                          padding:
                                              const EdgeInsets.only(right: 8),
                                          child: _getPlatformIcon(platform),
                                        ))
                                    .toList(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      // Chat Button
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _handleChatNavigation(context),
        backgroundColor: const Color(0xFF4B6BFB),
        icon: const Icon(
          Icons.chat_bubble_outline,
          color: Colors.white,
        ),
        label: const Text(
          'Chat with Customer',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: lexand.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF4B6BFB),
      ),
    );
  }
}

Widget _getPlatformIcon(String platform) {
  switch (platform.toLowerCase()) {
    case 'facebook':
      return Icon(LucideIcons.facebook, size: 20, color: Colors.black);
    case 'instagram':
      return Icon(LucideIcons.instagram, size: 20, color: Colors.black);
    case 'whatsapp':
      return Image.asset(
        "assets/icons/whatsapp.png",
        height: 20,
        width: 20,
      );
    default:
      return Icon(LucideIcons.link, size: 20, color: Colors.white);
  }
}
