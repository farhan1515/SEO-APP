import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import '../widgets/image_viewer.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:solar_icons/solar_icons.dart';
import '../services/notification_service.dart';

class PendingApprovalsScreen extends StatefulWidget {
  const PendingApprovalsScreen({Key? key}) : super(key: key);

  @override
  State<PendingApprovalsScreen> createState() => _PendingApprovalsScreenState();
}

class _PendingApprovalsScreenState extends State<PendingApprovalsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    // This will trigger a rebuild of the StreamBuilder
    await Future.delayed(const Duration(seconds: 1));
    setState(() {});
  }

  // Replace the existing _handleApproval method with this simplified version
  Future<void> _handleApproval(
      BuildContext context,
      String postId,
      bool isApproved,
      String originalPosterId,
      String designerId,
      String postTitle,
      String updatedFlyerBase64) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final feedbackController = TextEditingController();
    String? feedback;

    if (!isApproved) {
      feedback = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Provide Feedback',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Container(
            constraints: const BoxConstraints(maxHeight: 200),
            child: TextField(
              controller: feedbackController,
              decoration: InputDecoration(
                hintText: 'What needs to be changed?',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: Theme.of(context).primaryColor, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              maxLines: 5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[700])),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, feedbackController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Submit Feedback',
                  style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      );
      if (feedback == null || feedback.isEmpty) return;
    }

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 10),
            Text(isApproved ? 'Approving...' : 'Sending feedback...'),
          ],
        ),
        backgroundColor:
            isApproved ? Colors.green.shade700 : Colors.blue.shade700,
        duration: const Duration(seconds: 30),
      ),
    );

    try {
      final batch = FirebaseFirestore.instance.batch();

      // Update the post with flyer_base64 instead of image_base64
      final postRef =
          FirebaseFirestore.instance.collection('post_requests').doc(postId);
      if (isApproved) {
        batch.update(postRef, {
          'flyer_base64': updatedFlyerBase64,
          'updated_flyer_base64': null,
          'flyer_approval_status': 'approved',
        });
      } else {
        batch.update(postRef, {
          'updated_flyer_base64': null,
          'flyer_approval_status': 'declined',
          'feedback': feedback,
        });
      }

      // Notify the Designer via chat
      final chatId = _generateChatId(currentUser.uid, designerId);
      final messageRef = FirebaseFirestore.instance
          .collection('conversations')
          .doc(chatId)
          .collection('messages')
          .doc();

      batch.set(messageRef, {
        'senderId': currentUser.uid,
        'receiverId': designerId,
        'textMessage': isApproved
            ? 'I approved the flyer for the post: "$postTitle"'
            : 'I declined the flyer for the post: "$postTitle". Feedback: $feedback',
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'sent',
        'approved': isApproved ? 'accepted' : 'declined',
        'feedback': feedback,
      });

      // Update conversation metadata
      batch.update(
          FirebaseFirestore.instance.collection('conversations').doc(chatId), {
        'lastMessage': isApproved ? 'Approved flyer' : 'Declined flyer',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update sender's chat metadata
      batch.set(
        FirebaseFirestore.instance
            .collection('user_conversations')
            .doc(currentUser.uid)
            .collection('chats')
            .doc(chatId),
        {
          'partnerId': designerId,
          'partnerName': 'Designer',
          'lastMessage': isApproved ? 'Approved flyer' : 'Declined flyer',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'unreadCount': 0,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // Update recipient's chat metadata
      batch.set(
        FirebaseFirestore.instance
            .collection('user_conversations')
            .doc(designerId)
            .collection('chats')
            .doc(chatId),
        {
          'partnerId': currentUser.uid,
          'partnerName': currentUser.displayName ?? 'Unknown',
          'lastMessage': isApproved ? 'Approved flyer' : 'Declined flyer',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'unreadCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      // Send notification for the approval/decline
      await NotificationService.sendNotification(
        recipientId: designerId,
        title: isApproved ? '✅ Flyer Approved' : '❌ Flyer Feedback',
        body: isApproved
            ? '${currentUser.displayName ?? "Someone"} approved your flyer for "$postTitle"'
            : '${currentUser.displayName ?? "Someone"} provided feedback for "$postTitle"',
        type: isApproved ? 'flyer_approval' : 'flyer_feedback',
        chatId: chatId,
        senderId: currentUser.uid,
        senderName: currentUser.displayName ?? "Unknown",
        postId: postId,
        postTitle: postTitle,
      );

      scaffoldMessenger.hideCurrentSnackBar();

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isApproved ? Icons.check_circle : Icons.info,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Text(isApproved ? 'Flyer approved!' : 'Feedback sent'),
            ],
          ),
          backgroundColor:
              isApproved ? Colors.green.shade700 : Colors.blue.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(10),
        ),
      );
    } catch (e) {
      scaffoldMessenger.hideCurrentSnackBar();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text('Error: $e')),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  String _generateChatId(String user1, String user2) {
    final ids = [user1, user2]..sort();
    return '${ids[0]}-${ids[1]}';
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 70, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Please log in',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You need to be logged in to view approvals',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.login),
                label: const Text('Go to Login'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: () {
                  // Navigate to login screen
                  Navigator.of(context).pushReplacementNamed('/login');
                },
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pending Approvals',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _refreshIndicatorKey.currentState?.show(),
          ),
        ],
      ),
      body: RefreshIndicator(
        key: _refreshIndicatorKey,
        onRefresh: _refreshData,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).primaryColor.withOpacity(0.05),
                Colors.white,
              ],
            ),
          ),
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('post_requests')
                .where('user_id', isEqualTo: currentUser.uid)
                .where('flyer_approval_status', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: SpinKitPulse(
                    color: Theme.of(context).primaryColor,
                    size: 50.0,
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 120,
                        width: 120,
                        decoration: BoxDecoration(
                          color: Color(0xFFE0E8FF).withOpacity(0.7),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          SolarIconsOutline
                              .documentsMinimalistic, // or SolarIconsOutline.clipboardCheck
                          size: 64,
                          color: Color(0xFF5664F5),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'No Pending Approvals',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You\'re all caught up!',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              final posts = snapshot.data!.docs;

              return AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: posts.length,
                    itemBuilder: (context, index) {
                      final post = posts[index].data() as Map<String, dynamic>;
                      final postId = posts[index].id;
                      final originalImage = post['image_base64'];
                      final updatedImage = post['updated_image_base64'];

                      // Create a staggered animation effect
                      final itemAnimation =
                          Tween<double>(begin: 0.0, end: 1.0).animate(
                        CurvedAnimation(
                          parent: _animationController,
                          curve: Interval(
                            (index / posts.length) * 0.5,
                            min(1.0, ((index + 1) / posts.length) * 0.5 + 0.5),
                            curve: Curves.easeOut,
                          ),
                        ),
                      );

                      return FadeTransition(
                        opacity: itemAnimation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.2),
                            end: Offset.zero,
                          ).animate(itemAnimation),
                          child: _buildApprovalCard(
                            context,
                            post,
                            postId,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: () {
      //     // Navigate to view all posts or dashboard
      //     Navigator.of(context).pushNamed('/dashboard');
      //   },
      //   backgroundColor: Theme.of(context).primaryColor,
      //   child: const Icon(Icons.dashboard),
      // ),
    );
  }

  Widget _buildApprovalCard(
    BuildContext context,
    Map<String, dynamic> post,
    String postId,
  ) {
    final String postTitle = post['title'] ?? 'Untitled';
    final String postDescription =
        post['description'] ?? 'No description provided';
    final Timestamp? timestamp = post['timestamp'] as Timestamp?;
    final String formattedDate = timestamp != null
        ? '${timestamp.toDate().day}/${timestamp.toDate().month}/${timestamp.toDate().year}'
        : 'Unknown date';

    // Get the original and updated flyer images
    final originalFlyer = post['flyer_base64'];
    final updatedFlyer = post['updated_flyer_base64'];

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and timestamp
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        postTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Text(
                      //   'Created on $formattedDate',
                      //   style: TextStyle(
                      //     fontSize: 12,
                      //     color: Colors.grey[600],
                      //   ),
                      // ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.amber.shade700),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.pending,
                          size: 14, color: Colors.amber.shade900),
                      const SizedBox(width: 4),
                      Text(
                        'Pending',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Description (if available)
          if (postDescription.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                postDescription,
                style: TextStyle(color: Colors.grey[800], fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          // Flyer images section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (originalFlyer != null)
                  _buildFlyerThumbnail(
                    context,
                    originalFlyer,
                    'original-flyer-$postId',
                    'Original Flyer',
                    Colors.blue.shade100,
                    Colors.blue,
                  ),
                if (updatedFlyer != null) ...[
                  const SizedBox(height: 16),
                  _buildFlyerThumbnail(
                    context,
                    updatedFlyer,
                    'updated-flyer-$postId',
                    'Updated Flyer',
                    Colors.green.shade100,
                    Colors.green,
                  ),
                ],
              ],
            ),
          ),

          // Action buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _handleApproval(
                    context,
                    postId,
                    true,
                    post['user_id'],
                    post['last_updated_by'] ?? '',
                    post['title'] ?? 'Untitled',
                    updatedFlyer ?? '',
                  ),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => _handleApproval(
                    context,
                    postId,
                    false,
                    post['user_id'],
                    post['last_updated_by'] ?? '',
                    post['title'] ?? 'Untitled',
                    updatedFlyer ?? '',
                  ),
                  icon: const Icon(Icons.feedback_outlined),
                  label: const Text('Request Changes'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade600,
                    side: BorderSide(color: Colors.red.shade300),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlyerThumbnail(
    BuildContext context,
    String flyerBase64,
    String heroTag,
    String label,
    Color bgColor,
    Color textColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    fontSize: 12,
                  ),
                ),
                Icon(Icons.photo, size: 16, color: textColor),
              ],
            ),
          ),
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Hero(
                    tag: heroTag,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                      child: Image.memory(
                        base64Decode(flyerBase64),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ImageViewer(
                            imageBase64: flyerBase64,
                            tag: heroTag,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.fullscreen,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
