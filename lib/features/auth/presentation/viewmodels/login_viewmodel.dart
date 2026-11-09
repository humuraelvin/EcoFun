import 'package:eco_step/features/auth/domain/entities/user.dart';
import 'package:eco_step/features/auth/domain/usecases/sign_in_with_google_usecase.dart';
import 'package:eco_step/features/auth/domain/repositories/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:get/get.dart';

class LoginViewModel extends GetxController {
  final SignInWithGoogleUseCase _signInWithGoogleUseCase;
  final AuthRepository _authRepository;

  LoginViewModel(this._signInWithGoogleUseCase, this._authRepository);

  final Rx<User?> _user = Rx<User?>(null);
  User? get user => _user.value;

  final RxBool _isLoading = false.obs;
  bool get isLoading => _isLoading.value;

  final RxString _errorMessage = ''.obs;
  String get errorMessage => _errorMessage.value;

  Future<void> signInWithGoogle() async {
    try {
      _isLoading.value = true;
      _errorMessage.value = '';

      final user = await _signInWithGoogleUseCase.call();

      if (user != null) {
        _user.value = user;
        Get.offAllNamed('/');
      } else {
        _errorMessage.value = 'Google sign-in failed. Please try again.';
      }
    } catch (e) {
      _errorMessage.value = _messageFor(e);
    } finally {
      _isLoading.value = false;
    }
  }

  Future<void> signInWithEmail(String email, String password) async =>
      _runAuth(() => _authRepository.signInWithEmail(email, password));

  Future<void> signUpWithEmail(
    String name,
    String email,
    String password,
  ) async =>
      _runAuth(() => _authRepository.signUpWithEmail(name, email, password));

  Future<void> sendPasswordResetOtp(String email) async {
    _isLoading.value = true;
    _errorMessage.value = '';
    try {
      await _authRepository.sendPasswordResetOtp(email);
    } catch (e) {
      _errorMessage.value = _messageFor(e);
      rethrow;
    } finally {
      _isLoading.value = false;
    }
  }

  Future<void> resetPasswordWithOtp({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    _isLoading.value = true;
    _errorMessage.value = '';
    try {
      await _authRepository.resetPasswordWithOtp(
        email: email,
        otp: otp,
        newPassword: newPassword,
      );
    } catch (e) {
      _errorMessage.value = _messageFor(e);
      rethrow;
    } finally {
      _isLoading.value = false;
    }
  }

  Future<void> _runAuth(Future<User?> Function() action) async {
    _isLoading.value = true;
    _errorMessage.value = '';
    try {
      final user = await action();
      if (user == null) {
        throw StateError('Unable to create a signed-in session.');
      }
      _user.value = user;
      Get.offAllNamed('/');
    } catch (e) {
      _errorMessage.value = _messageFor(e);
    } finally {
      _isLoading.value = false;
    }
  }

  String _messageFor(Object error) {
    if (error is firebase_auth.FirebaseAuthException) {
      return switch (error.code) {
        'invalid-email' => 'Enter a valid email address.',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' => 'Email or password is incorrect.',
        'email-already-in-use' => 'An account already exists for this email.',
        'weak-password' => 'Choose a password with at least 6 characters.',
        'network-request-failed' =>
          'Check your internet connection and try again.',
        _ => error.message ?? 'Authentication failed. Please try again.',
      };
    }
    return error is StateError
        ? error.message.toString()
        : 'Request failed. Please try again.';
  }

  void clearError() {
    _errorMessage.value = '';
  }
}
