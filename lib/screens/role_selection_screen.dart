import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seo_app/screens/main_screen.dart';
import 'package:seo_app/screens/profile_screen.dart';
import 'package:seo_app/theme/text_style.dart'; // Import your text styles
// import 'package:lottie/lottie.dart'; // You may need to add this dependency

class RoleSelectionScreen extends StatefulWidget {
  final String userId;

  const RoleSelectionScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _RoleSelectionScreenState createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with SingleTickerProviderStateMixin {
  final List<RoleOption> roles = [
    RoleOption(
      title: 'Customer',
      description: 'Browse services and connect with professionals',
      icon: Icons.person,
      color: Color(0xFF5D6AEE),
      animationAsset: 'assets/animations/customer_animation.json',
    ),
    RoleOption(
      title: 'SEO.Credit Manager',
      description: 'Manage SEO projects and team members',
      icon: Icons.pie_chart,
      color: Color(0xFF3E1885),
      animationAsset: 'assets/animations/manager_animation.json',
      isProtected: true,
      passwordHint: "Ask your admin for the access code",
    ),
    RoleOption(
      title: 'Graphic Designer',
      description: 'Create stunning designs for clients',
      icon: Icons.brush,
      color: Color(0xFFFF6B6B),
      animationAsset: 'assets/animations/designer_animation.json',
      isProtected: true,
      passwordHint: "Design team password required",
    ),
  ];

  void _handleRoleSelection(RoleOption role) async {
    // If role is protected, show password dialog
    if (role.isProtected) {
      final isVerified = await _showRolePasswordDialog(context, role);
      if (!isVerified) {
        // Show error if password was wrong
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Access denied - incorrect password'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        return;
      }
    }

    // If not protected or password was correct, select the role
    setState(() {
      selectedRole = role.title;
    });

    // Play a nice confirmation animation
    _animationController.reset();
    _animationController.forward();
  }

  String? selectedRole;
  bool isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<bool> _showRolePasswordDialog(
      BuildContext context, RoleOption role) async {
    final passwordController = TextEditingController();
    bool isPasswordVisible = false;
    bool isVerifying = false;

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setState) {
                return Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  backgroundColor: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: role.color.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.lock_outline,
                            size: 32,
                            color: role.color,
                          ),
                        ),
                        SizedBox(height: 20),

