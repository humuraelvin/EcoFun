import 'package:eco_step/features/auth/domain/entities/user.dart';
import 'package:eco_step/features/auth/domain/repositories/auth_repository.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class AuthRepositoryImpl implements AuthRepository {
  final firebase_auth.FirebaseAuth _firebaseAuth =
      firebase_auth.FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: dotenv.env['GOOGLE_CLIENT_ID'],
  );

  @override
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null;
      }
      final googleAuth = await googleUser.authentication;
      final credential = firebase_auth.GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );
      final result = await _firebaseAuth.signInWithCredential(credential);
      if (result.user != null) await _ensureProfile(result.user!);
      return _fromFirebaseUser(result.user);
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      return null;
    }
  }

  @override
  Future<void> signOut() async {
    await Future.wait([_googleSignIn.signOut(), _firebaseAuth.signOut()]);
  }

  @override
  Future<User?> getCurrentUser() async {
    return _fromFirebaseUser(_firebaseAuth.currentUser);
  }

  @override
  Future<User?> signInWithEmail(String email, String password) async {
    final result = await _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    if (result.user != null) await _ensureProfile(result.user!);
    return _fromFirebaseUser(result.user);
  }

  @override
  Future<User?> signUpWithEmail(
    String name,
    String email,
    String password,
  ) async {
    final result = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await result.user?.updateDisplayName(name.trim());
    if (result.user != null) await _ensureProfile(result.user!, name.trim());
    return _fromFirebaseUser(result.user);
  }

  @override
  Future<void> sendPasswordResetOtp(String email) async {
    await _functions.httpsCallable('sendPasswordResetOtp').call({
      'email': email.trim(),
    });
  }

  @override
  Future<void> resetPasswordWithOtp({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    await _functions.httpsCallable('resetPasswordWithOtp').call({
      'email': email.trim(),
      'otp': otp.trim(),
      'newPassword': newPassword,
    });
  }

  User? _fromFirebaseUser(firebase_auth.User? user) {
    if (user == null || user.email == null) return null;
    return User(
      id: user.uid,
      email: user.email!,
      name: user.displayName ?? user.email!.split('@').first,
      profileImageUrl: user.photoURL,
    );
  }

  Future<void> _ensureProfile(
    firebase_auth.User user, [
    String? preferredName,
  ]) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) {
        transaction.set(ref, {
          'uid': user.uid,
          'fullName':
              (preferredName?.isNotEmpty == true
                  ? preferredName
                  : user.displayName) ??
              user.email?.split('@').first ??
              'EcoStep user',
          'photoURL': user.photoURL,
          'points': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  @override
  Stream<User?> get authStateChanges {
    return _firebaseAuth.authStateChanges().map(_fromFirebaseUser);
  }
}
