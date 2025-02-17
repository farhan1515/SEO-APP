import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:seo_app/theme/text_style.dart';
import 'chat_screen.dart';
import 'package:timeago/timeago.dart'
    as timeago; // Add this package to pubspec.yaml

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({Key? key}) : super(key: key);

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
        leading: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: const Text(
          'Messages',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
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
            .collection('userChats')
            .doc(currentUser.uid)
            .collection('activeChats')
            .orderBy('timestamp', descending: true)
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
                  Image.asset(
                    'assets/images/no_messages.png', // Add this image to your assets
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No messages yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start chatting with your contacts',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          final chats = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.only(top: 8),
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index].data() as Map<String, dynamic>;
              final partnerName = chat['partnerName'];
              final partnerId = chats[index].id;
              final lastMessage = chat['lastMessage'];
              final timestamp = chat['timestamp'] as Timestamp?;
              final isUnread = chat['unread'] ??
                  false; // Add unread status to your chat data

              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                                  backgroundColor: const Color(
                                      0xFFE8F0FE), // Light pastel blue
                                  child: Text(
                                    partnerName[0].toUpperCase(),
                                    style: lexand.copyWith(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF7C7BFF),
                                    ),
                                    // style: const TextStyle(
                                    //   fontSize: 20,
                                    //   fontWeight: FontWeight.bold,
                                    //   color: Color(0xFF7C7BFF), // Soft purple
                                    // ),
                                  ),
                                ),
                                if (isUnread)
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFFF8FAB), // Soft pink
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Color(
                                                0x29FF8FAB), // Transparent pink
                                            blurRadius: 4,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                            fontWeight: isUnread
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                            color: const Color(0xFF2D3142),
                                          ),
                                          // style: TextStyle(
                                          //   fontSize: 16,
                                          //   fontWeight: isUnread
                                          //       ? FontWeight.bold
                                          //       : FontWeight.w500,
                                          //   color: const Color(
                                          //       0xFF2D3142), // Dark blue-grey
                                          // ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (timestamp != null)
                                        Text(
                                          timeago.format(timestamp.toDate(),
                                              allowFromNow: true),
                                          style: headsmall.copyWith(
                                            fontSize: 12,
                                            color: const Color(0xFF9BA0B3)
                                                .withOpacity(
                                                    0.8), // Muted blue-grey
                                          ),
                                          // style: TextStyle(
                                          //   fontSize: 12,
                                          //   color: const Color(0xFF9BA0B3)
                                          //       .withOpacity(
                                          //           0.8), // Muted blue-grey
                                          // ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    lastMessage,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: texts.copyWith(
                                      fontSize: 14,
                                      color: isUnread
                                          ? const Color(
                                              0xFF4A4B57) // Darker grey
                                          : const Color(
                                              0xFF9BA0B3), // Muted blue-grey
                                      fontWeight: isUnread
                                          ? FontWeight.w500
                                          : FontWeight.normal,
                                    ),
                                    // style: TextStyle(
                                    //   fontSize: 14,
                                    //   color: isUnread
                                    //       ? const Color(
                                    //           0xFF4A4B57) // Darker grey
                                    //       : const Color(
                                    //           0xFF9BA0B3), // Muted blue-grey
                                    //   fontWeight: isUnread
                                    //       ? FontWeight.w500
                                    //       : FontWeight.normal,
                                    // ),
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
}
