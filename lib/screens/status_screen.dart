import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:typed_data';

class StatusScreen extends StatefulWidget {
  const StatusScreen({Key? key}) : super(key: key);

  @override
  _StatusScreenState createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool isLoading = true;
  List<Map<String, dynamic>> acceptedPosts = [];
  List<Map<String, dynamic>> rejectedPosts = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    setState(() {
      isLoading = true;
    });

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        setState(() {
          isLoading = false;
        });
        return;
      }

      print('Fetching posts for user: ${currentUser.uid}');

      // First, get all chat documents that involve this user
      final chatCollectionRef = _firestore.collection('chats');
      final snapshot = await chatCollectionRef.get();
      
      for (var chatDoc in snapshot.docs) {
        // Check if this chat involves the current user
        final chatId = chatDoc.id;
        if (chatId.contains(currentUser.uid)) {
          print('Found chat document: $chatId');
          
          // Now get all messages in this chat
          final messagesRef = chatDoc.reference.collection('messages');
          final messagesSnapshot = await messagesRef.get();
          
          for (var messageDoc in messagesSnapshot.docs) {
            final messageData = messageDoc.data();
            final approved = messageData['approved'] as String?;
            
            // Skip if approved status isn't set
            if (approved == null) continue;
            
            // Add document data and reference for display
            final post = {
              ...messageData,
              'messageId': messageDoc.id,
              'chatId': chatId,
            };
            
            if (approved == 'accepted') {
              acceptedPosts.add(post);
              print('Added accepted post: ${messageDoc.id}');
            } else if (approved == 'declined') {
              rejectedPosts.add(post);
              print('Added rejected post: ${messageDoc.id}');
            }
          }
        }
      }
      
      print('Total accepted posts: ${acceptedPosts.length}');
      print('Total rejected posts: ${rejectedPosts.length}');
    } catch (e) {
      print('Error fetching posts: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post Status'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Accepted'),
            Tab(text: 'Rejected'),
          ],
          indicatorColor: Colors.white,
          labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 14),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPostList(posts: acceptedPosts, status: 'accepted'),
                _buildPostList(posts: rejectedPosts, status: 'declined'),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Refresh posts when button is pressed
          _fetchPosts();
        },
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildPostList({required List<Map<String, dynamic>> posts, required String status}) {
    if (posts.isEmpty) {
      return Center(
        child: Text(
          status == 'accepted'
              ? 'No accepted posts yet.'
              : 'No rejected posts yet.',
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        final textMessage = post['textMessage'] ?? '';
        final finalProject = post['final_project'] ?? '';
        final timestamp = post['timestamp'] as Timestamp?;
        final String formattedDate = timestamp != null
            ? '${timestamp.toDate().day}/${timestamp.toDate().month}/${timestamp.toDate().year} ${timestamp.toDate().hour}:${timestamp.toDate().minute}'
            : 'Unknown date';

        // Get chat participants from the chat ID
        final chatId = post['chatId'] as String;
        final participants = chatId.split('-');
        final currentUser = _auth.currentUser;
        final otherUserId = participants.firstWhere(
          (id) => id != currentUser?.uid,
          orElse: () => 'Unknown User',
        );

        Uint8List? imageBytes;
        if (finalProject.isNotEmpty) {
          try {
            print('Decoding image from post ${post['messageId']}');
            imageBytes = base64Decode(finalProject);
            print('Image decoded, size: ${imageBytes.length} bytes');
          } catch (e) {
            print('Error decoding image: $e');
          }
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageBytes != null)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: Image.memory(
                    imageBytes,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      print('Error displaying image: $error');
                      return Container(
                        width: double.infinity,
                        height: 200,
                        color: Colors.grey.shade300,
                        child: const Center(
                          child: Text(
                            'Unable to load image',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      textMessage.isEmpty ? 'No message' : textMessage,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Date: $formattedDate',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      'Chat with: $otherUserId',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      'Message ID: ${post['messageId']}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}