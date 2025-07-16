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

  // Helper method to determine screen type
  bool _isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width > 1200;
  }

  bool _isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width > 600 && width <= 1200;
  }

  bool _isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width <= 600;
  }

  // Get responsive padding
  EdgeInsets _getResponsivePadding(BuildContext context) {
    if (_isLargeScreen(context)) {
      return const EdgeInsets.symmetric(horizontal: 80, vertical: 32);
    } else if (_isTablet(context)) {
      return const EdgeInsets.symmetric(horizontal: 32, vertical: 24);
    } else {
      return const EdgeInsets.all(16);
    }
  }

  // Get responsive card width
  double _getCardWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (_isLargeScreen(context)) {
      return min(800, screenWidth * 0.6);
    } else if (_isTablet(context)) {
      return min(600, screenWidth * 0.8);
    } else {
      return screenWidth - 32;
    }
  }

  // Get responsive image aspect ratio
  double _getImageAspectRatio(BuildContext context) {
    if (_isLargeScreen(context)) {
      return 21 / 9; // Wider aspect ratio for large screens
    } else if (_isTablet(context)) {
      return 16 / 9;
    } else {
      return 16 / 9;
    }
  }

  // Get responsive image height
  double _getImageHeight(BuildContext context) {
    if (_isLargeScreen(context)) {
      return 200;
    } else if (_isTablet(context)) {
      return 180;
    } else {
      return 160;
    }
  }

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
            constraints: BoxConstraints(
              maxHeight: 200,
              maxWidth: _isLargeScreen(context) ? 500 : 400,
            ),
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
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
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
                        height: _isLargeScreen(context) ? 150 : 120,
                        width: _isLargeScreen(context) ? 150 : 120,
                        decoration: BoxDecoration(
                          color: Color(0xFFE0E8FF).withOpacity(0.7),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          SolarIconsOutline.documentsMinimalistic,
                          size: _isLargeScreen(context) ? 80 : 64,
                          color: Color(0xFF5664F5),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'No Pending Approvals',
                        style: TextStyle(
                          fontSize: _isLargeScreen(context) ? 24 : 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You\'re all caught up!',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: _isLargeScreen(context) ? 16 : 14,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final posts = snapshot.data!.docs;

              return AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Center(
                    child: Container(
                      width: _getCardWidth(context),
                      child: ListView.builder(
                        padding: _getResponsivePadding(context),
                        itemCount: posts.length,
                        itemBuilder: (context, index) {
                          final post = posts[index].data() as Map<String, dynamic>;
                          final postId = posts[index].id;

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
                              child: Padding(
                                padding: EdgeInsets.only(
                                  bottom: _isLargeScreen(context) ? 32 : 20,
                                ),
                                child: _buildApprovalCard(
                                  context,
                                  post,
                                  postId,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and timestamp
          Container(
            padding: EdgeInsets.all(_isLargeScreen(context) ? 20 : 16),
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
                        style: TextStyle(
                          fontSize: _isLargeScreen(context) ? 20 : 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: _isLargeScreen(context) ? 16 : 12,
                    vertical: _isLargeScreen(context) ? 8 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.amber.shade700),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.pending,
                        size: _isLargeScreen(context) ? 16 : 14,
                        color: Colors.amber.shade900,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Pending',
                        style: TextStyle(
                          fontSize: _isLargeScreen(context) ? 14 : 12,
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
              padding: EdgeInsets.fromLTRB(
                _isLargeScreen(context) ? 20 : 16,
                _isLargeScreen(context) ? 12 : 8,
                _isLargeScreen(context) ? 20 : 16,
                0,
              ),
              child: Text(
                postDescription,
                style: TextStyle(
                  color: Colors.grey[800],
                  fontSize: _isLargeScreen(context) ? 16 : 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          // Flyer images section
          Padding(
            padding: EdgeInsets.all(_isLargeScreen(context) ? 20 : 16),
            child: _isLargeScreen(context) || _isTablet(context)
                ? Row(
                    children: [
                      if (originalFlyer != null)
                        Expanded(
                          child: _buildFlyerThumbnail(
                            context,
                            originalFlyer,
                            'original-flyer-$postId',
                            'Original Flyer',
                            Colors.blue.shade100,
                            Colors.blue,
                          ),
                        ),
                      if (updatedFlyer != null && originalFlyer != null)
                        SizedBox(width: _isLargeScreen(context) ? 24 : 16),
                      if (updatedFlyer != null)
                        Expanded(
                          child: _buildFlyerThumbnail(
                            context,
                            updatedFlyer,
                            'updated-flyer-$postId',
                            'Updated Flyer',
                            Colors.green.shade100,
                            Colors.green,
                          ),
                        ),
                    ],
                  )
                : Column(
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
            padding: EdgeInsets.all(_isLargeScreen(context) ? 20 : 16),
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
                  icon: Icon(
                    Icons.check_circle_outline,
                    size: _isLargeScreen(context) ? 20 : 18,
                  ),
                  label: Text(
                    'Approve',
                    style: TextStyle(
                      fontSize: _isLargeScreen(context) ? 16 : 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: _isLargeScreen(context) ? 24 : 20,
                      vertical: _isLargeScreen(context) ? 12 : 10,
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                ),
                SizedBox(width: _isLargeScreen(context) ? 16 : 12),
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
                  icon: Icon(
                    Icons.feedback_outlined,
                    size: _isLargeScreen(context) ? 20 : 18,
                  ),
                  label: Text(
                    'Request Changes',
                    style: TextStyle(
                      fontSize: _isLargeScreen(context) ? 16 : 14,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade600,
                    side: BorderSide(color: Colors.red.shade300),
                    padding: EdgeInsets.symmetric(
                      horizontal: _isLargeScreen(context) ? 24 : 20,
                      vertical: _isLargeScreen(context) ? 12 : 10,
                    ),
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
    final imageHeight = _getImageHeight(context);
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: _isLargeScreen(context) ? 16 : 12,
              vertical: _isLargeScreen(context) ? 10 : 8,
            ),
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
                    fontSize: _isLargeScreen(context) ? 14 : 12,
                  ),
                ),
                Icon(
                  Icons.photo,
                  size: _isLargeScreen(context) ? 18 : 16,
                  color: textColor,
                ),
              ],
            ),
          ),
          Stack(
            children: [
              Container(
                height: imageHeight,
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
                  padding: EdgeInsets.all(_isLargeScreen(context) ? 8 : 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.fullscreen,
                    color: Colors.white,
                    size: _isLargeScreen(context) ? 18 : 16,
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