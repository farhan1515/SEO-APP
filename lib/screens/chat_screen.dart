import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:seo_app/services/user_status.dart';

import '../widgets/image_viewer.dart';

class ChatScreen extends StatefulWidget {
  final String recipientId;
  final String recipientName;

  const ChatScreen({
    Key? key,
    required this.recipientId,
    required this.recipientName,
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
            _selectedImage = File(pickedFile.path);
            _projectBase64 = base64Encode(bytes);
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

    // Clear input immediately for better UX
    final localProjectBase64 = _projectBase64;
    _controller.clear();
    _clearImage();

    try {
      // Batch write for atomic operations
      final batch = _firestore.batch();

      // Add message
      final messageRef = _firestore
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .doc();

      batch.set(messageRef, {
        'senderId': _currentUser!.uid,
        'receiverId': widget.recipientId,
        'textMessage': message.isNotEmpty ? message : "",
        'final_project': localProjectBase64,
        'timestamp': timestamp,
      });

      final lastMessageText = message.isNotEmpty ? message : "Project Sent";

      // Update current user's chat
      batch.set(
        _firestore
            .collection('userChats')
            .doc(_currentUser!.uid)
            .collection('activeChats')
            .doc(widget.recipientId),
        {
          'partnerName': widget.recipientName,
          'lastMessage': lastMessageText,
          'timestamp': timestamp,
        },
        SetOptions(merge: true),
      );

      // Update recipient's chat
      batch.set(
        _firestore
            .collection('userChats')
            .doc(widget.recipientId)
            .collection('activeChats')
            .doc(_currentUser!.uid),
        {
          'partnerName': _currentUser!.displayName ?? "Unknown",
          'lastMessage': lastMessageText,
          'timestamp': timestamp,
        },
        SetOptions(merge: true),
      );

      await batch.commit();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    }
  }

  Future<void> _handleApproval(
      bool isApproved, String messageId, String senderId) async {
    final responseMessage = isApproved
        ? "Design is approved!  Love | Like | Claps Icons"
        : "Sorry! Can you please comment where exactly went wrong?";
//approve ku thumb icon decline 
    try {
      final batch = _firestore.batch();

      // Add response message
      final responseRef = _firestore
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .doc();

      batch.set(responseRef, {
        'senderId': _currentUser!.uid,
        'receiverId': senderId,
        'textMessage': responseMessage,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update original message
      batch.update(
        _firestore
            .collection('chats')
            .doc(_chatId)
            .collection('messages')
            .doc(messageId),
        {'approved': isApproved ? "accepted" : "declined"},
      );

      await batch.commit();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to process approval: $e')),
      );
    }
  }

  String _generateChatId(String user1, String user2) {
    return user1.hashCode <= user2.hashCode ? "$user1-$user2" : "$user2-$user1";
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
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black87),
            onPressed: () {},
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
        ),
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('chats')
                    .doc(_chatId)
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .limit(50)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final messages = snapshot.data?.docs ?? [];

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
                                                    0.7,
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
                                            children: [
                                              _ActionButton(
                                                onPressed: () =>
                                                    _handleApproval(
                                                  true,
                                                  messages[index].id,
                                                  senderId,
                                                ),
                                                text: "Approve",
                                                color: Colors.green,
                                              ),
                                              const SizedBox(width: 8),
                                              _ActionButton(
                                                onPressed: () =>
                                                    _handleApproval(
                                                  false,
                                                  messages[index].id,
                                                  senderId,
                                                ),
                                                text: "Decline",
                                                color: Colors.red,
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (data['approved'] != null)
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: data['approved'] ==
                                                    "accepted"
                                                ? Colors.green.withOpacity(0.1)
                                                : Colors.red.withOpacity(0.1),
                                            borderRadius:
                                                const BorderRadius.vertical(
                                              bottom: Radius.circular(16),
                                            ),
                                          ),
                                          child: Text(
                                            data['approved'] == "accepted"
                                                ? "✅ Project Approved"
                                                : "❌ Project Declined",
                                            style: TextStyle(
                                              color:
                                                  data['approved'] == "accepted"
                                                      ? Colors.green
                                                      : Colors.red,
                                              fontWeight: FontWeight.bold,
                                            ),
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
            if (_selectedImage != null)
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
                        child: Image.file(
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

  const _ActionButton({
    required this.onPressed,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
        ),
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
