import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:seo_app/screens/main_screen.dart';
import 'package:seo_app/screens/profile_list_screen.dart';
import 'package:seo_app/screens/settings_screen.dart';
import 'package:seo_app/theme/text_style.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recurring_schedule.dart';
import '../widgets/schedule_selector.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:seo_app/services/notification_service.dart';

import 'package:cloud_functions/cloud_functions.dart';

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
  bool _isSeoManager = false;
  bool _isLoadingProfiles = true;
  String _profileError = '';

  final GlobalKey<ScheduleSelectorState> _scheduleSelectorKey = GlobalKey();

  // Auto-save related variables
  Timer? _debounceTimer;
  bool _isAutoSaving = false;
  DateTime? _lastSaveTime;
  late SharedPreferences _prefs;
  String get _autoSaveKey =>
      'post_autosave_${FirebaseAuth.instance.currentUser?.uid ?? 'anonymous'}_${widget.existingData?['id'] ?? 'new'}';

  @override
  void initState() {
    super.initState();
    _initializePreferences();
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
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingProfiles = false);
      return;
    }

    try {
      final roleDoc = await FirebaseFirestore.instance
          .collection('roles')
          .doc(user.uid)
          .get();

      final role = roleDoc.data()?['role'] as String?;

      // Make the check case-insensitive
      final cleanRole = role?.trim().toLowerCase() ?? '';

      if (mounted) {
        setState(() {
          _isDesignerOrManager = cleanRole == 'graphic designer' ||
              cleanRole == 'seo.credit manager';
          _isSeoManager = cleanRole == 'seo.credit manager';
        });
      }

      // Always fetch user profiles directly
      await _fetchUserProfiles();
    } catch (e) {
      print("Error checking user role: $e");
      if (mounted) setState(() => _isLoadingProfiles = false);
    }
  }

  // Modify _fetchUserProfiles to handle SEO Manager differently
  Future<void> _fetchUserProfiles() async {
    if (mounted)
      setState(() {
        _isLoadingProfiles = true;
        _profileError = '';
      });

    try {
      // When editing a post, fetch the original profile information
      if (widget.existingData != null &&
          widget.existingData!['profile_id'] != null) {
        final profilePath = widget.existingData!['profile_id'].split('/');
        if (profilePath.length >= 4) {
          try {
            final profileDoc = await FirebaseFirestore.instance
                .collection(profilePath[0])
                .doc(profilePath[1])
                .collection(profilePath[2])
                .doc(profilePath[3])
                .get();

            if (mounted)
              setState(() {
                _userProfiles = [
                  {
                    'id': widget.existingData!['profile_id'],
                    'name': profileDoc.exists
                        ? (profileDoc.data()?['businessDetails']['name'] ??
                            'Original Profile')
                        : 'Original Profile'
                  }
                ];
                _selectedProfileId = widget.existingData!['profile_id'];
              });
          } catch (e) {
            print('Error fetching original profile: $e');
            // Fallback to using the stored profile name
            if (mounted)
              setState(() {
                _userProfiles = [
                  {
                    'id': widget.existingData!['profile_id'],
                    'name': widget.existingData!['profile_name'] ??
                        'Original Profile'
                  }
                ];
                _selectedProfileId = widget.existingData!['profile_id'];
              });
          }
        }
      }
      // SEO Manager creating a new post - fetch ALL business profiles
      else if (_isSeoManager) {
        print(
            "--- Calling Cloud Function 'getAllBusinessProfiles' as Manager ---");

        final HttpsCallable callable =
            FirebaseFunctions.instance.httpsCallable('getAllBusinessProfiles');
        final result = await callable.call();

        print("--- Cloud Function Response: ${result.data} ---");

        // Fix the type casting issue
        final responseData = result.data as Map<String, dynamic>;
        final List<dynamic> profilesFromServer =
            responseData['profiles'] as List<dynamic>;

        print(
            "--- Profiles from server count: ${profilesFromServer.length} ---");

        // Convert to proper type
        final List<Map<String, dynamic>> profiles =
            profilesFromServer.map((profile) {
          print("--- Processing profile: $profile ---");
          return Map<String, dynamic>.from(profile as Map<Object?, Object?>);
        }).toList();

        print("--- Final profiles count: ${profiles.length} ---");

        if (mounted) {
          setState(() {
            _userProfiles = profiles;
          });
        }

        // If no profiles found, let's add a helpful message
        if (profiles.isEmpty) {
          if (mounted) {
            setState(() {
              _profileError =
                  'No business profiles found. Please ensure customers have created their business profiles.';
            });
          }
        }
      }
      // Standard user creating a new post
      else {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;
        final querySnapshot = await FirebaseFirestore.instance
            .collection('profiles')
            .doc(user.uid)
            .collection('profiles')
            .get();
        if (mounted) {
          setState(() {
            _userProfiles = querySnapshot.docs.map((doc) {
              return {
                'id': 'profiles/${user.uid}/profiles/${doc.id}',
                'name':
                    doc.data()['businessDetails']['name'] ?? 'Unnamed Profile',
              };
            }).toList();
          });
        }
      }
    } on FirebaseFunctionsException catch (e) {
      print('--- CLOUD FUNCTION ERROR: ${e.message} ---');
      if (mounted)
        setState(() => _profileError =
            e.message ?? 'Failed to load profiles from server.');
    } catch (e) {
      print('--- FATAL ERROR in _fetchUserProfiles: $e ---');
      if (mounted)
        setState(() =>
            _profileError = 'An unexpected error occurred: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoadingProfiles = false);
    }
  }

  // --- NO CHANGES to the methods below this line ---
  // [ ... ALL OTHER METHODS LIKE _pickImage, _submitData, build, etc. remain the same ... ]
  // The 'build' method you provided in the previous step is still correct.

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
          _triggerAutoSave();
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
        _triggerAutoSave();
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
          _triggerAutoSave();
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
        _triggerAutoSave();
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

  Future<String> _getCustomerNameFromProfile(String profileId) async {
    try {
      // Extract customer ID from profile path: profiles/{userId}/profiles/{profileId}
      final profilePath = profileId.split('/');
      if (profilePath.length >= 2) {
        final customerId = profilePath[1];

        // Get customer's display name from users collection
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(customerId)
            .get();

        if (userDoc.exists) {
          return userDoc.data()?['displayName'] ?? 'Unknown Customer';
        }
      }
    } catch (e) {
      print('Error getting customer name: $e');
    }
    return 'Unknown Customer';
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
      if (_isDesignerOrManager && _selectedFlyerImageBytes != null) {
        flyerBase64 = await _convertImageToBase64(_selectedFlyerImageBytes!);
      }

      final postData = {
        'title': title,
        'title_lowercase': title.toLowerCase(),
        'description': description,
        'highlighted_text': highlightedText,
        'platforms': selectedPlatforms,
        'user_id': widget.existingData?['user_id'] ??
            (_isSeoManager && _selectedProfileId != null
                ? _selectedProfileId!
                    .split('/')[1] // Extract customer ID from profile path
                : currentUser?.uid),
        'user_name': widget.existingData?['user_name'] ??
            (_isSeoManager && _selectedProfileId != null
                ? await _getCustomerNameFromProfile(_selectedProfileId!)
                : currentUser?.displayName ?? 'Anonymous'),
        'created_by': widget.existingData?['created_by'] ??
            currentUser?.uid, // Track who created the post
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
      };

      bool flyerChanged = false;
      String? originalFlyerBase64 = widget.existingData?['flyer_base64'];
      if (widget.existingData != null && widget.existingData!['id'] != null) {
        if (flyerBase64 != null && flyerBase64 != originalFlyerBase64) {
          flyerChanged = true;
        } else if (flyerBase64 == null && originalFlyerBase64 != null) {
          flyerChanged = true;
        }
      }

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

      if (widget.existingData != null && widget.existingData!['id'] != null) {
        if (isDesignerEditingCustomerPost && flyerChanged) {
          postData['updated_flyer_base64'] = flyerBase64;
          postData['flyer_approval_status'] = 'pending';
          postData['last_updated_by'] = currentUser!.uid;
        } else {
          postData['flyer_base64'] = flyerBase64;
          postData['updated_flyer_base64'] = null;
          postData['flyer_approval_status'] = null;
        }
        postData['image_base64'] = imageBase64;
        await FirebaseFirestore.instance
            .collection('post_requests')
            .doc(widget.existingData!['id'])
            .update(postData);
      } else {
        postData['image_base64'] = imageBase64;
        postData['flyer_base64'] = flyerBase64;
        await FirebaseFirestore.instance
            .collection('post_requests')
            .add(postData);
      }

      if (isDesignerEditingCustomerPost &&
          flyerChanged &&
          widget.existingData != null) {
        final originalPosterId = widget.existingData!['user_id'];
        final originalPosterName =
            widget.existingData!['user_name'] ?? 'Anonymous';
        final chatId = _generateChatId(currentUser!.uid, originalPosterId);

        // Check if conversation exists, create if it doesn't
        final conversationDoc = await FirebaseFirestore.instance
            .collection('conversations')
            .doc(chatId)
            .get();

        final batch = FirebaseFirestore.instance.batch();

        // Create message
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

        // Create or update conversation document
        if (!conversationDoc.exists) {
          // Create new conversation document
          batch.set(
            FirebaseFirestore.instance.collection('conversations').doc(chatId),
            {
              'participants': [currentUser.uid, originalPosterId],
              'createdAt': FieldValue.serverTimestamp(),
              'lastMessage': 'Updated flyer for post: "$title"',
              'lastMessageTime': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
              'lastActive': {
                currentUser.uid: FieldValue.serverTimestamp(),
                originalPosterId: FieldValue.serverTimestamp(),
              },
            },
          );
        } else {
          // Update existing conversation document
          batch.update(
            FirebaseFirestore.instance.collection('conversations').doc(chatId),
            {
              'lastMessage': 'Updated flyer for post: "$title"',
              'lastMessageTime': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
          );
        }

        // Update user conversations
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

        // Send notification
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

        // Commit all changes
        await batch.commit();
      }

      // Clear auto-saved data after successful submission
      await _clearAutoSavedData();

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
            'Submission failed: ${e.toString()}',
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

  // Auto-save functionality
  Future<void> _initializePreferences() async {
    _prefs = await SharedPreferences.getInstance();

    // If not editing, try to load auto-saved data
    if (widget.existingData == null) {
      await _loadAutoSavedData();
    }

    // Setup listeners for auto-save
    _setupAutoSaveListeners();
  }

  void _setupAutoSaveListeners() {
    _titleController.addListener(_triggerAutoSave);
    _descriptionController.addListener(_triggerAutoSave);
    _highlightController.addListener(_triggerAutoSave);
    _referenceLinkController.addListener(_triggerAutoSave);
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
        'platforms': selectedPlatforms,
        'image_base64': _selectedImageBytes != null
            ? base64Encode(_selectedImageBytes!)
            : null,
        'flyer_base64': _selectedFlyerImageBytes != null
            ? base64Encode(_selectedFlyerImageBytes!)
            : null,
        'scheduled_date': _scheduledDate?.toIso8601String(),
        'scheduled_time': _scheduledTime,
        'scheduled_timezone': _scheduledTimezone,
        'recurring_schedule': _recurringSchedule?.toJson(),
        'selected_profile_id': _selectedProfileId,
        'reference_link': _referenceLinkController.text,
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
        selectedPlatforms = List<String>.from(autoSavedData['platforms'] ?? []);
        _referenceLinkController.text = autoSavedData['reference_link'] ?? '';

        // Load image data
        if (autoSavedData['image_base64'] != null) {
          _selectedImageBytes = base64Decode(autoSavedData['image_base64']);
        }
        if (autoSavedData['flyer_base64'] != null) {
          _selectedFlyerImageBytes =
              base64Decode(autoSavedData['flyer_base64']);
        }

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

        // Load profile selection
        _selectedProfileId = autoSavedData['selected_profile_id'];

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

  @override
  void dispose() {
    // Cancel auto-save timer
    _debounceTimer?.cancel();

    // Dispose controllers
    _titleController.dispose();
    _descriptionController.dispose();
    _highlightController.dispose();
    _referenceLinkController.dispose();

    super.dispose();
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
                        // IconButton(
                        //   icon: const Icon(SolarIconsOutline.heart),
                        //   onPressed: () {},
                        //   color: Colors.black,
                        // ),
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
                            Row(
                              children: [
                                Text(
                                  'Fill the details and see the magic',
                                  style: mont.copyWith(
                                      color: Color(0xFF3E1885),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w300),
                                ),
                                // if (_isAutoSaving || _lastSaveTime != null) ...[
                                //   SizedBox(width: 8),
                                //   _buildAutoSaveIndicator(),
                                // ],
                              ],
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
                    // Remove all customer selection UI - SEO Managers now see all profiles directly

                    // Existing Profile Selection
                    if (_isLoadingProfiles)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32.0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_profileError.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red),
                        ),
                        child: Text(
                          _profileError,
                          style: mont.copyWith(color: Colors.red.shade900),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else if (_userProfiles.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.existingData != null
                                ? 'Business Profile (Read Only)'
                                : 'Business Profile',
                            style: mont.copyWith(
                              color: Color(0xFF000000),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (widget.existingData != null)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: Colors.grey[300]!, width: 1.5),
                              ),
                              child: Text(
                                _userProfiles.first['name'],
                                style: mont.copyWith(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            )
                          else
                            DropdownButtonFormField<String>(
                              value: _selectedProfileId,
                              isExpanded: true,
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
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedProfileId = value;
                                });
                                _triggerAutoSave();
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
                              'No profiles found. Please create a profile first.',
                              style: mont.copyWith(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 16),
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
                              _triggerAutoSave();
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
                              _triggerAutoSave();
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
                              _triggerAutoSave();
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
                        _triggerAutoSave();
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
