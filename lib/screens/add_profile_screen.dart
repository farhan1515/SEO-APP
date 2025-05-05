import 'package:flutter/material.dart';
import 'package:seo_app/screens/profile_screen.dart';

class AddProfileScreen extends StatefulWidget {
  const AddProfileScreen({super.key});

  @override
  State<AddProfileScreen> createState() => _AddProfileScreenState();
}

class _AddProfileScreenState extends State<AddProfileScreen> {
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
  bool _receiveAlerts = false;
  bool _emailNotifications = false;

  String? selectedCountry;
  String? selectedTimeZone;

  @override
  void dispose() {
    // Dispose controllers
    _businessNameController.dispose();
    _businessTypeController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _zipController.dispose();
    _websiteController.dispose();
    _gstController.dispose();

    _facebookController.dispose();
    _instagramController.dispose();
    _googleBusinessController.dispose();
    _whatsappController.dispose();
    _telegramController.dispose();

    for (final contact in contacts) {
      contact.nameController.dispose();
      contact.emailController.dispose();
    }

    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
 appBar: AppBar(
        title: Text('Add New Profile'),
      ),
    );
  }
}