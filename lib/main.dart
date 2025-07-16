import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:seo_app/screens/auth_checker.dart';
import 'package:seo_app/services/user_status.dart';
import 'package:seo_app/services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Wait for Firebase Auth to initialize
  await Future.delayed(const Duration(seconds: 1));

  // Only initialize notifications if user is logged in
  if (FirebaseAuth.instance.currentUser != null) {
    await NotificationService.initialize();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppLifecycleManager(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'SEO Credit',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: const AuthChecker(),
      ),
    );
  }
}

// AppLifecycleManager to handle user status updates
class AppLifecycleManager extends StatefulWidget {
  final Widget child;

  const AppLifecycleManager({Key? key, required this.child}) : super(key: key);

  @override
  _AppLifecycleManagerState createState() => _AppLifecycleManagerState();
}

class _AppLifecycleManagerState extends State<AppLifecycleManager>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize notifications when auth state changes
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user != null) {
        await NotificationService.initialize();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      UserStatusService.updateUserStatus();
      // Re-initialize notifications if needed when app resumes
      if (FirebaseAuth.instance.currentUser != null) {
        NotificationService.initialize();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
