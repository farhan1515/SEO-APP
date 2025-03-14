import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:seo_app/firebase_options.dart';
import 'package:seo_app/screens/main_screen.dart';
import 'package:seo_app/screens/profile_screen.dart';
import 'package:seo_app/screens/signin_screen.dart';
import 'package:seo_app/screens/splash_screen.dart';
import 'package:seo_app/screens/auth_checker.dart';
import 'package:seo_app/screens/dashboard_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seo_app/services/user_status.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SEO Credit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3E1885)),
        useMaterial3: true,
      ),
      // Start with the splash screen
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/auth_checker': (context) => AppLifecycleManager(
          child: AuthChecker(),
        ),
      },
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}