import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:seo_app/models/recurring_schedule.dart';
import 'package:seo_app/theme/text_style.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image/image.dart' as img;

import 'package:intl/date_symbol_data_local.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

import '../widgets/schedule_selector.dart';

class PostRequestScreen extends StatefulWidget {
  final String? postId;
  final Map<String, dynamic>? existingData;
  const PostRequestScreen({
    super.key,
    this.postId,
    this.existingData,
  });

  @override
  State<PostRequestScreen> createState() => _PostRequestScreenState();
}

class _PostRequestScreenState extends State<PostRequestScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _highlightController = TextEditingController();
  List<String> _selectedPlatforms = [];
  File? _selectedImage;
  String? _existingImageBase64;
  bool _isEditing = false;

  DateTime? _scheduledDate;
  String? _scheduledTime;
  String? _scheduledTimezone;
  RecurringSchedule? _recurringSchedule;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.postId != null;

    if (_isEditing && widget.existingData != null) {
      _titleController.text = widget.existingData!['title'] ?? '';
      _descriptionController.text = widget.existingData!['description'] ?? '';
      _highlightController.text =
          widget.existingData!['highlighted_text'] ?? '';
      _selectedPlatforms =
          List<String>.from(widget.existingData!['platforms'] ?? []);
      _existingImageBase64 = widget.existingData!['image_base64'];

      if (widget.existingData!['scheduled_date'] != null) {
        _scheduledDate = DateTime.parse(widget.existingData!['scheduled_date']);
      }
      _scheduledTime = widget.existingData!['scheduled_time'];
      _scheduledTimezone = widget.existingData!['scheduled_timezone'];
      if (widget.existingData!['recurring_schedule'] != null) {
        _recurringSchedule = RecurringSchedule.fromJson(
            Map<String, dynamic>.from(
                widget.existingData!['recurring_schedule']));
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage(File image) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('post_images')
          .child(DateTime.now().toIso8601String() + '.jpg');
      await ref.putFile(image);
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  Future<String?> _convertImageToBase64(File image) async {
    try {
      // Read the image file
      List<int> imageBytes = await image.readAsBytes();

      // Decode the image
      img.Image? originalImage =
          img.decodeImage(Uint8List.fromList(imageBytes));

      if (originalImage == null) {
        print('Failed to decode image');
        return null;
      }

      // Resize the image to a maximum width/height of 800 pixels while maintaining aspect ratio
      img.Image resizedImage = img.copyResize(originalImage,
          width: 800, height: 800, interpolation: img.Interpolation.average);

      // Compress the image with reduced quality
      List<int> compressedBytes = img.encodeJpg(resizedImage, quality: 70);

      // Convert to base64
      return base64Encode(compressedBytes);
    } catch (e) {
      print('Error converting image to Base64: $e');
      return null;
    }
  }

  Future<void> _submitData() async {
    // Validate inputs
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final highlightedText = _highlightController.text.trim();
    final currentUser = FirebaseAuth.instance.currentUser;

    // Input validation
    if (title.isEmpty ||
        description.isEmpty ||
        highlightedText.isEmpty ||
        _selectedPlatforms.isEmpty ||
        _scheduledDate == null || // Add schedule validation
        _scheduledTime == null ||
        _scheduledTimezone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields.')),
      );
      return;
    }

    // Show loading indicator
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
      // Handle image
      String? imageBase64 = _existingImageBase64;

      // If new image is selected, process it
      if (_selectedImage != null) {
        imageBase64 = await _convertImageToBase64(_selectedImage!);
      }

      // Prepare post data
      final postData = {
        'title': title,
        'description': description,
        'highlighted_text': highlightedText,
        'platforms': _selectedPlatforms,
        'image_base64': imageBase64,
        'user_id': currentUser?.uid,
        'user_name': currentUser?.displayName ?? 'Anonymous',
        'created_at':
            _isEditing ? widget.existingData!['created_at'] : Timestamp.now(),
        'updated_at': Timestamp.now(),

        // Add scheduling data
        'scheduled_date': _scheduledDate?.toIso8601String(),
        'scheduled_time': _scheduledTime,
        'scheduled_timezone': _scheduledTimezone,
        'recurring_schedule': _recurringSchedule?.toJson(),
      };

      // Handle Firestore operation
      if (_isEditing) {
        // Update existing document
        await FirebaseFirestore.instance
            .collection('post_requests')
            .doc(widget.postId)
            .update(postData);
      } else {
        // Create new document
        await FirebaseFirestore.instance
            .collection('post_requests')
            .add(postData);
      }

      // Close loading dialog
      Navigator.of(context, rootNavigator: true).pop();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Post updated successfully!'
                : 'Request submitted successfully!',
            style: texts.copyWith(color: Colors.white),
          ),
          backgroundColor: Colors.green,
        ),
      );

      // Log success
      print("Data ${_isEditing ? 'updated' : 'submitted'} successfully:");
      print(postData);

      // Clear form if it's a new post
      if (!_isEditing) {
        _titleController.clear();
        _descriptionController.clear();
        _highlightController.clear();
        setState(() {
          _selectedImage = null;
          _selectedPlatforms = [];
          _existingImageBase64 = null;
          _scheduledDate = null;
          _scheduledTime = null;
          _scheduledTimezone = null;
          _recurringSchedule = null;
        });
      } else {
        // If editing, pop back to previous screen
        Navigator.of(context).pop();
      }
    } catch (e) {
      // Close loading dialog
      Navigator.of(context, rootNavigator: true).pop();

      // Log the error
      print('${_isEditing ? 'Update' : 'Submission'} Error: $e');

      // Show detailed error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_isEditing ? 'Update' : 'Submission'} failed: ${e.toString()}',
            style: texts.copyWith(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFc9dee7),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        child: Image.asset(
                          'assets/icons/horn.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _isEditing ? 'Edit Post' : 'Post Request',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const CircleAvatar(
                    backgroundColor: Color(0xFF5664f5),
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              Text(
                'Submit Your Requirement',
                style: lexand,
              ),

              const SizedBox(height: 24),

              // Post Title
              Text(
                'Post Title',
                style: lexand.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w200,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'Enter title',
                  hintStyle: lexand.copyWith(
                      fontSize: 14, color: Colors.grey.shade500),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
              ),

              const SizedBox(height: 16),

              // Description
              Text(
                'Description',
                style: lexand.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w200,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Enter detailed description',
                  hintStyle: lexand.copyWith(
                      fontSize: 14, color: Colors.grey.shade500),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
              ),

              const SizedBox(height: 16),

              // What to be highlighted
              Text(
                'What to be highlighted',
                style: lexand.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w200,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _highlightController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Enter detailed description',
                  hintStyle: lexand.copyWith(
                      fontSize: 14, color: Colors.grey.shade500),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
              ),

              const SizedBox(height: 16),

              // Reference Image/Link
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Reference Image/Link',
                    style: lexand.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w200,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _pickImage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0000ff),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Add',
                      style: texts.copyWith(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
              if (_selectedImage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _selectedImage!,
                      // height: 100,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else if (_existingImageBase64 != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      base64Decode(_existingImageBase64!),
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // Platforms
              Text(
                'Platforms',
                style: lexand.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _PlatformChip(
                    label: 'Facebook',
                    isSelected: _selectedPlatforms.contains('facebook'),
                    onTap: () => setState(() {
                      if (_selectedPlatforms.contains('facebook')) {
                        _selectedPlatforms.remove('facebook');
                      } else {
                        _selectedPlatforms.add('facebook');
                      }
                    }),
                  ),
                  const SizedBox(width: 12),
                  _PlatformChip(
                    label: 'Instagram',
                    isSelected: _selectedPlatforms.contains('instagram'),
                    onTap: () => setState(() {
                      if (_selectedPlatforms.contains('instagram')) {
                        _selectedPlatforms.remove('instagram');
                      } else {
                        _selectedPlatforms.add('instagram');
                      }
                    }),
                  ),
                  const SizedBox(width: 12),
                  _PlatformChip(
                    label: 'WhatsApp',
                    isSelected: _selectedPlatforms.contains('whatsapp'),
                    onTap: () => setState(() {
                      if (_selectedPlatforms.contains('whatsapp')) {
                        _selectedPlatforms.remove('whatsapp');
                      } else {
                        _selectedPlatforms.add('whatsapp');
                      }
                    }),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Schedule Selector

              const SizedBox(height: 16),
              ScheduleSelector(
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
              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _submitData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Text(
                    _isEditing ? 'Update' : 'Submit',
                    style: lexand.copyWith(fontSize: 18, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlatformChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlatformChip({
    required this.label,
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
          color: isSelected ? const Color(0xFF0000ff) : Colors.black,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: texts.copyWith(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
