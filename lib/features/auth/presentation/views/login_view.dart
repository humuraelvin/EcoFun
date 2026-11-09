import 'package:eco_step/core/util/style/colors.dart';
import 'package:eco_step/core/util/style/typography.dart';
import 'package:eco_step/core/widgets/common/google_sign_in_button.dart';
import 'package:eco_step/features/auth/presentation/viewmodels/login_viewmodel.dart';
import 'package:eco_step/gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

enum _AuthMode { signIn, signUp, forgotPassword }

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _email = TextEditingController();
  final _fullName = TextEditingController();
  final _password = TextEditingController();
  final _otp = TextEditingController();
  _AuthMode _mode = _AuthMode.signIn;
  bool _otpSent = false;

  @override
  void dispose() {
    _email.dispose();
    _fullName.dispose();
    _password.dispose();
    _otp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ThemeColors.of(context);
    final viewModel = Get.find<LoginViewModel>();
    final isForgot = _mode == _AuthMode.forgotPassword;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLogo(context, colors),
                  const SizedBox(height: 36),
                  Text(
                    isForgot
                        ? 'Reset your password'
                        : _mode == _AuthMode.signUp
                        ? 'Create your account'
                        : 'Welcome to Eco Step',
                    style: Typo.headingStrong(context, color: colors.gray900),
                  ),
                  const SizedBox(height: 24),
                  _field(
                    context,
                    'Email',
                    _email,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  if (_mode == _AuthMode.signUp) ...[
                    const SizedBox(height: 12),
                    _field(context, 'Full name', _fullName),
                  ],
                  if (!isForgot) ...[
                    const SizedBox(height: 12),
                    _field(context, 'Password', _password, obscureText: true),
                  ],
                  if (isForgot && _otpSent) ...[
                    const SizedBox(height: 12),
                    _field(
                      context,
                      'Email code',
                      _otp,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    _field(
                      context,
                      'New password',
                      _password,
                      obscureText: true,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Obx(
                    () => SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: viewModel.isLoading ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.primary,
                          foregroundColor: colors.gray900,
                        ),
                        child: viewModel.isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(_buttonLabel),
                      ),
                    ),
                  ),
                  if (_mode == _AuthMode.signIn) ...[
                    const SizedBox(height: 14),
                    Obx(
                      () => GoogleSignInButton(
                        onTap: viewModel.signInWithGoogle,
                        isLoading: viewModel.isLoading,
                      ),
                    ),
                  ],
                  Obx(
                    () => viewModel.errorMessage.isEmpty
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: Text(
                              viewModel.errorMessage,
                              textAlign: TextAlign.center,
                              style: Typo.labelRegular(
                                context,
                                color: colors.negative,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 6,
                    children: [
                      if (_mode == _AuthMode.signIn) ...[
                        TextButton(
                          onPressed: () {
                            _password.clear();
                            _otp.clear();
                            setState(() {
                              _mode = _AuthMode.forgotPassword;
                              _otpSent = false;
                            });
                          },
                          child: const Text('Forgot password?'),
                        ),
                        TextButton(
                          onPressed: () {
                            _password.clear();
                            setState(() => _mode = _AuthMode.signUp);
                          },
                          child: const Text('Create account'),
                        ),
                      ] else
                        TextButton(
                          onPressed: () {
                            _password.clear();
                            _otp.clear();
                            setState(() {
                              _mode = _AuthMode.signIn;
                              _otpSent = false;
                            });
                          },
                          child: const Text('Back to sign in'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _buttonLabel {
    if (_mode == _AuthMode.signUp) return 'Sign up';
    if (_mode == _AuthMode.forgotPassword) {
      return _otpSent ? 'Reset password' : 'Send code';
    }
    return 'Sign in';
  }

  Future<void> _submit() async {
    final viewModel = Get.find<LoginViewModel>();
    final email = _email.text.trim();
    final password = _password.text;
    if (!email.contains('@')) {
      Get.snackbar('Check your email', 'Enter a valid email address.');
      return;
    }
    if (_mode == _AuthMode.signIn) {
      await viewModel.signInWithEmail(email, password);
    } else if (_mode == _AuthMode.signUp) {
      if (_fullName.text.trim().length < 2) {
        Get.snackbar(
          'Add your name',
          'Enter your full name to create a profile.',
        );
        return;
      }
      await viewModel.signUpWithEmail(_fullName.text.trim(), email, password);
    } else if (!_otpSent) {
      try {
        await viewModel.sendPasswordResetOtp(email);
        if (mounted) {
          setState(() => _otpSent = true);
        }
        Get.snackbar(
          'Check your inbox',
          'If the account exists, a code has been sent.',
        );
      } catch (_) {
        // The view model exposes the actionable error.
      }
    } else {
      if (_otp.text.trim().length != 6 || password.length < 6) {
        Get.snackbar(
          'Check the form',
          'Enter the six-digit code and a password of at least 6 characters.',
        );
        return;
      }
      try {
        await viewModel.resetPasswordWithOtp(
          email: email,
          otp: _otp.text,
          newPassword: password,
        );
        if (mounted) {
          setState(() {
            _mode = _AuthMode.signIn;
            _otpSent = false;
            _password.clear();
            _otp.clear();
          });
        }
        Get.snackbar('Password updated', 'Sign in with your new password.');
      } catch (_) {
        // The view model exposes the actionable error.
      }
    }
  }

  Widget _field(
    BuildContext context,
    String label,
    TextEditingController controller, {
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    final colors = ThemeColors.of(context);
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      autocorrect: false,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: colors.gray20,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildLogo(BuildContext context, ThemeColors colors) => Column(
    children: [
      SizedBox(
        width: 84,
        height: 94,
        child: SvgPicture.asset(Assets.icons.logo.path, fit: BoxFit.contain),
      ),
      const SizedBox(height: 10),
      Text('Eco Step', style: Typo.logo(context, color: colors.primary)),
    ],
  );
}
