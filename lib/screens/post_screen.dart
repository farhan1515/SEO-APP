import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:seo_app/screens/home_screen.dart';
import 'package:seo_app/screens/main_screen.dart';
import 'package:seo_app/screens/profile_list_screen.dart';
import 'package:seo_app/screens/profile_screen.dart';
import 'package:seo_app/screens/settings_screen.dart';
import 'package:seo_app/theme/text_style.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/recurring_schedule.dart';
import '../widgets/schedule_selector.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:seo_app/services/notification_service.dart';
import 'package:seo_app/services/twilio_service.dart';
import 'package:http/http.dart' as http;

class PostScreen extends StatefulWidget {
  final Map<String, dynamic>? existingData;

  const PostScreen({super.key, this.existingData});

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _highlightController = TextEditingController();
  List<String> selectedPlatforms = [];
  Uint8List? _selectedImageBytes;

  DateTime? _scheduledDate;
  String? _scheduledTime;
  String? _scheduledTimezone;
  RecurringSchedule? _recurringSchedule;
  String? _selectedProfileId;
  List<Map<String, dynamic>> _userProfiles = [];
  final _referenceLinkController = TextEditingController();
  Uint8List? _selectedFlyerImageBytes;
  bool _isDesignerOrManager = false;

  final GlobalKey<ScheduleSelectorState> _scheduleSelectorKey = GlobalKey();

  Future<void> _fetchUserProfiles() async {
    if (widget.existingData == null ||
        widget.existingData!['profile_id'] == null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('profiles')
            .doc(user.uid)
            .collection('profiles')
            .get();

        setState(() {
          _userProfiles = querySnapshot.docs.map((doc) {
            return {
              'id': doc.id,
              'name':
                  doc.data()['businessDetails']['name'] ?? 'Unnamed Profile',
            };
          }).toList();
        });
      } catch (e) {
        print('Error fetching profiles: $e');
      }
      return;
    }

    try {
      final profilePath = widget.existingData!['profile_id'].split('/');
      if (profilePath.length >= 3) {
        final profileDoc = await FirebaseFirestore.instance
            .collection('profiles')
            .doc(profilePath[1])
            .collection('profiles')
            .doc(profilePath[2])
            .get();

        setState(() {
          _userProfiles = [
            {
              'id': widget.existingData!['profile_id'],
              'name': profileDoc.data()?['businessDetails']['name'] ??
                  widget.existingData!['profile_name'] ??
                  'Original Profile',
            }
          ];
          _selectedProfileId = widget.existingData!['profile_id'];
        });
      }
    } catch (e) {
      print('Error fetching original profile: $e');
      setState(() {
        _userProfiles = [
          {
            'id': widget.existingData!['profile_id'],
            'name': widget.existingData!['profile_name'] ?? 'Original Profile',
          }
        ];
        _selectedProfileId = widget.existingData!['profile_id'];
      });
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.existingData != null) {
      _titleController.text = widget.existingData!['title'] ?? '';
      _descriptionController.text = widget.existingData!['description'] ?? '';
      _highlightController.text =
          widget.existingData!['highlighted_text'] ?? '';
      selectedPlatforms =
          List<String>.from(widget.existingData!['platforms'] ?? []);
      _selectedImageBytes = widget.existingData!['image_base64'] != null
          ? base64Decode(widget.existingData!['image_base64'])
          : null;
      _scheduledDate = widget.existingData!['scheduled_date'] != null
          ? DateTime.parse(widget.existingData!['scheduled_date'])
          : null;
      _scheduledTime = widget.existingData!['scheduled_time'];
      _scheduledTimezone = widget.existingData!['scheduled_timezone'];
      _recurringSchedule = widget.existingData!['recurring_schedule'] != null
          ? RecurringSchedule.fromJson(
              widget.existingData!['recurring_schedule'])
          : null;
      _selectedProfileId = widget.existingData!['profile_id'];
      _referenceLinkController.text =
          widget.existingData!['reference_link'] ?? '';
      _selectedFlyerImageBytes = widget.existingData!['flyer_base64'] != null
          ? base64Decode(widget.existingData!['flyer_base64'])
          : null;
    }
    _fetchUserProfiles();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final roleDoc = await FirebaseFirestore.instance
        .collection('roles')
        .doc(user.uid)
        .get();

