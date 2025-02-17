import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:seo_app/firebase_options.dart';
import 'package:seo_app/screens/profile_screen.dart';
import 'package:seo_app/screens/signin_screen.dart';
import 'package:seo_app/screens/dashboard_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seo_app/services/user_status.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SEO APP',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: AppLifecycleManager(
        child: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasData && snapshot.data != null) {
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('profiles')
                    .doc(snapshot.data!.uid)
                    .get(),
                builder: (context, profileSnapshot) {
                  if (profileSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (profileSnapshot.hasData && profileSnapshot.data!.exists) {
                    // Profile is complete, navigate to DashboardScreen
                    return DashboardScreen();
                  } else {
                    // Profile is incomplete, navigate to ProfileScreen
                    return ProfileScreen(userId: snapshot.data!.uid);
                  }
                },
              );
            }

            // No user is signed in, navigate to SignInScreen
            return const SignInScreen();
          },
        ),
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