import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:seo_app/theme/text_style.dart';
import 'chat_screen.dart';
import 'package:timeago/timeago.dart'
    as timeago; // Add this package to pubspec.yaml
import 'package:solar_icons/solar_icons.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  @override
  void initState() {
    super.initState();
    _updateLastActive();
  }

  Future<void> _updateLastActive() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Get all conversations for current user
    final userChats = await FirebaseFirestore.instance
        .collection('user_conversations')
        .doc(currentUser.uid)
        .collection('chats')
        .get();

    // Update last active for each conversation
    for (var chat in userChats.docs) {
      final chatId = chat.id;
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(chatId)
          .update({
        'lastActive.${currentUser.uid}': FieldValue.serverTimestamp(),
      });
    }
  }

  String _getLastActiveStatus(Timestamp? lastActive, bool? isOnline) {
    if (lastActive == null) return 'Offline';

    final now = DateTime.now();
    final lastActiveTime = lastActive.toDate();
    final difference = now.difference(lastActiveTime);

    // Check if user is currently online (updated within last 2 minutes)
    if (isOnline == true && difference.inMinutes < 2) {
      return 'Active now';
    } else if (difference.inMinutes < 60) {
      return 'Active ${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return 'Active ${difference.inHours}h ago';
    } else {
      return 'Active ${difference.inDays}d ago';
    }
  }

  bool _isPartnerTyping(DocumentSnapshot? typingDoc, String partnerId) {
    if (typingDoc == null || !typingDoc.exists) return false;

    try {
      final data = typingDoc.data() as Map<String, dynamic>?;
      final partnerData = data?[partnerId] as Map<String, dynamic>?;

      if (partnerData == null) return false;

      final isTyping = partnerData['isTyping'] as bool? ?? false;
      final timestamp = partnerData['timestamp'] as Timestamp?;

      if (!isTyping || timestamp == null) return false;

      // Check if typing status is recent (within last 5 seconds)
      final now = DateTime.now();
      final typingTime = timestamp.toDate();
      final difference = now.difference(typingTime);

      return difference.inSeconds < 5;
    } catch (e) {
      // Return false if there's any error reading typing status
      return false;
    }
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
              Icon(Icons.chat_bubble_outline,
                  size: 80, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Please log in to view your chats',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        // leading: Padding(
        //   padding: const EdgeInsets.only(left: 10),
        //   child: IconButton(
        //     icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
        //     onPressed: () => Navigator.pop(context),
        //   ),
        // ),
        title: Text(
          'Messages',
          style: lexand.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
          // style: TextStyle(
          //   fontSize: 24,
          //   fontWeight: FontWeight.bold,
          //   color: Colors.black,
          // ),
        ),
        centerTitle: true,
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.search, color: Colors.black),
        //     onPressed: () {
        //       // Implement search functionality
        //     },
        //   ),
        // ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('user_conversations')
            .doc(currentUser.uid)
            .collection('chats')
            .orderBy('updatedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
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
                      SolarIconsOutline.chatRoundDots,
                      size: 64,
                      color: Color(0xFF5664F5),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No messages yet',
                    style: lexand.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
            );
          }

          final chats = snapshot.data!.docs;
          print('Found ${chats.length} chats for user ${currentUser.uid}');

          return ListView.builder(
            padding: const EdgeInsets.only(top: 8),
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index].data() as Map<String, dynamic>;
              final partnerId = chat['partnerId'] is String
                  ? chat['partnerId'] as String
                  : 'Unknown';
              final partnerName = chat['partnerName'] is String
                  ? chat['partnerName'] as String
                  : 'Unknown';
              final lastMessage =
                  chat['lastMessage'] as String? ?? 'New conversation';
              final timestamp = chat['lastMessageTime'] as Timestamp?;
              final unreadCount = chat['unreadCount'] as int? ?? 0;

              print(
                  'Chat with $partnerName (ID: $partnerId), unread: $unreadCount');

              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(partnerId)
                    .snapshots(),
                builder: (context, userSnapshot) {
                  final userData =
                      userSnapshot.data?.data() as Map<String, dynamic>?;
                  final partnerLastActive =
                      userData?['lastActive'] as Timestamp?;
                  final partnerIsOnline =
                      userData?['isOnline'] as bool? ?? false;

                  return StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('typing_status')
                        .doc(_generateChatId(currentUser.uid, partnerId))
                        .snapshots(),
                    builder: (context, typingSnapshot) {
                      final isPartnerTyping =
                          _isPartnerTyping(typingSnapshot.data, partnerId);

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        child: Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.purple.withOpacity(0.1),
                                  offset: const Offset(0, 4),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                                BoxShadow(
                                  color: Colors.pink.withOpacity(0.05),
                                  offset: const Offset(0, -2),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                print(
                                    'Opening chat with partner ID: $partnerId');
                                print('Partner name: $partnerName');

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatScreen(
                                      recipientId: partnerId,
                                      recipientName: partnerName,
                                    ),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Stack(
                                      children: [
                                        CircleAvatar(
                                          radius: 28,
                                          backgroundColor:
                                              const Color(0xFFE8F0FE),
                                          child: Text(
                                            partnerName.isNotEmpty
                                                ? partnerName[0].toUpperCase()
                                                : '?',
                                            style: lexand.copyWith(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF7C7BFF),
                                            ),
                                          ),
                                        ),
                                        if (unreadCount > 0)
                                          Positioned(
                                            right: 0,
                                            top: 0,
                                            child: Container(
                                              padding: EdgeInsets.all(4),
                                              decoration: const BoxDecoration(
                                                color: Color(0xFFFF8FAB),
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Color(0x29FF8FAB),
                                                    blurRadius: 4,
                                                    spreadRadius: 1,
                                                  ),
                                                ],
                                              ),
                                              child: Text(
                                                unreadCount.toString(),
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  partnerName,
                                                  style: lexand.copyWith(
                                                    fontSize: 16,
                                                    fontWeight: unreadCount > 0
                                                        ? FontWeight.bold
                                                        : FontWeight.w500,
                                                    color:
                                                        const Color(0xFF2D3142),
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (timestamp != null)
                                                Text(
                                                  timeago.format(
                                                      timestamp.toDate(),
                                                      allowFromNow: true),
                                                  style: headsmall.copyWith(
                                                    fontSize: 12,
                                                    color:
                                                        const Color(0xFF9BA0B3)
                                                            .withOpacity(0.8),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: isPartnerTyping
                                                    ? Row(
                                                        children: [
                                                          Text(
                                                            'Typing',
                                                            style:
                                                                texts.copyWith(
                                                              fontSize: 14,
                                                              color: Color(
                                                                  0xFF5664F5),
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              fontStyle:
                                                                  FontStyle
                                                                      .italic,
                                                            ),
                                                          ),
                                                          SizedBox(width: 8),
                                                          _TypingDotsAnimation(),
                                                        ],
                                                      )
                                                    : Text(
                                                        lastMessage,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: texts.copyWith(
                                                          fontSize: 14,
                                                          color: unreadCount > 0
                                                              ? const Color(
                                                                  0xFF4A4B57)
                                                              : const Color(
                                                                  0xFF9BA0B3),
                                                          fontWeight:
                                                              unreadCount > 0
                                                                  ? FontWeight
                                                                      .w500
                                                                  : FontWeight
                                                                      .normal,
                                                        ),
                                                      ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                _getLastActiveStatus(
                                                    partnerLastActive,
                                                    partnerIsOnline),
                                                style: texts.copyWith(
                                                  fontSize: 12,
                                                  color: partnerIsOnline &&
                                                          partnerLastActive !=
                                                              null &&
                                                          DateTime.now()
                                                                  .difference(
                                                                      partnerLastActive
                                                                          .toDate())
                                                                  .inMinutes <
                                                              2
                                                      ? Colors.green
                                                      : const Color(0xFF9BA0B3),
                                                ),
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
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: () {
      //     // Implement new chat functionality
      //   },
      //   backgroundColor: Colors.blue,
      //   child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
      // ),
    );
  }

  String _generateChatId(String user1, String user2) {
    final ids = [user1, user2]..sort();
    return '${ids[0]}-${ids[1]}';
  }
}

class _TypingDotsAnimation extends StatefulWidget {
  const _TypingDotsAnimation({Key? key}) : super(key: key);

  @override
  State<_TypingDotsAnimation> createState() => _TypingDotsAnimationState();
}

class _TypingDotsAnimationState extends State<_TypingDotsAnimation>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _animations = List.generate(3, (index) {
      return Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(
            index * 0.25,
            0.75 + index * 0.25,
            curve: Curves.easeInOut,
          ),
        ),
      );
    });

    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _animations[index],
          builder: (context, child) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              child: Opacity(
                opacity: 0.3 + (_animations[index].value * 0.7),
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Color(0xFF5664F5),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
