import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:seo_app/screens/main_screen.dart';
import 'package:seo_app/screens/settings_screen.dart';
import 'package:seo_app/theme/text_style.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';

class ProfileScreen extends StatefulWidget {
  final String userId;
  final String? profileId;
  const ProfileScreen({
    super.key,
    required this.userId,
    this.profileId,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final _businessNameController = TextEditingController();
  final _businessTypeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _zipController = TextEditingController();
  final _websiteController = TextEditingController();
  final _gstController = TextEditingController();

  // Social media controllers
  final _facebookController = TextEditingController();
  final _instagramController = TextEditingController();
  final _googleBusinessController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _telegramController = TextEditingController();

  // Contact controllers
  List<Contact> contacts = [Contact()];

  String? selectedCountry;
  String? selectedTimeZone;

  // Auto-save related variables
  Timer? _debounceTimer;
  bool _isAutoSaving = false;
  DateTime? _lastSaveTime;
  late SharedPreferences _prefs;
  String get _autoSaveKey =>
      'profile_autosave_${widget.userId}_${widget.profileId ?? 'new'}';

  void _updateProgress() {
    // This method can be used for future progress tracking if needed
    setState(() {
      // Trigger UI update
    });
  }

  // Auto-save functionality
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
        'currentStep': _currentStep,
        'businessDetails': {
          'name': _businessNameController.text,
          'type': _businessTypeController.text,
          'phone': _phoneController.text,
          'address': _addressController.text,
          'country': selectedCountry,
          'zip': _zipController.text,
          'timeZone': selectedTimeZone,
          'website': _websiteController.text,
          'gstNumber': _gstController.text,
        },
        'socialMedia': {
          'facebook': _facebookController.text,
          'instagram': _instagramController.text,
          'googleBusiness': _googleBusinessController.text,
          'whatsapp': _whatsappController.text,
          'telegram': _telegramController.text,
        },
        'contacts': contacts
            .map((contact) => {
                  'name': contact.name,
                  'email': contact.email,
                  'isPrimary': contact.isPrimary,
                  'receiveAlerts': contact.receiveAlerts,
                  'emailNotifications': contact.emailNotifications,
                })
            .toList(),
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

        // Load current step
        _currentStep = autoSavedData['currentStep'] ?? 0;

        // Load business details
        final businessDetails =
            autoSavedData['businessDetails'] as Map<String, dynamic>? ?? {};
        _businessNameController.text = businessDetails['name'] ?? '';
        _businessTypeController.text = businessDetails['type'] ?? '';
        _phoneController.text = businessDetails['phone'] ?? '';
        _addressController.text = businessDetails['address'] ?? '';
        selectedCountry = businessDetails['country'];
        _zipController.text = businessDetails['zip'] ?? '';
        selectedTimeZone = businessDetails['timeZone'];
        _websiteController.text = businessDetails['website'] ?? '';
        _gstController.text = businessDetails['gstNumber'] ?? '';

        // Load social media
        final socialMedia =
            autoSavedData['socialMedia'] as Map<String, dynamic>? ?? {};
        _facebookController.text = socialMedia['facebook'] ?? '';
        _instagramController.text = socialMedia['instagram'] ?? '';
        _googleBusinessController.text = socialMedia['googleBusiness'] ?? '';
        _whatsappController.text = socialMedia['whatsapp'] ?? '';
        _telegramController.text = socialMedia['telegram'] ?? '';

        // Load contacts
        final contactsData = autoSavedData['contacts'] as List<dynamic>? ?? [];
        if (contactsData.isNotEmpty) {
          contacts = contactsData.map((contactData) {
            final contact = Contact();
            contact.name = contactData['name'] ?? '';
            contact.email = contactData['email'] ?? '';
            contact.isPrimary = contactData['isPrimary'] ?? false;
            contact.receiveAlerts = contactData['receiveAlerts'] ?? false;
            contact.emailNotifications =
                contactData['emailNotifications'] ?? false;
            contact.nameController = TextEditingController(text: contact.name);
            contact.emailController =
                TextEditingController(text: contact.email);
            return contact;
          }).toList();
        }

        // Parse last saved time
        final lastSavedString = autoSavedData['lastSaved'] as String?;
        if (lastSavedString != null) {
          _lastSaveTime = DateTime.parse(lastSavedString);
        }

        // Update progress and UI
        _updateProgress();

        // Show snackbar about restored data
        if (mounted) {
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

  Future<void> _fetchProfileData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('profiles')
          .doc(widget.userId)
          .collection('profiles')
          .doc(widget.profileId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;

        // Business Details
        _businessNameController.text = data['businessDetails']['name'] ?? '';
        _businessTypeController.text = data['businessDetails']['type'] ?? '';
        _phoneController.text = data['businessDetails']['phone'] ?? '';
        _addressController.text = data['businessDetails']['address'] ?? '';
        selectedCountry = data['businessDetails']['country'];
        _zipController.text = data['businessDetails']['zip'] ?? '';
        selectedTimeZone = data['businessDetails']['timeZone'];
        _websiteController.text = data['businessDetails']['website'] ?? '';
        _gstController.text = data['businessDetails']['gstNumber'] ?? '';

        // Social Media
        _facebookController.text = data['socialMedia']['facebook'] ?? '';
        _instagramController.text = data['socialMedia']['instagram'] ?? '';
        _googleBusinessController.text =
            data['socialMedia']['googleBusiness'] ?? '';
        _whatsappController.text = data['socialMedia']['whatsapp'] ?? '';
        _telegramController.text = data['socialMedia']['telegram'] ?? '';

        // Contacts
        final contactsData = data['contacts'] as List<dynamic>? ?? [];
        contacts = contactsData
            .map((contact) => Contact()
              ..name = contact['name'] ?? ''
              ..email = contact['email'] ?? ''
              ..isPrimary = contact['isPrimary'] ?? false
              ..receiveAlerts = contact['receiveAlerts'] ?? false
              ..emailNotifications = contact['emailNotifications'] ?? false
              ..nameController =
                  TextEditingController(text: contact['name'] ?? '')
              ..emailController =
                  TextEditingController(text: contact['email'] ?? ''))
            .toList();

        // Update progress percentage
        _updateProgress();

        // Force UI to rebuild
        setState(() {});
      }
    } catch (e) {
      print('Error fetching profile data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching profile data: $e')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _initializePreferences();
  }

  Future<void> _initializePreferences() async {
    _prefs = await SharedPreferences.getInstance();

    // If editing existing profile, fetch from Firebase first
    if (widget.profileId != null) {
      await _fetchProfileData();
    } else {
      // For new profiles, try to load auto-saved data
      await _loadAutoSavedData();
    }

    // Setup listeners for all controllers to trigger auto-save
    _setupAutoSaveListeners();
  }

  void _setupAutoSaveListeners() {
    // Business details listeners
    _businessNameController.addListener(_triggerAutoSave);
    _businessTypeController.addListener(_triggerAutoSave);
    _phoneController.addListener(_triggerAutoSave);
    _addressController.addListener(_triggerAutoSave);
    _zipController.addListener(_triggerAutoSave);
    _websiteController.addListener(_triggerAutoSave);
    _gstController.addListener(_triggerAutoSave);

    // Social media listeners
    _facebookController.addListener(_triggerAutoSave);
    _instagramController.addListener(_triggerAutoSave);
    _googleBusinessController.addListener(_triggerAutoSave);
    _whatsappController.addListener(_triggerAutoSave);
    _telegramController.addListener(_triggerAutoSave);

    // Contact controllers will be set up when contacts are created/loaded
    _setupContactListeners();
  }

  void _setupContactListeners() {
    for (final contact in contacts) {
      contact.nameController
          .removeListener(_triggerAutoSave); // Remove if exists
      contact.emailController
          .removeListener(_triggerAutoSave); // Remove if exists
      contact.nameController.addListener(_triggerAutoSave);
      contact.emailController.addListener(_triggerAutoSave);
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

    // Dispose business details controllers
    _businessNameController.dispose();
    _businessTypeController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _zipController.dispose();
    _websiteController.dispose();
    _gstController.dispose();

    // Dispose social media controllers
    _facebookController.dispose();
    _instagramController.dispose();
    _googleBusinessController.dispose();
    _whatsappController.dispose();
    _telegramController.dispose();

    // Dispose contact controllers
    for (final contact in contacts) {
      contact.nameController.dispose();
      contact.emailController.dispose();
    }

    super.dispose();
  }

  void _nextStep() {
    // Check if the current step is 0 (Business Details step)
    if (_currentStep == 0) {
      // Validate mandatory fields
      if (_businessNameController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Business Name is required')),
        );
        return; // Stop further execution
      }
      if (_businessTypeController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Type of Business is required')),
        );
        return; // Stop further execution
      }
      if (_phoneController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Business Phone Number is required')),
        );
        return; // Stop further execution
      }
    }

    // Check if the current step is 2 (Contact Information step)
    if (_currentStep == 2) {
      // Validate contact information
      for (var i = 0; i < contacts.length; i++) {
        if (contacts[i].nameController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Contact Name is required for Contact ${i + 1}')),
          );
          return;
        }
        if (contacts[i].emailController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('Contact Email is required for Contact ${i + 1}')),
          );
          return;
        }
        // Basic email validation
        if (!contacts[i].emailController.text.contains('@') ||
            !contacts[i].emailController.text.contains('.')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Please enter a valid email address for Contact ${i + 1}')),
          );
          return;
        }
      }
    }

    // Proceed to the next step
    if (_currentStep < 3) {
      setState(() {
        _currentStep++;
      });
      // Trigger auto-save when step changes
      _triggerAutoSave();
    } else {
      // If on the last step, submit the form
      _submitForm();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser; // Get the current user
    final displayName =
        user?.displayName ?? 'U'; // Default to 'U' if name is null

    final String? photoURL = user?.photoURL;
    return Scaffold(
      backgroundColor: Colors.green,
      body: Container(
        decoration: BoxDecoration(
          color: Color(0xFFD3BDFC),
        ),
        child: Stack(
          children: [
            // New Header Design
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
                            backgroundImage: photoURL != null
                                ? NetworkImage(photoURL)
                                : null,
                            child: photoURL == null
                                ? Icon(Icons.person, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Hi, ${displayName.split(' ')[0]}!',
                            style: mont.copyWith(
                              fontSize: 18,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          // IconButton(
                          //   icon: Icon(SolarIconsOutline.heart),
                          //   onPressed: () {},
                          //   color: Colors.black,
                          // ),
                          IconButton(
                            icon: Icon(SolarIconsOutline.settings),
                            onPressed: () {
                              // Navigate to ProfileScreen
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
                child: SizedBox(
                  width: double.infinity,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal:
                          MediaQuery.of(context).size.width < 400 ? 12 : 16,
                      vertical: 8,
                    ),
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
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons
                                    .arrow_back_ios_rounded, // Sleek back arrow icon
                                color: Color(0xFF3E1885),
                                size: 20,
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                              },
                            ),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Text(
                                    'Profile',
                                    style: mont.copyWith(
                                        color: Color(0xFF3E1885),
                                        fontSize:
                                            MediaQuery.of(context).size.width <
                                                    400
                                                ? 20
                                                : 24,
                                        fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Complete Profile for best experience',
                                        style: mont.copyWith(
                                            color: Color(0xFF3E1885),
                                            fontSize: MediaQuery.of(context)
                                                        .size
                                                        .width <
                                                    400
                                                ? 13
                                                : 15,
                                            fontWeight: FontWeight.w300),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 2,
                                      ),
                                      if (_isAutoSaving ||
                                          _lastSaveTime != null) ...[
                                        SizedBox(height: 8),
                                        _buildAutoSaveIndicator(),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                                width: 8), // Add spacing between text and icon
                            IconButton(
                              icon: Icon(
                                Icons.info_outline,
                                color: Color(0xFF3E1885),
                                size: MediaQuery.of(context).size.width < 400
                                    ? 20
                                    : 24,
                              ),
                              onPressed: () {},
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(
                                minWidth:
                                    MediaQuery.of(context).size.width < 400
                                        ? 32
                                        : 48,
                                minHeight:
                                    MediaQuery.of(context).size.width < 400
                                        ? 32
                                        : 48,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Positioned(
            //   bottom: 20,
            //   right: 20,
            //   child: FloatingActionButton(
            //     onPressed: () {
            //       Navigator.push(
            //         context,
            //         MaterialPageRoute(
            //           builder: (context) =>
            //               AddProfileScreen(userId: widget.userId),
            //         ),
            //       );
            //     },
            //     child: Icon(Icons.add),
            //     backgroundColor: Color(0xFF5664f5),
            //   ),
            // ),
            // Main Content
            Padding(
              padding: const EdgeInsets.only(
                  top: 180), // Adjust this padding to fit below the header
              child: Container(
                color: Colors.white,
                child: Column(
                  children: [
                    // Custom Stepper Indicator
                    Padding(
                      padding:
                          const EdgeInsets.only(left: 24, top: 16, bottom: 10),
                      child: CustomStepperIndicator(
                        currentStep: _currentStep,
                        totalSteps: 4,
                      ),
                    ),

                    // Form Content
                    Expanded(
                      child: SingleChildScrollView(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: _buildCurrentStep(),
                        ),
                      ),
                    ),

                    // Navigation Buttons
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (_currentStep > 0)
                            OutlinedButton(
                              onPressed: () {
                                setState(() => _currentStep--);
                              },
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.black, // Text Color
                                  side: const BorderSide(
                                      color: Colors.black), // Border Color
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12))),
                              child: Text('Previous',
                                  style: sans.copyWith(fontSize: 16)),
                            ),
                          ElevatedButton(
                            onPressed: _nextStep, // Call _nextStep here
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Color(0xFF5664f5), // Blue Background
                              foregroundColor: Colors.white, // White Text
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(_currentStep == 3 ? 'Submit' : 'Next',
                                style: sans.copyWith(
                                    fontSize: 16, color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return FormContainer(
          title: 'Business Details',
          child: _buildBusinessDetailsStep(),
        );
      case 1:
        return FormContainer(
          title: 'Social Media',
          child: _buildSocialMediaStep(),
        );
      case 2:
        return FormContainer(
          title: 'Contact Information',
          child: _buildContactStep(),
        );
      case 3:
        return FormContainer(
          title: 'Review',
          child: _buildReviewStep(),
        );
      default:
        return Container();
    }
  }

  Widget _buildBusinessDetailsStep() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            style: sans.copyWith(fontSize: 16),
            controller: _businessNameController,
            decoration: getInputDecoration('Business Name', isRequired: true),
            onChanged: (_) {
              _updateProgress();
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Business Name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            style: sans.copyWith(fontSize: 16),
            controller: _businessTypeController,
            decoration:
                getInputDecoration('Type of Business', isRequired: true),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Type of Business is required';
              }
              return null;
            },
            onChanged: (_) {
              _updateProgress();
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            style: sans.copyWith(fontSize: 16),
            controller: _phoneController,
            decoration:
                getInputDecoration('Business Phone Number', isRequired: true),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Business Phone Number is required';
              }
              return null;
            },
            keyboardType: TextInputType.phone,
            onChanged: (_) {
              _updateProgress();
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            style: sans.copyWith(fontSize: 16),
            controller: _addressController,
            decoration: getInputDecoration('Address'),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Enter Address please';
              }
              return null;
            },
            maxLines: 2,
            onChanged: (_) {
              _updateProgress();
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: selectedCountry,
            decoration: getInputDecoration('Country'),
            items: ['USA', 'UK', 'Canada', 'Australia', 'India']
                .map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                selectedCountry = newValue;
              });
              _updateProgress();
              _triggerAutoSave();
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                print("Country is not selected");
                return 'Please select a country';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            style: sans.copyWith(fontSize: 16),
            controller: _zipController,
            decoration: getInputDecoration('Zip Code'),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Enter Zip Code';
              }
              return null;
            },
            keyboardType: TextInputType.number,
            onChanged: (_) {
              _updateProgress();
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: selectedTimeZone,
            decoration: getInputDecoration('Time Zone'),
            items: ['UTC', 'EST', 'CST', 'IST'].map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                selectedTimeZone = newValue;
              });
              _updateProgress();
              _triggerAutoSave();
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                print("Country is not selected");
                return 'Please select a country';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            style: sans.copyWith(fontSize: 16),
            controller: _websiteController,
            decoration: getInputDecoration('Website URL'),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Enter WEBSITE URL';
              }
              return null;
            },
            keyboardType: TextInputType.url,
            onChanged: (_) {
              _updateProgress();
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            style: sans.copyWith(fontSize: 16),
            controller: _gstController,
            decoration: getInputDecoration('EIN/GST Number'),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Enter GST Number';
              }
              return null;
            },
            onChanged: (_) {
              _updateProgress();
            },
          ),
        ],
      ),
    );
  }

  InputDecoration getInputDecoration(String label, {bool isRequired = false}) {
    return InputDecoration(
      labelText: label,
      labelStyle: sans.copyWith(
        color: Colors.grey[600],
        fontSize: 18,
      ),
      suffixIcon: isRequired
          ? Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Text(
                ' *',
                style: sans.copyWith(
                  color: Colors.red,
                  fontSize: 18,
                ),
              ),
            )
          : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.blue[700]!),
      ),
      filled: true,
      fillColor: Colors.grey[50],
    );
  }

  Widget _buildSocialMediaStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // const Text(
        //   'Social Media Integrations',
        //   style: TextStyle(
        //     fontSize: 24,
        //     fontWeight: FontWeight.bold,
        //     color: Color(0xFF1A1F36),
        //   ),
        // ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _facebookController,
                style: sans.copyWith(fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'Facebook Business Page URL',
                  labelStyle:
                      sans.copyWith(color: Colors.grey[600], fontSize: 15),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        BorderSide(color: Colors.blue.shade400, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                onChanged: (_) {
                  _updateProgress();
                },
              ),
            ),
            const SizedBox(width: 8), // Spacing between field and button
            ElevatedButton(
              onPressed: () {
                _showSetupDialog(context, 'Facebook');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF5664f5),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text(
                'Setup',
                style: sans.copyWith(
                  fontSize: 15,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _instagramController,
                style: sans.copyWith(fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'Instagram URL',
                  labelStyle:
                      sans.copyWith(color: Colors.grey[600], fontSize: 15),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        BorderSide(color: Colors.blue.shade400, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                onChanged: (_) {
                  _updateProgress();
                },
              ),
            ),
            const SizedBox(width: 8), // Space between field and button
            ElevatedButton(
              onPressed: () {
                _showSetupDialog(context, 'Instagram');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF5664f5),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text('Setup',
                  style: sans.copyWith(color: Colors.white, fontSize: 15)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _googleBusinessController,
          style: sans.copyWith(fontSize: 16),
          decoration: InputDecoration(
            labelText: 'Google Business Page',
            labelStyle: sans.copyWith(color: Colors.grey[600], fontSize: 15),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          onChanged: (_) => _updateProgress(),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _whatsappController,
                style: sans.copyWith(fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'WhatsApp Group Names',
                  labelStyle:
                      sans.copyWith(color: Colors.grey[600], fontSize: 15),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        BorderSide(color: Colors.blue.shade400, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                onChanged: (_) {
                  _updateProgress();
                },
              ),
            ),
            const SizedBox(width: 8), // Space between field and button
            ElevatedButton(
              onPressed: () {
                _showSetupDialog(context, 'WhatsApp');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF5664f5),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text('Setup',
                  style: sans.copyWith(color: Colors.white, fontSize: 15)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _telegramController,
          style: sans.copyWith(fontSize: 16),
          decoration: InputDecoration(
            labelText: 'Telegram Group Names',
            labelStyle: sans.copyWith(color: Colors.grey[600], fontSize: 15),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          onChanged: (_) => _updateProgress(),
        ),
      ],
    );
  }

  Widget _buildContactStep() {
    return Column(
      children: [
        ...contacts.asMap().entries.map((entry) {
          final index = entry.key;
          final contact = entry.value;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Contact ${index + 1}',
                      style: sans.copyWith(fontSize: 16)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: contact.nameController,
                    style: sans.copyWith(fontSize: 16),
                    decoration: InputDecoration(
                      labelText: 'Contact Name',
                      labelStyle:
                          sans.copyWith(color: Colors.grey[600], fontSize: 18),
                      suffixIcon: Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Text(
                          ' *',
                          style: sans.copyWith(
                            color: Colors.red,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            BorderSide(color: Colors.blue.shade400, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    onChanged: (value) {
                      contact.name = value;
                      _updateProgress();
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Contact Name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: contact.emailController,
                    style: sans.copyWith(fontSize: 16),
                    decoration: InputDecoration(
                      labelText: 'Contact Email',
                      labelStyle:
                          sans.copyWith(color: Colors.grey[600], fontSize: 18),
                      suffixIcon: Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Text(
                          ' *',
                          style: sans.copyWith(
                            color: Colors.red,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            BorderSide(color: Colors.blue.shade400, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    onChanged: (value) {
                      contact.email = value;
                      _updateProgress();
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Contact Email is required';
                      }
                      // Basic email validation
                      if (!value.contains('@') || !value.contains('.')) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: contact.isPrimary,
                        onChanged: (bool? value) {
                          setState(() {
                            contact.isPrimary = value ?? false;
                          });
                          _triggerAutoSave();
                        },
                      ),
                      Text('Is Primary Contact?',
                          style:
                              sans.copyWith(color: Colors.black, fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Notification Preferences
                  Text('Notification Preferences',
                      style: sans.copyWith(
                          color: Colors.black,
                          fontSize: 17,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(
                        value: contact.receiveAlerts,
                        onChanged: (bool? value) {
                          setState(() {
                            contact.receiveAlerts = value ?? false;
                          });
                          _triggerAutoSave();
                        },
                      ),
                      Text('Receive Alerts',
                          style: sans.copyWith(
                              color: Color(0xFF030303),
                              fontSize: 15,
                              fontWeight: FontWeight.w200)),
                    ],
                  ),
                  Row(
                    children: [
                      Checkbox(
                        value: contact.emailNotifications,
                        onChanged: (bool? value) {
                          setState(() {
                            contact.emailNotifications = value ?? false;
                          });
                          _triggerAutoSave();
                        },
                      ),
                      Text('Email Notifications',
                          style: sans.copyWith(
                              color: Color(0xFF030303),
                              fontSize: 15,
                              fontWeight: FontWeight.w200)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (index > 0)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          contacts.removeAt(index);
                        });
                        _updateProgress();
                        _setupContactListeners(); // Refresh listeners
                        _triggerAutoSave();
                      },
                      child: Text(
                        'Remove',
                        style:
                            texts.copyWith(color: Colors.black, fontSize: 15),
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            setState(() {
              contacts.add(Contact());
            });
            _setupContactListeners(); // Setup listeners for new contact
            _triggerAutoSave();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF5664f5), // Blue Background
            foregroundColor: Colors.white, // White Text
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(
            Icons.add,
            color: Colors.white,
          ),
          label: Text('Add Contact',
              style: sans.copyWith(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w200)),
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildReviewSection(
              'Business Details',
              [
                'Business Name: ${_businessNameController.text}',
                'Business Type: ${_businessTypeController.text}',
                'Phone: ${_phoneController.text}',
                'Address: ${_addressController.text}',
                'Country: $selectedCountry',
                'ZIP: ${_zipController.text}',
                'Time Zone: $selectedTimeZone',
                'Website: ${_websiteController.text}',
                'EIN/GST: ${_gstController.text}',
              ],
              icon: Icons.business,
            ),
            const SizedBox(height: 32),
            _buildReviewSection(
              'Social Media',
              [
                'Facebook: ${_facebookController.text}',
                'Instagram: ${_instagramController.text}',
                'Google Business: ${_googleBusinessController.text}',
                'WhatsApp Groups: ${_whatsappController.text}',
                'Telegram Groups: ${_telegramController.text}',
              ],
              icon: Icons.facebook_rounded,
            ),
            const SizedBox(height: 32),
            _buildReviewSection(
              'Contacts',
              contacts
                  .map((contact) =>
                      '${contact.name} (${contact.email})' +
                      (contact.isPrimary ? ' (Primary)' : ''))
                  .toList(),
              icon: Icons.people,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewSection(String title, List<String> items,
      {IconData? icon}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 3,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 24,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 12),
              ],
              Text(title,
                  style: sans.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                    letterSpacing: 0.5,
                  )
                  // style: TextStyle(
                  //   fontSize: 20,
                  //   fontWeight: FontWeight.bold,
                  //   color: Theme.of(context).primaryColor,
                  //   letterSpacing: 0.5,
                  // ),
                  ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(),
          ),
          ...items.map((item) {
            final parts = item.split(': ');
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (parts.length > 1) ...[
                    Expanded(
                      flex: 2,
                      child: Text(parts[0] + ':',
                          style: sans.copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                            letterSpacing: 0.5,
                          )),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(parts[1],
                          style: sans.copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          )
                          // style: const TextStyle(
                          //   fontSize: 15,
                          //   color: Colors.black87,
                          //   height: 1.5,
                          // ),
                          ),
                    ),
                  ] else ...[
                    Expanded(
                      child: Text(item,
                          style: sans.copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          )
                          // style: const TextStyle(
                          //   fontSize: 15,
                          //   color: Colors.black87,
                          //   height: 1.5,
                          // ),
                          ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  void _submitForm() async {
    final data = {
      'businessDetails': {
        'name': _businessNameController.text,
        'type': _businessTypeController.text,
        'phone': _phoneController.text,
        'address': _addressController.text,
        'country': selectedCountry,
        'zip': _zipController.text,
        'timeZone': selectedTimeZone,
        'website': _websiteController.text,
        'gstNumber': _gstController.text,
      },
      'socialMedia': {
        'facebook': _facebookController.text,
        'instagram': _instagramController.text,
        'googleBusiness': _googleBusinessController.text,
        'whatsapp': _whatsappController.text,
        'telegram': _telegramController.text,
      },
      'contacts': contacts
          .map((contact) => {
                'name': contact.name,
                'email': contact.email,
                'isPrimary': contact.isPrimary,
                'receiveAlerts': contact.receiveAlerts,
                'emailNotifications': contact.emailNotifications,
              })
          .toList(),
    };

    try {
      if (widget.profileId == null) {
        // Add a new profile
        await FirebaseFirestore.instance
            .collection('profiles')
            .doc(widget.userId)
            .collection('profiles')
            .add(data);
      } else {
        // Update an existing profile
        await FirebaseFirestore.instance
            .collection('profiles')
            .doc(widget.userId)
            .collection('profiles')
            .doc(widget.profileId)
            .set(data, SetOptions(merge: true));
      }

      // Clear auto-saved data after successful submission
      await _clearAutoSavedData();

      // Show success message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                SolarIconsOutline.checkCircle,
                color: Colors.white,
                size: 20,
              ),
              SizedBox(width: 12),
              Text(
                'Profile saved successfully!',
                style: mont.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF5664F5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: Duration(seconds: 3),
          margin: EdgeInsets.all(16),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {
              if (!mounted) return;
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );

      // Navigate to MainScreen after a short delay
      Future.delayed(Duration(seconds: 1), () {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainScreen(),
          ),
        );
      });
    } catch (e) {
      // Show error message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving profile: $e')),
      );
    }
  }

  void _showSetupDialog(BuildContext context, String platform) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon with gradient background
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _getPlatformGradient(platform),
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _getPlatformGradient(platform)[0]
                              .withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Icon(
                      _getPlatformIcon(platform),
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 25),

                  // Title
                  Text(
                    '$platform Setup Assistance',
                    style: mont.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2D3748),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 15),

                  // Description
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7FAFC),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'Our SEO manager will contact you and help you set up your $platform configuration for optimal social media integration.',
                      style: mont.copyWith(
                        fontSize: 16,
                        color: const Color(0xFF4A5568),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 25),

                  // Animated feature list
                  Container(
                    width: double.infinity,
                    child: Column(
                      children: [
                        _buildFeatureItem('✨', 'Professional setup guidance'),
                        const SizedBox(height: 8),
                        _buildFeatureItem('🔧', 'Configuration optimization'),
                        const SizedBox(height: 8),
                        _buildFeatureItem('📞', 'Direct expert support'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: Colors.grey[300]!,
                                width: 1.5,
                              ),
                            ),
                          ),
                          child: Text(
                            'Maybe Later',
                            style: mont.copyWith(
                              fontSize: 16,
                              color: const Color(0xFF718096),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _getPlatformGradient(platform),
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: _getPlatformGradient(platform)[0]
                                    .withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _handleSetupRequest(platform);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Request Setup',
                              style: mont.copyWith(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeatureItem(String emoji, String text) {
    return Row(
      children: [
        Text(
          emoji,
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: mont.copyWith(
              fontSize: 14,
              color: const Color(0xFF4A5568),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  List<Color> _getPlatformGradient(String platform) {
    switch (platform.toLowerCase()) {
      case 'facebook':
        return [const Color(0xFF1877F2), const Color(0xFF42A5F5)];
      case 'instagram':
        return [
          const Color(0xFFE4405F),
          const Color(0xFFFD1D1D),
          const Color(0xFFFFDC80)
        ];
      case 'whatsapp':
        return [const Color(0xFF25D366), const Color(0xFF128C7E)];
      default:
        return [const Color(0xFF667EEA), const Color(0xFF764BA2)];
    }
  }

  IconData _getPlatformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'facebook':
        return Icons.facebook;
      case 'instagram':
        return Icons.camera_alt;
      case 'whatsapp':
        return Icons.chat;
      default:
        return Icons.settings;
    }
  }

  void _handleSetupRequest(String platform) {
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Setup Request Sent!',
                    style: mont.copyWith(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Our SEO manager will contact you soon.',
                    style: mont.copyWith(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: _getPlatformGradient(platform)[0],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

class CustomStepperIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const CustomStepperIndicator({
    Key? key,
    required this.currentStep,
    required this.totalSteps,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps, (index) {
        bool isCompleted = index < currentStep;
        bool isCurrent = index == currentStep;
        bool isLast = index == totalSteps - 1;

        return Expanded(
          child: Row(
            children: [
              // Circle indicator
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? Colors.green
                      : isCurrent
                          ? Colors.blue[300]
                          : Colors.grey[400],
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check, color: Colors.white)
                      : Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              // Connecting line
              if (!isLast)
                Expanded(
                  child: Container(
                    height: 2,
                    color: isCompleted ? Colors.green : Colors.grey[300],
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

class FormContainer extends StatelessWidget {
  final Widget child;
  final String title;

  const FormContainer({
    Key? key,
    required this.child,
    required this.title,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 5,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: sans.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class Contact {
  String name = '';
  String email = '';
  bool isPrimary = false;
  bool receiveAlerts = false;
  bool emailNotifications = false;
  TextEditingController nameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
}
