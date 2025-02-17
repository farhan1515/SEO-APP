import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seo_app/screens/dashboard_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:seo_app/theme/text_style.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();
  double _completionPercentage = 0;

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
  bool _receiveAlerts = false;
  bool _emailNotifications = false;

  String? selectedCountry;
  String? selectedTimeZone;

  void _updateProgress() {
    int filledFields = 0;
    final totalFields = 18; // Total fields across all steps

    // Check business details
    if (_businessNameController.text.isNotEmpty) filledFields++;
    if (_businessTypeController.text.isNotEmpty) filledFields++;
    if (_phoneController.text.isNotEmpty) filledFields++;
    if (_addressController.text.isNotEmpty) filledFields++;
    if (selectedCountry != null) filledFields++;
    if (_zipController.text.isNotEmpty) filledFields++;
    if (selectedTimeZone != null) filledFields++;
    if (_websiteController.text.isNotEmpty) filledFields++;
    if (_gstController.text.isNotEmpty) filledFields++;

    // Check social media
    if (_facebookController.text.isNotEmpty) filledFields++;
    if (_instagramController.text.isNotEmpty) filledFields++;
    if (_googleBusinessController.text.isNotEmpty) filledFields++;
    if (_whatsappController.text.isNotEmpty) filledFields++;
    if (_telegramController.text.isNotEmpty) filledFields++;

    // Check contacts
    for (var contact in contacts) {
      if (contact.name.isNotEmpty) filledFields++;
      if (contact.email.isNotEmpty) filledFields++;
    }

    setState(() {
      _completionPercentage = (filledFields / totalFields) * 100;
    });
  }

  Future<void> _fetchProfileData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('profiles')
          .doc(widget.userId)
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
    _fetchProfileData();
  }

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser; // Get the current user
    final displayName =
        user?.displayName ?? 'U'; // Default to 'U' if name is null
    final firstLetter =
        displayName.isNotEmpty ? displayName[0] : 'U'; // Get the first letter
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Header with profile and completion
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 5,
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.blue[700],
                    child: Text(
                      firstLetter.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Customer Profile',
                          style: sans.copyWith(fontSize: 20)),
                      Text(
                          '${_completionPercentage.toStringAsFixed(0)}% Complete',
                          style: sans.copyWith(
                              color: Color(0xFF23a93b), fontSize: 14)),
                    ],
                  ),
                ],
              ),
            ),

            // Custom Stepper Indicator
            Padding(
              padding: const EdgeInsets.only(left: 24, top: 16, bottom: 10),
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                // boxShadow: [
                //   BoxShadow(
                //     color: Colors.grey.withOpacity(0.1),
                //     spreadRadius: 1,
                //     blurRadius: 5,
                //     offset: const Offset(0, -3),
                //   ),
                // ],
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
                      child:
                          Text('Previous', style: sans.copyWith(fontSize: 16)),
                    ),
                  ElevatedButton(
                    onPressed: () {
                      if (_currentStep < 3) {
                        setState(() => _currentStep++);
                      } else {
                        _submitForm();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF5664f5), // Blue Background
                      foregroundColor: Colors.white, // White Text
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(_currentStep == 3 ? 'Submit' : 'Next',
                        style:
                            sans.copyWith(fontSize: 16, color: Colors.white)),
                  ),
                ],
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
            decoration: getInputDecoration('Business Name'),
            onChanged: (_) => _updateProgress(),
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'Please enter business name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            style: sans.copyWith(fontSize: 16),
            controller: _businessTypeController,
            decoration: getInputDecoration('Type of Business'),
            onChanged: (_) => _updateProgress(),
          ),
          const SizedBox(height: 16),
          TextFormField(
            style: sans.copyWith(fontSize: 16),
            controller: _phoneController,
            decoration: getInputDecoration('Business Phone Number'),
            keyboardType: TextInputType.phone,
            onChanged: (_) => _updateProgress(),
          ),
          const SizedBox(height: 16),
          TextFormField(
            style: sans.copyWith(fontSize: 16),
            controller: _addressController,
            decoration: getInputDecoration('Address'),
            maxLines: 2,
            onChanged: (_) => _updateProgress(),
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
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            style: sans.copyWith(fontSize: 16),
            controller: _zipController,
            decoration: getInputDecoration('Zip Code'),
            keyboardType: TextInputType.number,
            onChanged: (_) => _updateProgress(),
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
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            style: sans.copyWith(fontSize: 16),
            controller: _websiteController,
            decoration: getInputDecoration('Website URL'),
            keyboardType: TextInputType.url,
            onChanged: (_) => _updateProgress(),
          ),
          const SizedBox(height: 16),
          TextFormField(
            style: sans.copyWith(fontSize: 16),
            controller: _gstController,
            decoration: getInputDecoration('EIN/GST Number'),
            onChanged: (_) => _updateProgress(),
          ),
        ],
      ),
    );
  }

  InputDecoration getInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: sans.copyWith(color: Colors.grey[600], fontSize: 18),
      // labelStyle: TextStyle(color: Colors.grey[600]),
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
                onChanged: (_) => _updateProgress(),
              ),
            ),
            const SizedBox(width: 8), // Spacing between field and button
            ElevatedButton(
              onPressed: () {
                // Implement setup logic
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
                onChanged: (_) => _updateProgress(),
              ),
            ),
            const SizedBox(width: 8), // Space between field and button
            ElevatedButton(
              onPressed: () {
                // Implement setup logic
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
        TextFormField(
          controller: _whatsappController,
          style: sans.copyWith(fontSize: 16),
          decoration: InputDecoration(
            labelText: 'WhatsApp Group Names',
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
                    style: sans.copyWith(
                        fontSize: 16), // Added style for input text
                    decoration: InputDecoration(
                      labelText: 'Contact Name',
                      labelStyle:
                          sans.copyWith(color: Colors.grey[600], fontSize: 18),
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
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: contact.emailController,
                    style: sans.copyWith(
                        fontSize: 16), // Added style for input text
                    decoration: InputDecoration(
                      labelText: 'Contact Email',
                      labelStyle:
                          sans.copyWith(color: Colors.grey[600], fontSize: 18),
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
    if (_formKey.currentState?.validate() ?? false) {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      try {
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

        print("Data to be saved: $data"); // Debug print

        // Save data to Firestore
        await FirebaseFirestore.instance
            .collection('profiles')
            .doc(widget.userId)
            .set(data, SetOptions(merge: true));

        print("Profile updated successfully!");

        // Close loading indicator
        Navigator.of(context).pop();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile saved successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Navigate to DashboardScreen
        if (mounted) {
          print("Navigating to DashboardScreen");
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const DashboardScreen(),
            ),
          );
        }
      } catch (e) {
        // Close loading indicator
        if (mounted) {
          Navigator.of(context).pop();
        }
        print("Error: $e");

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
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
