import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seo_app/theme/text_style.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:convert'; // For base64Decode

class ShowPostsScreen extends StatelessWidget {
  const ShowPostsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Column(
          children: [
            // Header Section (unchanged)
            Padding(
              padding: const EdgeInsets.all(18.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00B8D9).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.article_rounded,
                          color: Color(0xFF00B8D9),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'ALL Posts',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black87),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Posts List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('post_requests')
                    .orderBy('created_at', descending: true)
                    .snapshots(),
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

                  return ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final doc = snapshot.data!.docs[index];
                      final data = doc.data() as Map<String, dynamic>;

                      String timeAgo = '';
                      if (data['created_at'] != null) {
                        final timestamp = data['created_at'] as Timestamp;
                        final dateTime = timestamp.toDate();
                        timeAgo = timeago.format(dateTime);
                      }

                      return Card(
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
                              // Left Image
                              // Left Image
// Replace the problematic image section with this:
                              Container(
                                child: data['image_base64'] != null
                                    ? Padding(
                                        padding: const EdgeInsets.all(6.0),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(12),
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

                              // Content Section
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data['title'] ?? 'Untitled',
                                        style: texts.copyWith(
                                            color: Color(
                                              0xFF001d35,
                                            ),
                                            fontSize: 16),
                                        // style: const TextStyle(
                                        //   fontSize: 16,
                                        //   fontWeight: FontWeight.bold,
                                        //   color: Colors.black87,
                                        // ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        data['description'] ?? '',
                                        style: texts.copyWith(
                                            color: Color(0xFF545454),
                                            fontSize: 13),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      if (data['highlighted_text'] != null)
                                        Text(
                                          data['highlighted_text'],
                                          style: texts.copyWith(
                                              color: Color(0xFF545454),
                                              fontSize: 12),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      const Spacer(),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceAround,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'BY: ${data['user_name'] ?? 'Anonymous'}',
                                              style: texts.copyWith(
                                                  fontSize: 12,
                                                  color: Color(0xFFff9500)),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          SizedBox(
                                            width: 8,
                                          ),
                                          Text(
                                            timeAgo,
                                            style: texts.copyWith(
                                              color: Color(0xFF23a93b)
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
                              // Right Social Media Icons Column
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                    // border: Border(
                                    //   left: BorderSide(
                                    //     color: Colors.grey[200]!,
                                    //     width: 1,
                                    //   ),
                                    // ),
                                    ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: (data['platforms']
                                              as List<dynamic>? ??
                                          [])
                                      .map<Widget>(
                                        (platform) => Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 4),
                                          child: _getPlatformIcon(
                                              platform), // Use directly
                                        ),
                                      )
                                      .toList(),
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
          ],
        ),
      ),
    );
  }

  Widget _getPlatformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'facebook':
        return Icon(LucideIcons.facebook, size: 20); // Use Lucide icon
      case 'instagram':
        return Icon(LucideIcons.instagram, size: 20); // Use Lucide icon
      case 'whatsapp':
        return Image.asset(
          "assets/icons/whatsapp.png",
          height: 20,
          width: 20,
        ); // Use custom WhatsApp image icon
      default:
        return Icon(LucideIcons.link, size: 20); // Use default icon
    }
  }
}
