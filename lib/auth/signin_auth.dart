// class AuthRepository {
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   final GoogleSignIn _googleSignIn = GoogleSignIn();

//   // Stream of auth state changes
//   Stream<User?> get authStateChanges => _auth.authStateChanges();

//   // Google Sign In
//   Future<UserCredential?> signInWithGoogle() async {
//     try {
//       final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
//       if (googleUser == null) return null;

//       final GoogleSignInAuthentication googleAuth = 
//           await googleUser.authentication;
//       final credential = GoogleAuthProvider.credential(
//         accessToken: googleAuth.accessToken,
//         idToken: googleAuth.idToken,
//       );

//       return await _auth.signInWithCredential(credential);
//     } catch (e) {
//       throw AuthException('Failed to sign in with Google: $e');
//     }
//   }

//   // Apple Sign In
//   Future<UserCredential?> signInWithApple() async {
//     try {
//       final appleCredential = await SignInWithApple.getAppleIDCredential(
//         scopes: [
//           AppleIDAuthorizationScopes.email,
//           AppleIDAuthorizationScopes.fullName,
//         ],
//       );

//       final oAuthCredential = OAuthProvider('apple.com').credential(
//         idToken: appleCredential.identityToken,
//         accessToken: appleCredential.authorizationCode,
//       );

//       return await _auth.signInWithCredential(oAuthCredential);
//     } catch (e) {
//       throw AuthException('Failed to sign in with Apple: $e');
//     }
//   }

//   // Email Sign In
//   Future<UserCredential?> signInWithEmail(String email, String password) async {
//     try {
//       return await _auth.signInWithEmailAndPassword(
//         email: email,
//         password: password,
//       );
//     } catch (e) {
//       throw AuthException('Failed to sign in with email: $e');
//     }
//   }

//   // Sign Out
//   Future<void> signOut() async {
//     try {
//       await Future.wait([
//         _auth.signOut(),
//         _googleSignIn.signOut(),
//       ]);
//     } catch (e) {
//       throw AuthException('Failed to sign out: $e');
//     }
//   }
// }

// // Custom exception for auth errors
// class AuthException implements Exception {
//   final String message;
//   AuthException(this.message);
// }

// // lib/features/auth/controllers/auth_controller.dart
// import 'package:flutter_riverpod/flutter_riverpod.dart';

// final authRepositoryProvider = Provider((ref) => AuthRepository());

// final authControllerProvider = StateNotifierProvider<AuthController, AsyncValue<UserModel?>>((ref) {
//   return AuthController(ref.watch(authRepositoryProvider));
// });

// class AuthController extends StateNotifier<AsyncValue<UserModel?>> {
//   final AuthRepository _authRepository;

//   AuthController(this._authRepository) : super(const AsyncValue.loading()) {
//     _authRepository.authStateChanges.listen((user) {
//       state = AsyncValue.data(user != null ? UserModel.fromFirebase(user) : null);
//     });
//   }

//   Future<void> signInWithGoogle() async {
//     try {
//       state = const AsyncValue.loading();
//       await _authRepository.signInWithGoogle();
//     } catch (e, st) {
//       state = AsyncValue.error(e, st);
//     }
//   }

//   // Similar methods for Apple and Email sign in...
// }