                        // Title
                        Text(
                          'Verify ${role.title} Role',
                          style: mont.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: role.color,
                          ),
                        ),
                        SizedBox(height: 8),

                        // Hint
                        if (role.passwordHint != null)
                          Text(
                            role.passwordHint!,
                            style: mont.copyWith(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        SizedBox(height: 24),

                        // Password Field
                        TextField(
                          controller: passwordController,
                          obscureText: !isPasswordVisible,
                          decoration: InputDecoration(
                            labelText: 'Enter Access Code',
                            labelStyle: mont.copyWith(
                                color: Colors.grey[600], fontSize: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: role.color, width: 2),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                isPasswordVisible
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.grey[500],
                              ),
                              onPressed: () {
                                setState(() {
                                  isPasswordVisible = !isPasswordVisible;
                                });
                              },
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                        ),
                        SizedBox(height: 24),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: Colors.grey[300]!),
                                  ),
                                ),
                                child: Text(
                                  'Cancel',
                                  style: mont.copyWith(
                                    color: Colors.grey[700],
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: isVerifying
                                    ? null
                                    : () async {
                                        setState(() => isVerifying = true);
                                        final isCorrect =
                                            await _verifyRolePassword(
                                          role.title,
                                          passwordController.text,
                                        );
                                        setState(() => isVerifying = false);
                                        if (isCorrect) {
                                          Navigator.pop(context, true);
                                        } else {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content:
                                                  Text('Incorrect access code'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: role.color,
                                  padding: EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: isVerifying
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        'Verify',
                                        style: mont.copyWith(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ) ??
        false;
  }

  Future<bool> _verifyRolePassword(String role, String enteredPassword) async {
    // In production, store these securely (Firebase Remote Config or secure storage)
    const passwords = {
      'SEO.Credit Manager': 'SEO123', // Change to your actual password
      'Graphic Designer': 'SEO123', // Change to your actual password
    };

    return passwords[role] == enteredPassword;
  }

  Future<void> saveUserRole() async {
    if (selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a role to continue'),
          backgroundColor: Color(0xFF3E1885),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('roles')
          .doc(widget.userId)
          .set({
        'role': selectedRole,
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'isVerified':
            roles.firstWhere((r) => r.title == selectedRole).isProtected,
      });

      await Future.delayed(Duration(milliseconds: 500));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => selectedRole == 'Customer'
                ? ProfileScreen(userId: widget.userId)
                : MainScreen(),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving role: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFD3BDFC), Colors.white],
            stops: [0.3, 0.7],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _animation,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 40),
                  Text(
                    "Choose Your Role",
                    style: mont.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3E1885),
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    "Select the role that best describes what you do",
                    style: mont.copyWith(
                      fontSize: 16,
                      color: Color(0xFF6B48C8),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  SizedBox(height: 40),
                  Expanded(
                    child: ListView.builder(
                      itemCount: roles.length,
                      itemBuilder: (context, index) {
                        final role = roles[index];
                        final isSelected = selectedRole == role.title;

                        return AnimatedContainer(
                          duration: Duration(milliseconds: 300),
                          margin: EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? role.color.withOpacity(0.1)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? role.color
                                  : Colors.grey.shade300,
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: role.color.withOpacity(0.2),
                                      blurRadius: 10,
                                      offset: Offset(0, 4),
                                    )
                                  ]
                                : [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.1),
                                      blurRadius: 5,
                                      offset: Offset(0, 2),
                                    )
                                  ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _handleRoleSelection(role),
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        // Role Icon with Background
                                        Container(
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            color: role.color.withOpacity(0.2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            role.icon,
                                            size: 28,
                                            color: role.color,
                                          ),
                                        ),
                                        SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                role.title,
                                                style: mont.copyWith(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w600,
                                                  color: isSelected
                                                      ? role.color
                                                      : Colors.black87,
                                                ),
                                              ),
                                              SizedBox(height: 6),
                                              Text(
                                                role.description,
                                                style: mont.copyWith(
                                                  fontSize: 14,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Selection indicator
                                        Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isSelected
                                                  ? role.color
                                                  : Colors.grey.shade400,
                                              width: 2,
                                            ),
                                          ),
                                          child: isSelected
                                              ? Center(
                                                  child: Container(
                                                    width: 12,
                                                    height: 12,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: role.color,
                                                    ),
                                                  ),
                                                )
                                              : null,
                                        ),
                                        // Add this near the selection indicator (inside your Row widget)
                                        if (role.isProtected)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(left: 8),
                                            child: Icon(
                                              Icons.lock_outline,
                                              size: 16,
                                              color: isSelected
                                                  ? role.color
                                                  : Colors.grey[500],
                                            ),
                                          ),
                                      ],
                                    ),

                                    // Animation area (optional, if you have Lottie animations)
                                    if (isSelected)
                                      Container(
                                        height: 100,
                                        margin: EdgeInsets.only(top: 16),
                                        child: Center(
                                          // If you have Lottie animations, uncomment this:
                                          // child: Lottie.asset(
                                          //   role.animationAsset,
                                          //   repeat: true,
                                          // ),
                                          // Otherwise use a placeholder:
                                          child: Icon(
                                            role.icon,
                                            size: 50,
                                            color: role.color.withOpacity(0.5),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 20),
                  AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: selectedRole != null
                          ? LinearGradient(
                              colors: [Color(0xFF3E1885), Color(0xFF6B48C8)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            )
                          : null,
                      color: selectedRole == null ? Colors.grey.shade300 : null,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: selectedRole != null
                          ? [
                              BoxShadow(
                                color: Color(0xFF3E1885).withOpacity(0.3),
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ]
                          : [],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: isLoading ? null : saveUserRole,
                        borderRadius: BorderRadius.circular(16),
                        child: Center(
                          child: isLoading
                              ? SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  ),
                                )
                              : Text(
                                  "Continue",
                                  style: mont.copyWith(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: selectedRole != null
                                        ? Colors.white
                                        : Colors.grey.shade700,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Helper class for role options
class RoleOption {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String animationAsset;
  final bool isProtected;
  final String? passwordHint;

  RoleOption({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.animationAsset,
    this.isProtected = false,
    this.passwordHint,
  });
}
