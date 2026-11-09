import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Trans;

import '../../app/routes.dart';
import '../../app/session_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/fields.dart';
import '../../core/widgets/toast.dart';
import '../../data/auth_repository.dart';
import '../../data/supa.dart';

/// Two steps: email → 6-digit code from the email + new password.
class ResetPasswordView extends StatefulWidget {
  const ResetPasswordView({super.key});

  @override
  State<ResetPasswordView> createState() => _ResetPasswordViewState();
}

class _ResetPasswordViewState extends State<ResetPasswordView> {
  late final _email = TextEditingController(text: (Get.arguments as String?) ?? '');
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _sent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final email = _email.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return setState(() => _error = 'auth.invalidEmail'.tr());
    }
    if (_sent && _code.text.trim().length < 6) return setState(() => _error = 'auth.enterCode'.tr());
    if (_sent && _password.text.length < 6) return setState(() => _error = 'errors.weakPassword'.tr());

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!_sent) {
        await AuthRepository.sendResetCode(email);
        if (mounted) setState(() => _sent = true);
      } else {
        await AuthRepository.resetPassword(email, _code.text, _password.text);
        showToast('auth.passwordUpdated'.tr());
        Get.offAllNamed(Routes.shell);
        SessionController.to.start();
      }
    } catch (e) {
      HapticFeedback.heavyImpact();
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(
        leading: CupertinoNavigationBarBackButton(color: c.brand, onPressed: Get.back),
        title: Text('auth.resetTitle'.tr()),
      ),
      body: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            Icon(_sent ? CupertinoIcons.envelope_badge_fill : CupertinoIcons.lock_rotation, size: 46, color: c.brand),
            const SizedBox(height: 16),
            Text(
              _sent ? 'auth.resetCodeSent'.tr(args: [_email.text.trim()]) : 'auth.resetIntro'.tr(),
              textAlign: TextAlign.center,
              style: AppText.callout.c(c.secondaryLabel),
            ),
            const SizedBox(height: 22),
            AppTextField(
              key: const ValueKey('email'),
              controller: _email,
              placeholder: 'auth.email'.tr(),
              icon: CupertinoIcons.mail,
              keyboardType: TextInputType.emailAddress,
            ),
            if (_sent) ...[
              const SizedBox(height: 10),
              AppTextField(
                key: const ValueKey('code'),
                controller: _code,
                placeholder: 'auth.code'.tr(),
                icon: CupertinoIcons.number,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
              ),
              const SizedBox(height: 10),
              AppTextField(
                key: const ValueKey('password'),
                controller: _password,
                placeholder: 'auth.newPassword'.tr(),
                icon: CupertinoIcons.lock,
                obscure: true,
                onSubmitted: (_) => _submit(),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: AppText.subhead.c(c.danger)),
            ],
            const SizedBox(height: 20),
            AppButton(
              label: _sent ? 'auth.resetPassword'.tr() : 'auth.sendCode'.tr(),
              loading: _busy,
              onPressed: _submit,
            ),
            if (_sent)
              Center(
                child: TextLink('auth.resendCode'.tr(), onTap: () {
                  setState(() => _sent = false);
                  _submit();
                }),
              ),
          ],
        ),
      ),
    );
  }
}
