import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supa.dart';

enum SignUpOutcome { signedIn, needsConfirmation }

abstract final class AuthRepository {
  static String get _webClientId => dotenv.env['GOOGLE_WEB_CLIENT_ID']?.trim() ?? '';
  static String get _iosClientId => dotenv.env['GOOGLE_IOS_CLIENT_ID']?.trim() ?? '';

  static bool get googleEnabled => _webClientId.isNotEmpty;

  static Future<void> signIn(String email, String password) async {
    await supa.auth.signInWithPassword(email: email.trim().toLowerCase(), password: password);
  }

  /// [lang] ('en' or 'rw') picks the language of every email EcoFun sends this person.
  static Future<SignUpOutcome> signUp(String name, String email, String password, {String lang = 'en'}) async {
    final res = await supa.auth.signUp(
      email: email.trim().toLowerCase(),
      password: password,
      data: {'full_name': name.trim(), 'lang': lang},
    );
    // Supabase returns a user with no identities when the email is already registered.
    if (res.user != null && (res.user!.identities?.isEmpty ?? false)) {
      throw const AuthException('User already registered');
    }
    return res.session != null ? SignUpOutcome.signedIn : SignUpOutcome.needsConfirmation;
  }

  static Future<void> verifySignUpCode(String email, String code) async {
    await supa.auth.verifyOTP(email: email.trim().toLowerCase(), token: code.trim(), type: OtpType.signup);
  }

  static Future<void> resendConfirmation(String email) async {
    await supa.auth.resend(type: OtpType.signup, email: email.trim().toLowerCase());
  }

  static Future<void> sendResetCode(String email) async {
    await supa.auth.resetPasswordForEmail(email.trim().toLowerCase());
  }

  /// Verifies the emailed recovery code (signs the user in) then sets the new password.
  static Future<void> resetPassword(String email, String code, String newPassword) async {
    await supa.auth.verifyOTP(email: email.trim().toLowerCase(), token: code.trim(), type: OtpType.recovery);
    await supa.auth.updateUser(UserAttributes(password: newPassword));
  }

  /// Keeps the email language in step with the app language (stored in the user's metadata).
  static Future<void> syncLanguage(String lang) async {
    final user = supa.auth.currentUser;
    if (user == null || user.userMetadata?['lang'] == lang) return;
    try {
      await supa.auth.updateUser(UserAttributes(data: {'lang': lang}));
    } catch (_) {
      // Not critical; retried on the next app start.
    }
  }

  /// Streak and progress emails (security emails are always sent).
  static bool get emailUpdates => supa.auth.currentUser?.userMetadata?['email_updates'] != false;

  static Future<void> setEmailUpdates(bool on) async {
    await supa.auth.updateUser(UserAttributes(data: {'email_updates': on}));
  }

  static bool _googleReady = false;

  /// Native Google sign-in, exchanged for a Supabase session.
  /// Returns false if the user closed the Google sheet.
  static Future<bool> signInWithGoogle() async {
    final google = GoogleSignIn.instance;
    if (!_googleReady) {
      await google.initialize(
        serverClientId: _webClientId,
        clientId: _iosClientId.isEmpty ? null : _iosClientId,
      );
      _googleReady = true;
    }
    final GoogleSignInAccount account;
    try {
      account = await google.authenticate(scopeHint: const ['email', 'profile']);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return false;
      rethrow;
    }
    final idToken = account.authentication.idToken;
    if (idToken == null) throw const AuthException('Google did not return an ID token.');
    final authz = await account.authorizationClient.authorizationForScopes(const ['email', 'profile']);
    await supa.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: authz?.accessToken,
    );
    return true;
  }

  static Future<void> signOut() async {
    try {
      if (_googleReady) await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await supa.auth.signOut();
  }
}
