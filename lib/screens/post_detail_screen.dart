import 'package:flutter/material.dart';
import 'package:seo_app/screens/home_screen.dart';
import 'package:seo_app/screens/post_request_screen.dart';
import 'package:seo_app/screens/post_screen.dart';
import 'package:seo_app/theme/text_style.dart';
import 'package:seo_app/screens/chat_screen.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'dart:convert';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:universal_html/html.dart' as html;
import 'dart:typed_data';

class PostDetailScreen extends StatelessWidget {
  final Map<String, dynamic> post;

  const PostDetailScreen({
    Key? key,
    required this.post,
  }) : super(key: key);

  void _handleChatNavigation(BuildContext context) {
    // Get the correct recipient ID and name from the post data
    final recipientId = post['user_id']?.toString() ?? '';
    final recipientName = post['user_name']?.toString() ?? '';

    print('🔔 [DEBUG] Initiating chat with:');
    print('🔔 [DEBUG] Recipient ID from post: $recipientId');
    print('🔔 [DEBUG] Recipient Name from post: $recipientName');

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please login to chat with the designer'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (currentUser.uid == recipientId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot chat with yourself'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (recipientId.isEmpty || recipientName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to initiate chat. User details are missing.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // First verify the recipient exists in users collection
    FirebaseFirestore.instance
        .collection('users')
        .doc(recipientId)
        .get()
        .then((userDoc) async {
      if (!userDoc.exists) {
        print('❌ [DEBUG] Recipient user document not found: $recipientId');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to find the recipient user.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Ensure chat document exists before navigating
      final chatId = _generateChatId(currentUser.uid, recipientId);
      print('🔔 [DEBUG] Generated chat ID: $chatId');

      try {
        final chatDoc = await FirebaseFirestore.instance
            .collection('conversations')
            .doc(chatId)
            .get();

        if (!chatDoc.exists) {
          print('🔔 [DEBUG] Creating new chat document');
          // Create new chat document
          final batch = FirebaseFirestore.instance.batch();

          // Create conversation document
          batch.set(
              FirebaseFirestore.instance
                  .collection('conversations')
                  .doc(chatId),
              {
                'participants': [currentUser.uid, recipientId],
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
                'lastMessage': null,
                'lastMessageTime': null,
                'lastActive': {
                  currentUser.uid: FieldValue.serverTimestamp(),
                  recipientId: FieldValue.serverTimestamp(),
                },
              });

          // Create chat metadata for both users
          batch.set(
            FirebaseFirestore.instance
                .collection('user_conversations')
                .doc(currentUser.uid)
                .collection('chats')
                .doc(chatId),
            {
              'partnerId': recipientId,
              'partnerName': recipientName,
              'lastMessage': null,
              'lastMessageTime': null,
              'unreadCount': 0,
              'updatedAt': FieldValue.serverTimestamp(),
              'lastActive': FieldValue.serverTimestamp(),
            },
          );

          batch.set(
            FirebaseFirestore.instance
                .collection('user_conversations')
                .doc(recipientId)
                .collection('chats')
                .doc(chatId),
            {
              'partnerId': currentUser.uid,
              'partnerName': currentUser.displayName ?? 'Unknown',
              'lastMessage': null,
              'lastMessageTime': null,
              'unreadCount': 0,
              'updatedAt': FieldValue.serverTimestamp(),
              'lastActive': FieldValue.serverTimestamp(),
            },
          );

          await batch.commit();
          print('✅ [DEBUG] Chat document created successfully');
        }

        // Update last active timestamp for current user
        await FirebaseFirestore.instance
            .collection('conversations')
            .doc(chatId)
            .update({
          'lastActive.${currentUser.uid}': FieldValue.serverTimestamp(),
        });

        // Navigate to chat screen
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                recipientId: recipientId,
                recipientName: recipientName,
                postContext: {
                  'id': post['id'],
                  'title': post['title'],
                  'image_base64': post['image_base64'],
                },
              ),
            ),
          );
        }
      } catch (error) {
        print('❌ [DEBUG] Error initiating chat: $error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initiating chat: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }).catchError((error) {
      print('❌ [DEBUG] Error checking recipient user: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error checking recipient user: $error'),
          backgroundColor: Colors.red,
        ),
      );
    });
  }

  String _generateChatId(String user1, String user2) {
    final ids = [user1, user2]..sort();
    return '${ids[0]}-${ids[1]}';
  }

  void _navigateToEditScreen(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => PostScreen(
          existingData: {
            'title': post['title'],
            'description': post['description'],
            'highlighted_text': post['highlight_text'],
            'image_base64': post['image_base64'],
            'reference_link': post['reference_link'], // Add reference link
            'flyer_base64': post['flyer_base64'], // Add flyer image
            'user_id': post['user_id'],
            'user_name': post['user_name'],
            'created_at': post['created_at'],
            'platforms': post['platforms'],
            'scheduled_date': post['scheduled_date'],
            'scheduled_time': post['scheduled_time'],
            'scheduled_timezone': post['scheduled_timezone'],
            'recurring_schedule': post['recurring_schedule'],
            'id': post['id'],
            'profile_id': post['profile_id'],
            'profile_name': post['profile_name'],
            'image_approval_status': post['image_approval_status'],
            'flyer_approval_status': post['flyer_approval_status'],
          },
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Confirm Delete',
            style: lexand.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.red[700],
            ),
          ),
          content: Text(
            'Are you sure you want to delete this post?',
            style: lexand.copyWith(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: lexand.copyWith(color: Colors.grey[700]),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context); // Close the dialog
                await _deletePost(context); // Delete the post

                // Navigate to HomeScreen after deletion
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HomeScreen(),
                  ),
                );

                // Show success snackbar
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Post deleted successfully!',
                      style: TextStyle(color: Colors.white),
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[400],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Delete',
                style: lexand.copyWith(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deletePost(BuildContext context) async {
    try {
      await FirebaseFirestore.instance
          .collection('post_requests')
          .doc(post['id'])
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 10),
              Text(
                'Post deleted successfully',
                style: lexand.copyWith(color: Colors.white),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error deleting post: ${e.toString()}',
            style: lexand.copyWith(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  void _showImagePopup(BuildContext context, String imageBase64) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: MediaQuery.of(context).size.width * 0.8,
                height: MediaQuery.of(context).size.height * 0.8,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      spreadRadius: 5,
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.memory(
                      base64Decode(imageBase64),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: CircleAvatar(
                  backgroundColor: Colors.black.withOpacity(0.5),
                  radius: 20,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatRecurringSchedule(Map<String, dynamic>? recurringSchedule) {
    if (recurringSchedule == null) return 'No recurring schedule';

    final frequency = recurringSchedule['frequency'] ?? 'No frequency';
    final weekdays = recurringSchedule['weekdays'] ?? [];

    String endDateStr = 'No end date';
    if (recurringSchedule['endDate'] != null) {
      try {
        final endDateTimestamp = recurringSchedule['endDate'].toString();
        if (endDateTimestamp.contains('T')) {
          final dateOnly = endDateTimestamp.split('T')[0];
          endDateStr = dateOnly;
        } else {
          endDateStr = recurringSchedule['endDate'].toString();
        }
      } catch (e) {
        endDateStr = recurringSchedule['endDate'].toString();
      }
    }

    List<String> weekdayNames = [];
    try {
      if (weekdays is List) {
        for (var entry in weekdays) {
          if (entry is Map && entry.containsKey('value')) {
            String value = entry['value']?.toString() ?? '';
            weekdayNames.add(value);
          } else {
            weekdayNames.add(entry.toString());
          }
        }
      }
    } catch (e) {
      print('Error formatting weekdays: $e');
    }

    return 'Frequency: $frequency\nWeekdays: ${weekdayNames.join(', ')}\nEnd Date: $endDateStr';
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Not specified';

    try {
      if (dateStr.contains('T')) {
        final dateOnly = dateStr.split('T')[0];
        return dateOnly;
      }
      return dateStr;
    } catch (e) {
      return dateStr;
    }
  }

  Future<String?> _getUserRole() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return null;

    try {
      final roleDoc = await FirebaseFirestore.instance
          .collection('roles')
          .doc(currentUser.uid)
          .get();

      if (roleDoc.exists) {
        return roleDoc.data()?['role'] as String?;
      }
      return null;
    } catch (e) {
      print('Error fetching user role: $e');
      return null;
    }
  }

  Future<bool> _isAuthorizedEditor() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return false;

    try {
      final roleDoc = await FirebaseFirestore.instance
          .collection('roles')
          .doc(currentUser.uid)
          .get();

      if (roleDoc.exists) {
        final role = roleDoc.data()?['role'] as String?;
        return role == 'Graphic Designer' || role == 'SEO.Credit Manager';
      }
      return false;
    } catch (e) {
      print('Error checking user role: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Debug printing to inspect post data
    print('Post data: ${post.toString()}');

    String scheduledDate = _formatDate(post['scheduled_date']?.toString());
    String scheduledTime =
        post['scheduled_time']?.toString() ?? 'Not specified';
    String timezone = post['scheduled_timezone']?.toString() ?? 'Not specified';

    Map<String, dynamic>? recurringSchedule;
    if (post['recurring_schedule'] != null) {
      recurringSchedule = post['recurring_schedule'] is Map
          ? Map<String, dynamic>.from(post['recurring_schedule'])
          : null;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFEFF6FB), // Lighter blue for a cute look
      body: SafeArea(
        child: Stack(
          children: [
            // Background design elements
            Positioned(
              top: -50,
              right: -30,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: const Color(0xFFB2DFFF).withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -60,
              left: -40,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD6E5).withOpacity(0.4),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            // Main content
            FutureBuilder(
                future: _isAuthorizedEditor(),
                builder: (context, snapshot) {
                  final isAuthorized = snapshot.data ?? false;
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with back button
                        Container(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.arrow_back_ios_rounded,
                                      size: 20),
                                  color: const Color(0xFF4B6BFB),
                                ),
                              ),
                              Text(
                                'Post Details',
                                style: lexand.copyWith(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF4B6BFB),
                                ),
                              ),
                              if (isAuthorized)
                                Row(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.1),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: IconButton(
                                        icon: Icon(Icons.edit,
                                            color: Colors.blue[400]),
                                        onPressed: () =>
                                            _navigateToEditScreen(context),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.1),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: IconButton(
                                        icon: Icon(Icons.delete,
                                            color: Colors.red[400]),
                                        onPressed: () =>
                                            _confirmDelete(context),
                                      ),
                                    ),
                                  ],
                                )
                              else
                                const SizedBox(width: 48),
                            ],
                          ),
                        ),

                        // Main Content Card
                        Container(
                          margin: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.07),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: 20,
                              ),
                              // FLYER IMAGE SECTION - VISIBLE TO ALL
                              if (post['flyer_base64'] != null &&
                                  post['flyer_base64'].toString().isNotEmpty)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _SectionTitle('Flyer Design'),
                                    const SizedBox(height: 12),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 24),
                                      child: GestureDetector(
                                        onTap: () => _showImagePopup(
                                            context, post['flyer_base64']),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.1),
                                                blurRadius: 10,
                                                offset: const Offset(0, 5),
                                              )
                                            ],
                                          ),
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            child: Stack(
                                              children: [
                                                Image.memory(
                                                  base64Decode(
                                                      post['flyer_base64']),
                                                  width: double.infinity,
                                                  height: 240,
                                                  fit: BoxFit.cover,
                                                ),
                                                Positioned(
                                                  right: 12,
                                                  bottom: 12,
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black
                                                          .withOpacity(0.6),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                    ),
                                                    child: const Icon(
                                                      Icons.fullscreen,
                                                      color: Colors.white,
                                                      size: 20,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 28),
                                  ],
                                ),

                              Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Title with gradient
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        gradient: LinearGradient(
                                          colors: [
                                            const Color(0xFFE9F1FF),
                                            const Color(0xFFE9F1FF)
                                                .withOpacity(0.3),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      child: Text(
                                        post['title'] ?? 'Untitled',
                                        style: lexand.copyWith(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF2D3748),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(height: 20),

                                    // Posted by and timestamp with avatar
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[50],
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.grey.withOpacity(0.2),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor:
                                                const Color(0xFF4B6BFB)
                                                    .withOpacity(0.2),
                                            radius: 20,
                                            child: Text(
                                              (post['user_name'] ?? 'A')[0]
                                                  .toUpperCase(),
                                              style: lexand.copyWith(
                                                color: const Color(0xFF4B6BFB),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Posted by ${post['posted_by'] ?? post['user_name'] ?? 'Anonymous'}',
                                                  style: lexand.copyWith(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.black87,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  timeago.format(
                                                    DateTime.tryParse(post[
                                                                'created_at'] ??
                                                            '') ??
                                                        DateTime.now(),
                                                  ),
                                                  style: lexand.copyWith(
                                                    fontSize: 13,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 28),
                                    // Profile Information Section
                                    _SectionTitle('Business Profile'),
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF5F0FF),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: const Color(0xFFD9CCFF),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.business,
                                            color: Colors.deepPurple[400],
                                            size: 24,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              post['profile_name'] ??
                                                  'No profile selected',
                                              style: lexand.copyWith(
                                                fontSize: 16,
                                                color: Colors.deepPurple[800],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 28),
                                    // Description Section
                                    _SectionTitle('Description'),
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[50],
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.grey.withOpacity(0.2),
                                        ),
                                      ),
                                      child: Text(
                                        post['description'] ??
                                            'No description available',
                                        style: lexand.copyWith(
                                          fontSize: 16,
                                          color: Colors.black87,
                                          height: 1.6,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(height: 28),

                                    // Highlights Section
                                    _SectionTitle('Highlights'),
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF9E6),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: const Color(0xFFFFEAA7),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Text(
                                        post['highlight_text'] ??
                                            'No highlights available',
                                        style: lexand.copyWith(
                                          fontSize: 16,
                                          color: const Color(0xFF6B5600),
                                          height: 1.6,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(height: 28),

                                    // REFERENCE IMAGE SECTION
                                    _SectionTitle('Reference Image'),
                                    const SizedBox(height: 12),
                                    if (post['image_base64'] != null)
                                      GestureDetector(
                                        onTap: () => _showImagePopup(
                                            context, post['image_base64']),
                                        child: Stack(
                                          children: [
                                            Padding(
                                              padding:
                                                  const EdgeInsets.all(8.0),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                child: Image.memory(
                                                  base64Decode(
                                                      post['image_base64']),
                                                  width: double.infinity,
                                                  height: 240,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              right: 12,
                                              bottom: 12,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withOpacity(0.6),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: const Icon(
                                                  Icons.fullscreen,
                                                  color: Colors.white,
                                                  size: 20,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                    // Image approval status
                                    if (post['image_approval_status'] != null)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 24),
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          margin: const EdgeInsets.only(
                                              top: 12, bottom: 28),
                                          decoration: BoxDecoration(
                                            color: post['image_approval_status'] ==
                                                    'pending'
                                                ? Colors.orange.withOpacity(0.1)
                                                : post['image_approval_status'] ==
                                                        'approved'
                                                    ? Colors.green
                                                        .withOpacity(0.1)
                                                    : Colors.red
                                                        .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            post['image_approval_status'] ==
                                                    'pending'
                                                ? 'Image Update Pending Approval'
                                                : post['image_approval_status'] ==
                                                        'approved'
                                                    ? 'Image Update Approved ✅'
                                                    : 'Image Update Declined ❌',
                                            style: lexand.copyWith(
                                              color: post['image_approval_status'] ==
                                                      'pending'
                                                  ? Colors.orange
                                                  : post['image_approval_status'] ==
                                                          'approved'
                                                      ? Colors.green
                                                      : Colors.red,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    SizedBox(
                                      height: 12,
                                    ),
                                    // Inside the main Column of PostDetailScreen's build method, after the image section
                                    if (post['reference_link'] != null &&
                                        post['reference_link'].isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 24),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _SectionTitle('Reference Link'),
                                            const SizedBox(height: 12),
                                            Container(
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF0F7FF),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                border: Border.all(
                                                  color:
                                                      const Color(0xFFB8D8FF),
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: InkWell(
                                                onTap: () {
                                                  if (post['reference_link'] !=
                                                      null) {
                                                    final url = post[
                                                                'reference_link']
                                                            .startsWith('http')
                                                        ? post['reference_link']
                                                        : 'https://${post['reference_link']}';
                                                    if (kIsWeb) {
                                                      html.window
                                                          .open(url, '_blank');
                                                    } else {
                                                      // For mobile, you'd use url_launcher package
                                                      // launchUrl(Uri.parse(url));
                                                    }
                                                  }
                                                },
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.link,
                                                      color: Colors.blue[600],
                                                      size: 24,
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Text(
                                                        post['reference_link'],
                                                        style: lexand.copyWith(
                                                          fontSize: 16,
                                                          color:
                                                              Colors.blue[600],
                                                          decoration:
                                                              TextDecoration
                                                                  .underline,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 28),
                                          ],
                                        ),
                                      ),

                                    // Scheduled Date and Time
                                    _SectionTitle('Scheduled Date & Time'),
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE9F8F5),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: const Color(0xFFB7E1D7),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.calendar_today,
                                                color: Colors.teal[700],
                                                size: 18,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Date: $scheduledDate',
                                                style: lexand.copyWith(
                                                  fontSize: 16,
                                                  color: Colors.teal[700],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.access_time,
                                                color: Colors.teal[700],
                                                size: 18,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'Time: $scheduledTime',
                                                  style: lexand.copyWith(
                                                    fontSize: 16,
                                                    color: Colors.teal[700],
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.public,
                                                color: Colors.teal[700],
                                                size: 18,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'Timezone: $timezone',
                                                  style: lexand.copyWith(
                                                    fontSize: 16,
                                                    color: Colors.teal[700],
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 28),

                                    // Recurring Schedule
                                    _SectionTitle('Recurring Schedule'),
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF0E6FF),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: const Color(0xFFD2BDFF),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Text(
                                        _formatRecurringSchedule(
                                            recurringSchedule),
                                        style: lexand.copyWith(
                                          fontSize: 16,
                                          color: const Color(0xFF5A2CA0),
                                          height: 1.6,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 28),

                                    // Platforms Section
                                    _SectionTitle('Platforms'),
                                    const SizedBox(height: 12),
                                    if (post['platforms'] != null &&
                                        (post['platforms'] as List).isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE7F0FF),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                            color: const Color(0xFFB6D0FF),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Row(
                                          children: (post['platforms']
                                                  as List<dynamic>)
                                              .map<Widget>((platform) =>
                                                  Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                            right: 20),
                                                    child: Column(
                                                      children: [
                                                        Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(12),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors.white,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12),
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color: Colors
                                                                    .black
                                                                    .withOpacity(
                                                                        0.05),
                                                                blurRadius: 8,
                                                                offset:
                                                                    const Offset(
                                                                        0, 3),
                                                              ),
                                                            ],
                                                          ),
                                                          child:
                                                              _getPlatformIcon(
                                                                  platform),
                                                        ),
                                                        const SizedBox(
                                                            height: 8),
                                                        Text(
                                                          platform,
                                                          style:
                                                              lexand.copyWith(
                                                            fontSize: 12,
                                                            color: const Color(
                                                                0xFF3A5998),
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ))
                                              .toList(),
                                        ),
                                      ),
                                    // Space for FAB at bottom
                                    const SizedBox(height: 80),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
          ],
        ),
      ),

      // Chat Button - Using gradient and animation
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4B6BFB).withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          gradient: const LinearGradient(
            colors: [Color(0xFF4B6BFB), Color(0xFF6F87FF)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: FloatingActionButton.extended(
          onPressed: () => _handleChatNavigation(context),
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(
            Icons.chat_bubble_outline_rounded,
            color: Colors.white,
          ),
          label: Row(
            children: [
              Text(
                'Chat with Customer',
                style: lexand.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16),
              ),
              const SizedBox(width: 4),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.greenAccent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
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
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFF4B6BFB),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: lexand.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF4B6BFB),
          ),
        ),
      ],
    );
  }
}

Widget _getPlatformIcon(String platform) {
  switch (platform.toLowerCase()) {
    case 'facebook':
      return Icon(LucideIcons.facebook, size: 24, color: Colors.blue[800]);
    case 'instagram':
      return Icon(LucideIcons.instagram, size: 24, color: Colors.purple);
    case 'whatsapp':
      return Image.asset(
        "assets/icons/whatsapp.png",
        height: 24,
        width: 24,
      );
    default:
      return Icon(LucideIcons.link, size: 24, color: Colors.black);
  }
}