    final role = roleDoc.data()?['role'] as String?;

    setState(() {
      _isDesignerOrManager =
          role == 'Graphic Designer' || role == 'SEO.Credit Manager';
    });
  }

  Future<void> _pickImage() async {
    if (kIsWeb) {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null) {
        final fileBytes = result.files.single.bytes;
        if (fileBytes != null) {
          setState(() {
            _selectedImageBytes = fileBytes;
          });
        }
      }
    } else {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        final fileBytes = await pickedFile.readAsBytes();
        setState(() {
          _selectedImageBytes = fileBytes;
        });
      }
    }
  }

  Future<void> _pickFlyerImage() async {
    if (kIsWeb) {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null) {
        final fileBytes = result.files.single.bytes;
        if (fileBytes != null) {
          setState(() {
            _selectedFlyerImageBytes = fileBytes;
          });
        }
      }
    } else {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        final fileBytes = await pickedFile.readAsBytes();
        setState(() {
          _selectedFlyerImageBytes = fileBytes;
        });
      }
    }
  }

  Future<String?> _convertImageToBase64(Uint8List imageBytes) async {
    try {
      img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) {
        print('Failed to decode image');
        return null;
      }
      img.Image resizedImage = img.copyResize(originalImage,
          width: 800, height: 800, interpolation: img.Interpolation.average);
      List<int> compressedBytes = img.encodeJpg(resizedImage, quality: 70);
      return base64Encode(compressedBytes);
    } catch (e) {
      print('Error converting image to Base64: $e');
      return null;
    }
  }

  Future<String?> _uploadFlyerToStorage(
      Uint8List flyerBytes, String postId) async {
    try {
      final ref =
          FirebaseStorage.instance.ref().child('flyers').child('$postId.jpg');
      await ref.putData(
          flyerBytes, SettableMetadata(contentType: 'image/jpeg'));
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error uploading flyer to storage: $e');
      return null;
    }
  }

  Future<void> _submitData() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final highlightedText = _highlightController.text.trim();
    final currentUser = FirebaseAuth.instance.currentUser;

    if (title.isEmpty ||
        description.isEmpty ||
        highlightedText.isEmpty ||
        selectedPlatforms.isEmpty ||
        _scheduledDate == null ||
        _scheduledTime == null ||
        _scheduledTimezone == null ||
        _selectedProfileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields.')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
        ),
      ),
    );

    try {
      String? imageBase64;
      if (_selectedImageBytes != null) {
        imageBase64 = await _convertImageToBase64(_selectedImageBytes!);
      }

      String? flyerBase64;
      String? flyerStorageUrl;
      String postId = widget.existingData?['id'] ??
          DateTime.now().millisecondsSinceEpoch.toString();
      if (_isDesignerOrManager && _selectedFlyerImageBytes != null) {
        flyerBase64 = await _convertImageToBase64(_selectedFlyerImageBytes!);
        flyerStorageUrl =
            await _uploadFlyerToStorage(_selectedFlyerImageBytes!, postId);
      } else if (widget.existingData != null) {
        flyerBase64 = widget.existingData!['flyer_base64'];
        flyerStorageUrl = widget.existingData!['flyer_storage_url'];
      }

      final postData = {
        'title': title,
        'title_lowercase': title.toLowerCase(),
        'description': description,
        'highlighted_text': highlightedText,
        'platforms': selectedPlatforms,
        'user_id': widget.existingData?['user_id'] ?? currentUser?.uid,
        'user_name': widget.existingData?['user_name'] ??
            currentUser?.displayName ??
            'Anonymous',
        'profile_id': widget.existingData?['profile_id'] ?? _selectedProfileId,
        'profile_name': widget.existingData?['profile_name'] ??
            _userProfiles.firstWhere(
              (profile) => profile['id'] == _selectedProfileId,
              orElse: () => {'name': 'No Profile'},
            )['name'],
        'created_at': widget.existingData != null
            ? widget.existingData!['created_at'] ?? FieldValue.serverTimestamp()
            : FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'scheduled_date': _scheduledDate?.toIso8601String(),
        'scheduled_time': _scheduledTime,
        'scheduled_timezone': _scheduledTimezone,
        'recurring_schedule': _recurringSchedule?.toJson(),
        'reference_link': _referenceLinkController.text.trim(),
        'image_base64': imageBase64,
      };

      // Check if this is an edit and if the flyer has changed
      bool flyerChanged = false;
      String? originalFlyerBase64 = widget.existingData?['flyer_base64'];
      if (widget.existingData != null && widget.existingData!['id'] != null) {
        if (flyerBase64 != null && flyerBase64 != originalFlyerBase64) {
          flyerChanged = true;
        } else if (flyerBase64 == null && originalFlyerBase64 != null) {
          flyerChanged = true;
        }
      }

      // Determine if the current user is a Designer/Manager editing a Customer's post
      bool isDesignerEditingCustomerPost = false;
      if (widget.existingData != null && widget.existingData!['id'] != null) {
        final roleDoc = await FirebaseFirestore.instance
            .collection('roles')
            .doc(currentUser!.uid)
            .get();
        final userRole = roleDoc.data()?['role'] as String?;
        if (userRole == 'SEO.Credit Manager' ||
            userRole == 'Graphic Designer') {
          if (widget.existingData!['user_id'] != currentUser.uid) {
            isDesignerEditingCustomerPost = true;
          }
        }
      }

      // Save the post
      if (widget.existingData != null && widget.existingData!['id'] != null) {
        // Update existing post
        if (isDesignerEditingCustomerPost && flyerChanged) {
          // Designer is editing a Customer's post and the flyer changed
          postData['updated_flyer_base64'] = flyerBase64;
          postData['updated_flyer_storage_url'] = flyerStorageUrl;
          postData['flyer_approval_status'] = 'pending';
          postData['last_updated_by'] = currentUser!.uid;
        } else {
          // Either not a Designer editing a Customer's post, or flyer didn't change
          postData['flyer_base64'] = flyerBase64;
          postData['flyer_storage_url'] = flyerStorageUrl;
          postData['updated_flyer_base64'] = null;
          postData['updated_flyer_storage_url'] = null;
          postData['flyer_approval_status'] = null;
        }
        await FirebaseFirestore.instance
            .collection('post_requests')
            .doc(widget.existingData!['id'])
            .update(postData);
      } else {
        // Create new post
        postData['flyer_base64'] = flyerBase64;
        postData['flyer_storage_url'] = flyerStorageUrl;
        postData['updated_flyer_base64'] = null;
        postData['updated_flyer_storage_url'] = null;
        postData['flyer_approval_status'] = null;
        await FirebaseFirestore.instance
            .collection('post_requests')
            .add(postData);
      }

      // If the flyer changed and this is a Designer editing a Customer's post, notify the Customer
      if (isDesignerEditingCustomerPost &&
          flyerChanged &&
          widget.existingData != null) {
        final originalPosterId = widget.existingData!['user_id'];
        final originalPosterName =
            widget.existingData!['user_name'] ?? 'Anonymous';
        final chatId = _generateChatId(currentUser!.uid, originalPosterId);

        final batch = FirebaseFirestore.instance.batch();
        final messageRef = FirebaseFirestore.instance
            .collection('conversations')
            .doc(chatId)
            .collection('messages')
            .doc();

        batch.set(messageRef, {
          'senderId': currentUser.uid,
          'receiverId': originalPosterId,
          'textMessage':
              'I updated the flyer for your post: "$title". Please review it here OR in the Pending Approvals section.',
          'final_project': flyerBase64,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'sent',
        });

        // Update conversation metadata
        batch.update(
            FirebaseFirestore.instance.collection('conversations').doc(chatId),
            {
              'lastMessage': 'Updated flyer for post: "$title"',
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
            'partnerId': originalPosterId,
            'partnerName': originalPosterName,
            'lastMessage': 'Updated flyer for post: "$title"',
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
              .doc(originalPosterId)
              .collection('chats')
              .doc(chatId),
          {
            'partnerId': currentUser.uid,
            'partnerName': currentUser.displayName ?? 'Unknown',
            'lastMessage': 'Updated flyer for post: "$title"',
            'lastMessageTime': FieldValue.serverTimestamp(),
            'unreadCount': FieldValue.increment(1),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        // Send notification for the flyer update
        await NotificationService.sendNotification(
          recipientId: originalPosterId,
          title: '📢 New Flyer Update',
          body:
              '${currentUser.displayName ?? "A designer"} updated the flyer for your post: "$title"',
          type: 'project',
          chatId: chatId,
          senderId: currentUser.uid,
          senderName: currentUser.displayName ?? "Unknown",
          postId: widget.existingData!['id'],
          postTitle: title,
        );

        // Send WhatsApp message via Twilio with the flyer image using the storage URL
        // TODO: Replace with your actual credentials securely (e.g., from environment variables)
        const accountSid = String.fromEnvironment('TWILIO_ACCOUNT_SID', defaultValue: 'YOUR_SID_HERE');
        const authToken = String.fromEnvironment('TWILIO_AUTH_TOKEN', defaultValue: 'YOUR_TOKEN_HERE');
        const fromNumber = String.fromEnvironment('TWILIO_FROM_NUMBER', defaultValue: 'whatsapp:+14155238886');

        final twilio = TwilioService(
          accountSid: accountSid,
          authToken: authToken,
          fromNumber: fromNumber,
        );
        try {
          await twilio.sendWhatsAppMessageWithImageUrl(
            '+919014263260',
            'I updated the flyer for your post: "$title". Please review it here OR in the Pending Approvals section.',
            flyerStorageUrl,
          );
        } catch (e) {
          print('Failed to send WhatsApp message with flyer: $e');
          // Fallback: try sending just the text message
          try {
            await twilio.sendWhatsAppMessage(
              '+919014263260',
              'I updated the flyer for your post: "$title". Please review it here OR in the Pending Approvals section. (Image could not be attached)',
            );
          } catch (fallbackError) {
            print('Failed to send fallback WhatsApp message: $fallbackError');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Post updated but WhatsApp notification failed'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
        await batch.commit();
      }

      Navigator.of(context, rootNavigator: true).pop();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MainScreen(),
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.existingData != null
                ? 'Post updated successfully!'
                : 'Post created successfully!',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Submission failed: [32m${e.toString()}[0m',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
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
    final User? user = FirebaseAuth.instance.currentUser;
    final String? displayName = user?.displayName;
    final String? photoURL = user?.photoURL;
    final String userId = user?.uid ?? '';
    return Scaffold(
      backgroundColor: Color(0xFFD3BDFC),
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.only(left: 20, right: 20),
              child: Container(
                height: 90,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(35),
                    bottomRight: Radius.circular(35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ProfileListScreen(userId: userId),
                              ),
                            );
                          },
                          child: CircleAvatar(
                            radius: 25,
                            backgroundImage: photoURL != null
                                ? NetworkImage(photoURL)
                                : null,
                            child: photoURL == null
                                ? const Icon(Icons.person, color: Colors.white)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Hi, ${displayName?.split(' ')[0] ?? 'User'}!',
                          style:
                              mont.copyWith(fontSize: 18, color: Colors.black),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(SolarIconsOutline.heart),
                          onPressed: () {},
                          color: Colors.black,
                        ),
                        IconButton(
                          icon: const Icon(SolarIconsOutline.settings),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => SettingScreen()),
                            );
                          },
                          color: Colors.black,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 70,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Color(0xFFD3BDFC),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Post a Request',
                              style: mont.copyWith(
                                  color: Color(0xFF3E1885),
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Fill the details and see the magic',
                              style: mont.copyWith(
                                  color: Color(0xFF3E1885),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w300),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(
                            SolarIconsOutline.infoCircle,
                            color: Color(0xFF3E1885),
                          ),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 190,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: Colors.white,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_userProfiles.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Business Profile',
                            style: mont.copyWith(
                              color: Color(0xFF000000),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (widget.existingData != null)
                            TextFormField(
                              readOnly: true,
                              initialValue: _userProfiles.first['name'],
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                              ),
                            )
                          else
                            DropdownButtonFormField<String>(
                              value: _selectedProfileId,
                              hint: Text(
                                'Choose a profile',
                                style: mont.copyWith(
                                    color: Colors.grey,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w200),
                              ),
                              items: _userProfiles.map((profile) {
                                return DropdownMenuItem<String>(
                                  value: profile['id'],
                                  child: Text(
                                    profile['name'],
                                    style: mont.copyWith(fontSize: 14),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedProfileId = value;
                                });
                              },
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                      width: 1.5, color: Color(0xFF3E1885)),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                              ),
                            ),
                          const SizedBox(height: 16),
                        ],
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Business Profile',
                            style: mont.copyWith(
                              color: Color(0xFF000000),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.purple[300]!,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              widget.existingData != null
                                  ? 'Original profile: ${widget.existingData!['profile_name'] ?? 'Not available'}'
                                  : 'No profiles found. Please create a profile first.',
                              style: mont.copyWith(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    Text(
                      'Title',
                      style: mont.copyWith(
                          color: Color(0xFF000000),
                          fontSize: 14,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _titleController,
                      style: mont.copyWith(
                        fontSize: 14,
                        color: Colors.black,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Poster title here...',
                        hintStyle: mont.copyWith(
                            color: Colors.grey,
                            fontSize: 12,
                            fontWeight: FontWeight.w200),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              BorderSide(width: 1.5, color: Color(0xFF3E1885)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.purple[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              BorderSide(width: 1.5, color: Color(0xFF3E1885)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Upto 20 characters',
                      style:
                          mont.copyWith(color: Color(0xFF000000), fontSize: 11),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Description',
                      style: mont.copyWith(
                          color: Color(0xFF000000),
                          fontSize: 14,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descriptionController,
                      style: mont.copyWith(
                        fontSize: 14,
                        color: Colors.black,
                      ),
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Description goes here...',
                        hintStyle: mont.copyWith(
                            color: Colors.grey[400],
                            fontSize: 12,
                            fontWeight: FontWeight.w200),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              BorderSide(width: 1.5, color: Color(0xFF3E1885)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.purple[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              BorderSide(width: 1.5, color: Color(0xFF3E1885)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Upto 240 characters',
                      style:
                          mont.copyWith(color: Color(0xFF000000), fontSize: 11),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'HighLighting Aspects',
                      style: mont.copyWith(
                          color: Color(0xFF000000),
                          fontSize: 14,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _highlightController,
                      style: mont.copyWith(
                        fontSize: 14,
                        color: Colors.black,
                      ),
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Add what all to be highlighted',
                        hintStyle: mont.copyWith(
                            color: Colors.grey[400],
                            fontSize: 12,
                            fontWeight: FontWeight.w200),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              BorderSide(width: 1.5, color: Color(0xFF3E1885)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.purple[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              BorderSide(width: 1.5, color: Color(0xFF3E1885)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Upto 240 characters',
                      style:
                          mont.copyWith(color: Color(0xFF000000), fontSize: 11),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Reference Image',
                      style: mont.copyWith(
                          color: Color(0xFF000000),
                          fontSize: 14,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickImage,
                      child: DottedBorder(
                        borderType: BorderType.RRect,
                        radius: Radius.circular(10),
                        color: Color(0xFF3E1885),
                        strokeWidth: 2,
                        dashPattern: [10, 10],
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 30),
                          decoration: BoxDecoration(
                            color: Color.fromRGBO(62, 24, 133, 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                SolarIconsOutline.galleryAdd,
                                size: 50,
                                color: Color(0xFF3E1885),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Add Media (png, jpg)',
                                style: mont.copyWith(
                                  color: Color(0xFF3E1885),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Up to 20 MB',
                                style: mont.copyWith(
                                  color: Color(0xFF3E1885).withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_selectedImageBytes != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            _selectedImageBytes!,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    // Add this after the Reference Image section

                    Text(
                      'Reference Link(If Any)',
                      style: mont.copyWith(
                        color: Color(0xFF000000),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _referenceLinkController,
                      style: mont.copyWith(
                        fontSize: 14,
                        color: Colors.black,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Reference link here...',
                        hintStyle: mont.copyWith(
                          color: Colors.grey[400],
                          fontSize: 12,
                          fontWeight: FontWeight.w200,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              BorderSide(width: 1.5, color: Color(0xFF3E1885)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.purple[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              BorderSide(width: 1.5, color: Color(0xFF3E1885)),
                        ),
                      ),
                    ),

// Add Flyer Image section only for designers/managers
                    if (_isDesignerOrManager) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Flyer Image',
                        style: mont.copyWith(
                          color: Color(0xFF000000),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _pickFlyerImage,
                        child: DottedBorder(
                          borderType: BorderType.RRect,
                          radius: Radius.circular(10),
                          color: Color(0xFF3E1885),
                          strokeWidth: 2,
                          dashPattern: [10, 10],
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 30),
                            decoration: BoxDecoration(
                              color: Color.fromRGBO(62, 24, 133, 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  SolarIconsOutline.galleryAdd,
                                  size: 50,
                                  color: Color(0xFF3E1885),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Add Flyer Image (png, jpg)',
                                  style: mont.copyWith(
                                    color: Color(0xFF3E1885),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'Up to 20 MB',
                                  style: mont.copyWith(
                                    color: Color(0xFF3E1885).withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (_selectedFlyerImageBytes != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              _selectedFlyerImageBytes!,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: 16),

                    Text(
                      'Posting Platforms',
                      style: mont.copyWith(
                        fontSize: 14,
                        color: Color(0xFF3E1885),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _PlatformChip(
                            label: 'WhatsApp',
                            icon: Image.asset(
                              "assets/icons/whatsapp.png",
                              height: 20,
                              width: 20,
                              color: selectedPlatforms.contains('whatsapp')
                                  ? Colors.white
                                  : Colors.black,
                              fit: BoxFit.contain,
                            ),
                            isSelected: selectedPlatforms.contains('whatsapp'),
                            onTap: () {
                              setState(() {
                                selectedPlatforms.contains('whatsapp')
                                    ? selectedPlatforms.remove('whatsapp')
                                    : selectedPlatforms.add('whatsapp');
                              });
                            },
                          ),
                          const SizedBox(width: 12),
                          _PlatformChip(
                            label: 'Instagram',
                            icon: Icon(LucideIcons.instagram,
                                color: selectedPlatforms.contains('instagram')
                                    ? Colors.white
                                    : Colors.black),
                            isSelected: selectedPlatforms.contains('instagram'),
                            onTap: () {
                              setState(() {
                                selectedPlatforms.contains('instagram')
                                    ? selectedPlatforms.remove('instagram')
                                    : selectedPlatforms.add('instagram');
                              });
                            },
                          ),
                          const SizedBox(width: 12),
                          _PlatformChip(
                            label: 'Facebook',
                            icon: Icon(LucideIcons.facebook,
                                color: selectedPlatforms.contains('facebook')
                                    ? Colors.white
                                    : Colors.black),
                            isSelected: selectedPlatforms.contains('facebook'),
                            onTap: () {
                              setState(() {
                                selectedPlatforms.contains('facebook')
                                    ? selectedPlatforms.remove('facebook')
                                    : selectedPlatforms.add('facebook');
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    ScheduleSelector(
                      key: _scheduleSelectorKey,
                      initialDate: _scheduledDate,
                      initialTime: _scheduledTime,
                      initialTimezone: _scheduledTimezone,
                      initialRecurringSchedule: _recurringSchedule,
                      onScheduleChange: (date, time, timezone, recurring) {
                        setState(() {
                          _scheduledDate = date;
                          _scheduledTime = time;
                          _scheduledTimezone = timezone;
                          _recurringSchedule = recurring;
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _submitData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF3E1885),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: Text('Submit',
                            style: mont.copyWith(
                                color: Colors.white, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlatformChip extends StatelessWidget {
  final String label;
  final Widget icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlatformChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFF319F43) : Color.fromRGBO(0, 0, 0, 0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Color(0xFF319F43) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 8),
            Text(
              label,
              style: mont.copyWith(
                color: isSelected ? Colors.white : Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
