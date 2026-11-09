import 'package:eco_step/features/auth/domain/entities/user.dart';

abstract class AuthRepository {
  Future<User?> signInWithGoogle();
  Future<User?> signInWithEmail(String email, String password);
  Future<User?> signUpWithEmail(String name, String email, String password);
  Future<void> sendPasswordResetOtp(String email);
  Future<void> resetPasswordWithOtp({
    required String email,
    required String otp,
    required String newPassword,
  });
  Future<void> signOut();
  Future<User?> getCurrentUser();
  Stream<User?> get authStateChanges;
}
