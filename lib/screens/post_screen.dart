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
import 'package:seo_app/screens/profile_screen.dart';
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


class PostScreen extends StatefulWidget {
  const PostScreen({super.key});

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _highlightController = TextEditingController();
  List<String> selectedPlatforms = [];
  Uint8List? _selectedImageBytes; // Store image as Uint8List

  DateTime? _scheduledDate;
  String? _scheduledTime;
  String? _scheduledTimezone;
  RecurringSchedule? _recurringSchedule;

  final GlobalKey<ScheduleSelectorState> _scheduleSelectorKey = GlobalKey();

  Future<void> _pickImage() async {
    if (kIsWeb) {
      // Use file_picker for web
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null) {
        final fileBytes = result.files.single.bytes;
        if (fileBytes != null) {
          setState(() {
            _selectedImageBytes = fileBytes; // Store the image bytes
          });
        }
      }
    } else {
      // Use image_picker for Android
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        final fileBytes = await pickedFile.readAsBytes();
        setState(() {
          _selectedImageBytes = fileBytes; // Store the image bytes
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
        _scheduledTimezone == null) {
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

      final postData = {
        'title': title,
        'description': description,
        'highlighted_text': highlightedText,
        'platforms': selectedPlatforms,
        'image_base64': imageBase64, // Store the base64 string
        'user_id': currentUser?.uid,
        'user_name': currentUser?.displayName ?? 'Anonymous',
        'created_at': Timestamp.now(),
        'updated_at': Timestamp.now(),
        'scheduled_date': _scheduledDate?.toIso8601String(),
        'scheduled_time': _scheduledTime,
        'scheduled_timezone': _scheduledTimezone,
        'recurring_schedule': _recurringSchedule?.toJson(),
      };

      await FirebaseFirestore.instance
          .collection('post_requests')
          .add(postData);

      Navigator.of(context, rootNavigator: true).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Request submitted successfully!',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.green,
        ),
      );

      _titleController.clear();
      _descriptionController.clear();
      _highlightController.clear();
      setState(() {
        _selectedImageBytes = null; // Clear the image bytes
        selectedPlatforms = [];
        _scheduledDate = null;
        _scheduledTime = null;
        _scheduledTimezone = null;
        _recurringSchedule = null;
      });
      _scheduleSelectorKey.currentState?.resetFields();
    } catch (e) {
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Submission failed: ${e.toString()}',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final String? displayName = user?.displayName;
    final String? photoURL = user?.photoURL;
    return Scaffold(
      backgroundColor: Color(0xFFD3BDFC),
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
              ),
              child: Container(
                height: 90,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
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
                        CircleAvatar(
                          radius: 25,
                          backgroundImage:
                              photoURL != null ? NetworkImage(photoURL) : null,
                          child: photoURL == null
                              ? Icon(Icons.person, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Hi, ${displayName?.split(' ')[0] ?? 'User'}!',
                          style: mont.copyWith(
                            fontSize: 18,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(SolarIconsOutline.heart),
                          onPressed: () {},
                          color: Colors.black,
                        ),
                        IconButton(
                          icon: Icon(SolarIconsOutline.settings),
                          onPressed: () {
                            // Navigate to ProfileScreen
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProfileScreen(
                                  userId:
                                      FirebaseAuth.instance.currentUser!.uid,
                                ),
                              ),
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
                      'Reference Images/Videos',
                      style: mont.copyWith(
                          color: Color(0xFF000000),
                          fontSize: 14,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickImage, // Trigger image picker on tap
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
                                'Add Media (png, jpg, mp4)',
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

                    // Display the selected image (if any)
                    if (_selectedImageBytes != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            _selectedImageBytes!, // Use Uint8List to display the image
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
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

// Platform Chip Widget
class _PlatformChip extends StatelessWidget {
  final String label;
  final Widget icon; // Change from IconData to Widget
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
            color: isSelected
                ? Color(0xFF319F43)
                : Colors.transparent, // Border color changes on selection
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon, // Supports both Image and Icon
            const SizedBox(width: 8), // Space between icon and text
            Text(
              label,
              style: mont.copyWith(
                color: isSelected
                    ? Colors.white
                    : Colors.black, // Text color changes on selection
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
