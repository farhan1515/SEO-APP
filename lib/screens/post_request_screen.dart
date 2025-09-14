import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:seo_app/models/recurring_schedule.dart';
import 'package:seo_app/theme/text_style.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_icons/solar_icons.dart';

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

  final GlobalKey<ScheduleSelectorState> _scheduleSelectorKey = GlobalKey();

  // Auto-save related variables
  Timer? _debounceTimer;
  bool _isAutoSaving = false;
  DateTime? _lastSaveTime;
  late SharedPreferences _prefs;
  String get _autoSaveKey =>
      'post_request_autosave_${FirebaseAuth.instance.currentUser?.uid ?? 'anonymous'}_${widget.postId ?? 'new'}';

  @override
  void initState() {
    super.initState();
    _isEditing = widget.postId != null;
    _initializePreferences();

    if (_isEditing && widget.existingData != null) {
      print('Existing Data: ${widget.existingData}'); // Debug print
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
      _triggerAutoSave();
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

  // Auto-save functionality
  Future<void> _initializePreferences() async {
    _prefs = await SharedPreferences.getInstance();

    // If not editing, try to load auto-saved data
    if (!_isEditing) {
      await _loadAutoSavedData();
    }

    // Setup listeners for auto-save
    _setupAutoSaveListeners();
  }

  void _setupAutoSaveListeners() {
    _titleController.addListener(_triggerAutoSave);
    _descriptionController.addListener(_triggerAutoSave);
    _highlightController.addListener(_triggerAutoSave);
  }

  void _triggerAutoSave() {
    // Cancel any existing timer
    _debounceTimer?.cancel();

    // Set up a new timer with 2-second delay
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      _autoSaveFormData();
    });
  }

  Future<void> _autoSaveFormData() async {
    if (!mounted) return;

    setState(() {
      _isAutoSaving = true;
    });

    try {
      final autoSaveData = {
        'title': _titleController.text,
        'description': _descriptionController.text,
        'highlighted_text': _highlightController.text,
        'platforms': _selectedPlatforms,
        'image_base64': _existingImageBase64,
        'scheduled_date': _scheduledDate?.toIso8601String(),
        'scheduled_time': _scheduledTime,
        'scheduled_timezone': _scheduledTimezone,
        'recurring_schedule': _recurringSchedule?.toJson(),
        'lastSaved': DateTime.now().toIso8601String(),
      };

      await _prefs.setString(_autoSaveKey, jsonEncode(autoSaveData));

      if (mounted) {
        setState(() {
          _isAutoSaving = false;
          _lastSaveTime = DateTime.now();
        });
      }
    } catch (e) {
      print('Error auto-saving: $e');
      if (mounted) {
        setState(() {
          _isAutoSaving = false;
        });
      }
    }
  }

  Future<void> _loadAutoSavedData() async {
    try {
      final autoSavedJson = _prefs.getString(_autoSaveKey);
      if (autoSavedJson != null) {
        final autoSavedData = jsonDecode(autoSavedJson) as Map<String, dynamic>;

        // Load form data
        _titleController.text = autoSavedData['title'] ?? '';
        _descriptionController.text = autoSavedData['description'] ?? '';
        _highlightController.text = autoSavedData['highlighted_text'] ?? '';
        _selectedPlatforms =
            List<String>.from(autoSavedData['platforms'] ?? []);
        _existingImageBase64 = autoSavedData['image_base64'];

        // Load scheduling data
        if (autoSavedData['scheduled_date'] != null) {
          _scheduledDate = DateTime.parse(autoSavedData['scheduled_date']);
        }
        _scheduledTime = autoSavedData['scheduled_time'];
        _scheduledTimezone = autoSavedData['scheduled_timezone'];
        if (autoSavedData['recurring_schedule'] != null) {
          _recurringSchedule = RecurringSchedule.fromJson(
              Map<String, dynamic>.from(autoSavedData['recurring_schedule']));
        }

        // Parse last saved time
        final lastSavedString = autoSavedData['lastSaved'] as String?;
        if (lastSavedString != null) {
          _lastSaveTime = DateTime.parse(lastSavedString);
        }

        // Update UI
        if (mounted) {
          setState(() {});
          // Show snackbar about restored data
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(SolarIconsOutline.clockCircle,
                          color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Previous progress restored',
                        style: mont.copyWith(fontSize: 14, color: Colors.white),
                      ),
                    ],
                  ),
                  backgroundColor: Color(0xFF5664F5),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  duration: Duration(seconds: 3),
                ),
              );
            }
          });
        }
      }
    } catch (e) {
      print('Error loading auto-saved data: $e');
    }
  }

  Future<void> _clearAutoSavedData() async {
    try {
      await _prefs.remove(_autoSaveKey);
      _lastSaveTime = null;
    } catch (e) {
      print('Error clearing auto-saved data: $e');
    }
  }

  Widget _buildAutoSaveIndicator() {
    final isSmallScreen = MediaQuery.of(context).size.width < 400;

    if (_isAutoSaving) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: isSmallScreen ? 10 : 12,
            height: isSmallScreen ? 10 : 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5664F5)),
            ),
          ),
          SizedBox(width: isSmallScreen ? 3 : 4),
          Text(
            'Saving...',
            style: mont.copyWith(
              color: Color(0xFF5664F5),
              fontSize: isSmallScreen ? 10 : 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    } else if (_lastSaveTime != null) {
      final now = DateTime.now();
      final difference = now.difference(_lastSaveTime!);
      String timeText;

      if (difference.inSeconds < 60) {
        timeText = isSmallScreen ? 'Saved now' : 'Saved just now';
      } else if (difference.inMinutes < 60) {
        timeText = 'Saved ${difference.inMinutes}m ago';
      } else {
        timeText = 'Saved ${difference.inHours}h ago';
      }

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            SolarIconsOutline.checkCircle,
            size: isSmallScreen ? 10 : 12,
            color: Colors.green,
          ),
          SizedBox(width: isSmallScreen ? 3 : 4),
          Text(
            timeText,
            style: mont.copyWith(
              color: Colors.green,
              fontSize: isSmallScreen ? 10 : 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }
    return SizedBox.shrink();
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

      // Clear auto-saved data after successful submission
      await _clearAutoSavedData();

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
        _scheduleSelectorKey.currentState?.resetFields();
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
  void dispose() {
    // Cancel auto-save timer
    _debounceTimer?.cancel();

    // Dispose controllers
    _titleController.dispose();
    _descriptionController.dispose();
    _highlightController.dispose();

    super.dispose();
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEditing ? 'Edit Post' : 'Post Request',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_isAutoSaving || _lastSaveTime != null) ...[
                            SizedBox(height: 4),
                            _buildAutoSaveIndicator(),
                          ],
                        ],
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
                      _triggerAutoSave();
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
                      _triggerAutoSave();
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
                      _triggerAutoSave();
                    }),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Schedule Selector

              const SizedBox(height: 16),
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
                  _triggerAutoSave();
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
