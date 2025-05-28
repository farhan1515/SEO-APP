import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:seo_app/services/user_status.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:seo_app/services/notification_service.dart';

import '../widgets/image_viewer.dart';
import 'history_screen.dart';

class ChatScreen extends StatefulWidget {
  final String recipientId;
  final String recipientName;
  final Map<String, dynamic>? postContext;

  const ChatScreen({
    Key? key,
    required this.recipientId,
    required this.recipientName,
    this.postContext,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _currentUser = FirebaseAuth.instance.currentUser;
  final _firestore = FirebaseFirestore.instance;

  String? _projectBase64;
  File? _selectedImage;
  bool _isUploading = false;

  // Cache chat ID to avoid regenerating it
  late final String _chatId;
  Stream<DocumentSnapshot>? _userStatusStream;
  Timer? _statusUpdateTimer;
  @override
  void initState() {
    super.initState();
    _chatId = _generateChatId(_currentUser!.uid, widget.recipientId);
    _setupScrollListener();
    _statusUpdateTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      UserStatusService.updateUserStatus();
    });
    // Update immediately when opening chat
    UserStatusService.updateUserStatus();
    _userStatusStream = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.recipientId)
        .snapshots();
  }

  // Function to format last active time
  String _getLastActiveStatus(Timestamp? lastActive) {
    if (lastActive == null) return 'Offline';

    final now = DateTime.now();
    final lastActiveTime = lastActive.toDate();
    final difference = now.difference(lastActiveTime);

    if (difference.inMinutes < 1) {
      return 'Active now';
    } else if (difference.inMinutes < 60) {
      return 'Active ${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return 'Active ${difference.inHours}h ago';
    } else {
      return 'Active ${difference.inDays}d ago';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _statusUpdateTimer?.cancel();
    super.dispose();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        // Load more messages if needed
      }
    });
  }

  Future<void> _uploadProject() async {
    if (_isUploading) return;

    setState(() => _isUploading = true);

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        if (mounted) {
          setState(() {
            _projectBase64 = base64Encode(bytes);
            if (kIsWeb) {
              // For web, store the image as Uint8List
              _selectedImage = null; // No File object on web
            } else {
              // For mobile, store the image as File
              _selectedImage = File(pickedFile.path);
            }
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _clearImage() {
    setState(() {
      _selectedImage = null;
      _projectBase64 = null;
    });
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty && _projectBase64 == null) return;

    final message = _controller.text.trim();
    final timestamp = FieldValue.serverTimestamp();

    final localProjectBase64 = _projectBase64;
    _controller.clear();
    _clearImage();

    try {
      print('Sending message:');
      print('User: [32m[1m[4m${FirebaseAuth.instance.currentUser?.uid}[0m');
      print('Chat ID: $_chatId');
      print('Message: $message');
      print('Image: ${localProjectBase64 != null}');

      final batch = _firestore.batch();
      final messageRef = _firestore
          .collection('conversations')
          .doc(_chatId)
          .collection('messages')
          .doc();

      batch.set(messageRef, {
        'senderId': _currentUser!.uid,
        'receiverId': widget.recipientId,
        'textMessage': message.isNotEmpty ? message : "",
        'final_project': localProjectBase64,
        'timestamp': timestamp,
        'status': 'sent',
      });

      final lastMessageText = message.isNotEmpty ? message : "Project Sent";

      // Update conversation metadata
      batch.update(_firestore.collection('conversations').doc(_chatId), {
        'lastMessage': lastMessageText,
        'lastMessageTime': timestamp,
        'updatedAt': timestamp,
        'lastActive': {
          _currentUser!.uid: FieldValue.serverTimestamp(),
        },
      });

      // Update sender's chat metadata
      batch.set(
        _firestore
            .collection('user_conversations')
            .doc(_currentUser!.uid)
            .collection('chats')
            .doc(_chatId),
        {
          'partnerId': widget.recipientId,
          'partnerName': widget.recipientName,
          'lastMessage': lastMessageText,
          'lastMessageTime': timestamp,
          'updatedAt': timestamp,
          'unreadCount': 0,
          'lastActive': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // Update recipient's chat metadata
      batch.set(
        _firestore
            .collection('user_conversations')
            .doc(widget.recipientId)
            .collection('chats')
            .doc(_chatId),
        {
          'partnerId': _currentUser!.uid,
          'partnerName': _currentUser!.displayName ?? "Unknown",
          'lastMessage': lastMessageText,
          'lastMessageTime': timestamp,
          'updatedAt': timestamp,
          'unreadCount': FieldValue.increment(1),
          'lastActive': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();
      print('Message sent successfully');
      // Verify the write
      final doc = await messageRef.get();
      print('Message in Firestore: ${doc.exists ? doc.data() : 'Not found'}');

      // Send notification for normal chat message
      await NotificationService.sendNotification(
        recipientId: widget.recipientId,
        title: _currentUser!.displayName ?? 'New Message',
        body: message.isNotEmpty ? message : 'Sent a flyer',
        type: 'chat',
        chatId: _chatId,
        senderId: _currentUser!.uid,
        senderName: _currentUser!.displayName ?? 'Unknown',
      );
    } catch (e) {
      print('Send error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    }
  }

  Future<void> _handleApproval(
      bool isApproved, String messageId, String senderId) async {
    String responseMessage;
    String? feedback;

    if (!isApproved) {
      final feedbackController = TextEditingController();
      feedback = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 8,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: min(MediaQuery.of(context).size.width * 0.85, 400),
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).primaryColor.withOpacity(0.2),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.feedback_outlined,
                          color: Theme.of(context).primaryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Provide Feedback',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Content
                  Text(
                    'Please let us know what needs to be changed:',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade200,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: feedbackController,
                      decoration: InputDecoration(
                        hintText: 'Your feedback helps improve the flyer...',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Theme.of(context).primaryColor,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      maxLines: 4,
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Actions
                  Wrap(
                    alignment: WrapAlignment.spaceAround,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: Colors.grey[700],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Cancel',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 30,
                      ),
                      ElevatedButton(
                        onPressed: () {
                          if (feedbackController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Please provide feedback before submitting'),
                                backgroundColor: Colors.orange.shade700,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                margin: EdgeInsets.all(10),
                              ),
                            );
                          } else {
                            Navigator.pop(context, feedbackController.text);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.send_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Submit ',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      if (feedback == null || feedback.trim().isEmpty) return;
      responseMessage = 'Declined the flyer. Feedback: $feedback';
    } else {
      _showApprovalAnimation(context);
      responseMessage = 'Approved the flyer! ✅';
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final batch = _firestore.batch();
      final responseRef = _firestore
          .collection('conversations')
          .doc(_chatId)
          .collection('messages')
          .doc();

      batch.set(responseRef, {
        'senderId': _currentUser!.uid,
        'receiverId': senderId,
        'textMessage': responseMessage,
        'timestamp': FieldValue.serverTimestamp(),
      });

      batch.update(
        _firestore
            .collection('conversations')
            .doc(_chatId)
            .collection('messages')
            .doc(messageId),
        {'approved': isApproved ? 'accepted' : 'declined'},
      );

      // Update the post if this message is related to a flyer update
      final messageDoc = await _firestore
          .collection('conversations')
          .doc(_chatId)
          .collection('messages')
          .doc(messageId)
          .get();
      final messageData = messageDoc.data();
      if (messageData != null &&
          messageData['textMessage']
              .contains('I updated the flyer for your post')) {
        final postTitleMatch =
            RegExp(r'"([^"]*)"').firstMatch(messageData['textMessage']);
        if (postTitleMatch != null) {
          final postTitle = postTitleMatch.group(1);
          final postQuery = await _firestore
              .collection('post_requests')
              .where('title', isEqualTo: postTitle)
              .where('user_id', isEqualTo: _currentUser!.uid)
              .limit(1)
              .get();

          if (postQuery.docs.isNotEmpty) {
            final postId = postQuery.docs.first.id;
            if (isApproved) {
              batch.update(
                _firestore.collection('post_requests').doc(postId),
                {
                  'flyer_base64': messageData['final_project'],
                  'updated_flyer_base64': null,
                  'flyer_approval_status': 'approved',
                },
              );
            } else {
              batch.update(
                _firestore.collection('post_requests').doc(postId),
                {
                  'updated_flyer_base64': null,
                  'flyer_approval_status': 'declined',
                  'feedback': feedback,
                },
              );
            }
          }
        }
      }

      await batch.commit();

      // Send notification for flyer approval/decline
      await NotificationService.sendNotification(
        recipientId: senderId,
        title: isApproved ? '✅ Flyer Approved' : '❌ Flyer Feedback',
        body: isApproved
            ? '${_currentUser!.displayName ?? "Someone"} approved your flyer!'
            : '${_currentUser!.displayName ?? "Someone"} provided feedback: $feedback',
        type: isApproved ? 'flyer_approval' : 'flyer_feedback',
        chatId: _chatId,
        senderId: _currentUser!.uid,
        senderName: _currentUser!.displayName ?? 'Unknown',
      );

      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isApproved ? Icons.check_circle : Icons.info_outline,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(isApproved
                      ? 'Flyer successfully approved!'
                      : 'Feedback submitted successfully')),
            ],
          ),
          backgroundColor: isApproved ? Colors.green : Colors.blue,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text('Failed to process approval: $e')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

// Add this animation function to your class
  void _showApprovalAnimation(BuildContext context) {
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: Material(
          color: Colors.black.withOpacity(0.3),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 56,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Flyer Approved!',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlayEntry);

    Future.delayed(const Duration(milliseconds: 2500), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  String _generateChatId(String user1, String user2) {
    final ids = [user1, user2]..sort(); // Sort alphabetically
    return '${ids[0]}-${ids[1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 1,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey[200],
              child: Text(
                widget.recipientName[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.recipientName,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  StreamBuilder<DocumentSnapshot>(
                    stream: _userStatusStream,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Text(
                          'Offline',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        );
                      }

                      final userData =
                          snapshot.data!.data() as Map<String, dynamic>?;
                      final lastActive = userData?['lastActive'] as Timestamp?;

                      return Text(
                        _getLastActiveStatus(lastActive),
                        style: TextStyle(
                          color: lastActive != null &&
                                  DateTime.now()
                                          .difference(lastActive.toDate())
                                          .inMinutes <
                                      1
                              ? Colors.green
                              : Colors.grey,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black87),
            onSelected: (value) {
              if (value == 'history') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HistoryScreen(chatId: _chatId),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'history',
                child: Text('History'),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
        ),
        child: Column(
          children: [
            // Display post context if available
            if (widget.postContext != null)
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Row(
                  children: [
                    if (widget.postContext!['image_base64'] != null)
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ImageViewer(
                                imageBase64:
                                    widget.postContext!['image_base64'],
                                tag:
                                    'post-context-${widget.postContext!['id']}',
                              ),
                            ),
                          );
                        },
                        child: Hero(
                          tag: 'post-context-${widget.postContext!['id']}',
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              base64Decode(widget.postContext!['image_base64']),
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Discussing Post: ${widget.postContext!['title']}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('conversations')
                    .doc(_chatId)
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .limit(50)
                    .snapshots(),
                builder: (context, snapshot) {
                  print('Stream update for chatId: $_chatId');
                  print('Connection state: ${snapshot.connectionState}');
                  print('Has data: ${snapshot.hasData}');
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final messages = snapshot.data?.docs ?? [];
                  print('Messages received: ${messages.length}');

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    itemCount: messages.length,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemBuilder: (context, index) {
                      final data =
                          messages[index].data() as Map<String, dynamic>;
                      final isMe = data['senderId'] == _currentUser!.uid;
                      final senderId = data['senderId'];

                      return Align(
                        alignment:
                            isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: isMe ? 64 : 16,
                            right: isMe ? 16 : 64,
                            bottom: 8,
                          ),
                          child: Column(
                            crossAxisAlignment: isMe
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              if (data['final_project'] != null)
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 10,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => ImageViewer(
                                                imageBase64:
                                                    data['final_project'],
                                                tag:
                                                    'project-${messages[index].id}',
                                              ),
                                            ),
                                          );
                                        },
                                        child: Hero(
                                          tag: 'project-${messages[index].id}',
                                          child: ClipRRect(
                                            borderRadius:
                                                const BorderRadius.vertical(
                                              top: Radius.circular(16),
                                            ),
                                            child: ConstrainedBox(
                                              constraints: BoxConstraints(
                                                maxWidth: MediaQuery.of(context)
                                                        .size
                                                        .width *
                                                    0.8,
                                                maxHeight:
                                                    MediaQuery.of(context)
                                                            .size
                                                            .height *
                                                        0.4,
                                              ),
                                              child: Image.memory(
                                                base64Decode(
                                                    data['final_project']),
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (!isMe && data['approved'] == null)
                                        Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            children: [
                                              _ActionButton(
                                                onPressed: () =>
                                                    _handleApproval(
                                                  false,
                                                  messages[index].id,
                                                  senderId,
                                                ),
                                                text: "Decline",
                                                color: Colors.red.shade600,
                                                isApprove: false,
                                              ),
                                              const SizedBox(width: 28),
                                              _ActionButton(
                                                onPressed: () =>
                                                    _handleApproval(
                                                  true,
                                                  messages[index].id,
                                                  senderId,
                                                ),
                                                text: "Approve",
                                                color: Colors.green.shade600,
                                                isApprove: true,
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (data['approved'] != null)
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12, horizontal: 16),
                                          decoration: BoxDecoration(
                                            color:
                                                data['approved'] == "accepted"
                                                    ? Colors.green.shade600
                                                        .withOpacity(0.12)
                                                    : Colors.red.shade600
                                                        .withOpacity(0.12),
                                            borderRadius:
                                                const BorderRadius.vertical(
                                              bottom: Radius.circular(16),
                                            ),
                                            border: Border(
                                              left: BorderSide(
                                                color: data['approved'] ==
                                                        "accepted"
                                                    ? Colors.green.shade600
                                                        .withOpacity(0.5)
                                                    : Colors.red.shade600
                                                        .withOpacity(0.5),
                                                width: 3,
                                              ),
                                              bottom: BorderSide(
                                                color: data['approved'] ==
                                                        "accepted"
                                                    ? Colors.green.shade600
                                                        .withOpacity(0.5)
                                                    : Colors.red.shade600
                                                        .withOpacity(0.5),
                                                width: 1.5,
                                              ),
                                              right: BorderSide(
                                                color: data['approved'] ==
                                                        "accepted"
                                                    ? Colors.green.shade600
                                                        .withOpacity(0.5)
                                                    : Colors.red.shade600
                                                        .withOpacity(0.5),
                                                width: 1.5,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: data['approved'] ==
                                                          "accepted"
                                                      ? Colors.green.shade600
                                                          .withOpacity(0.2)
                                                      : Colors.red.shade600
                                                          .withOpacity(0.2),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Text(
                                                  data['approved'] == "accepted"
                                                      ? "✅"
                                                      : "❌",
                                                  style:
                                                      TextStyle(fontSize: 14),
                                                ),
                                              ),
                                              SizedBox(width: 12),
                                              Text(
                                                data['approved'] == "accepted"
                                                    ? "Flyer Approved"
                                                    : "Flyer Declined",
                                                style: TextStyle(
                                                  color: data['approved'] ==
                                                          "accepted"
                                                      ? Colors.green.shade700
                                                      : Colors.red.shade700,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              if (data['textMessage']?.isNotEmpty == true)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isMe
                                        ? const Color(0xFF0084FF)
                                        : Colors.white,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(20),
                                      topRight: const Radius.circular(20),
                                      bottomLeft:
                                          Radius.circular(isMe ? 20 : 4),
                                      bottomRight:
                                          Radius.circular(isMe ? 4 : 20),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 10,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    data['textMessage'],
                                    style: TextStyle(
                                      color:
                                          isMe ? Colors.white : Colors.black87,
                                      fontSize: 16,
                                    ),
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
            // Update the selected image preview
            if (_selectedImage != null || _projectBase64 != null)
              Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.4,
                        ),
                        child: kIsWeb
                            ? Image.memory(
                                base64Decode(_projectBase64!),
                                width: double.infinity,
                                fit: BoxFit.contain,
                              )
                            : Image.file(
                                _selectedImage!,
                                width: double.infinity,
                                fit: BoxFit.contain,
                              ),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: GestureDetector(
                        onTap: _clearImage,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              child: Row(
                children: [
                  _UploadButton(
                    onTap: _isUploading ? null : _uploadProject,
                    isUploading: _isUploading,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: "Message...",
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF0084FF),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;
  final Color color;
  final bool isApprove;

  const _ActionButton({
    required this.onPressed,
    required this.text,
    required this.color,
    required this.isApprove,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.15),
        foregroundColor: color,
        elevation: 0,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withOpacity(0.5), width: 1.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          SizedBox(width: 8),
          Container(
            padding: EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Text(
              isApprove ? '✅' : '❌',
              style: TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool isUploading;

  const _UploadButton({
    required this.onTap,
    required this.isUploading,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF0084FF).withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: isUploading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0084FF)),
                ),
              )
            : Row(
                children: const [
                  Icon(
                    Icons.upload_file,
                    color: Color(0xFF0084FF),
                    size: 20,
                  ),
                  SizedBox(width: 4),
                  Text(
                    "Upload",
                    style: TextStyle(
                      color: Color(0xFF0084FF),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
