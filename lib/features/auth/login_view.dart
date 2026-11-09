import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart' hide Trans;
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../app/routes.dart';
import '../../app/session_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/fields.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/toast.dart';
import '../../data/auth_repository.dart';
import '../../data/supa.dart';

enum _Mode { signIn, signUp, confirm }

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  _Mode _mode = _Mode.signIn;
  bool _busy = false;
  bool _googleBusy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  void _setMode(_Mode m) {
    HapticFeedback.selectionClick();
    setState(() {
      _mode = m;
      _error = null;
    });
  }

  /// Opens the member app, or the admin portal for admins.
  Future<void> _enterApp() => SessionController.to.enterApp();

  Future<void> _run(Future<void> Function() action) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
      HapticFeedback.heavyImpact();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _validEmail(String v) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim());

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (_mode == _Mode.confirm) {
      if (_code.text.trim().length < 6) return setState(() => _error = 'auth.enterCode'.tr());
      return _run(() async {
        await AuthRepository.verifySignUpCode(email, _code.text);
        await _enterApp();
      });
    }
    if (!_validEmail(email)) return setState(() => _error = 'auth.invalidEmail'.tr());
    if (_password.text.length < 6) return setState(() => _error = 'errors.weakPassword'.tr());

    if (_mode == _Mode.signIn) {
      return _run(() async {
        try {
          await AuthRepository.signIn(email, _password.text);
        } on AuthException catch (e) {
          // Signed up earlier but never entered the code: send a fresh code and ask for it.
          if (e.message.toLowerCase().contains('email not confirmed')) {
            await AuthRepository.resendConfirmation(email);
            if (mounted) setState(() => _mode = _Mode.confirm);
            return;
          }
          rethrow;
        }
        await _enterApp();
      });
    }
    if (_name.text.trim().length < 2) return setState(() => _error = 'auth.enterName'.tr());
    return _run(() async {
      final outcome = await AuthRepository.signUp(_name.text, email, _password.text, lang: context.locale.languageCode);
      if (outcome == SignUpOutcome.signedIn) {
        await _enterApp();
      } else if (mounted) {
        setState(() => _mode = _Mode.confirm);
      }
    });
  }

  Future<void> _google() async {
    setState(() {
      _googleBusy = true;
      _error = null;
    });
    try {
      if (await AuthRepository.signInWithGoogle()) await _enterApp();
    } catch (e) {
      if (mounted) setState(() => _error = 'auth.googleFailed'.tr());
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _mode == _Mode.confirm ? _confirm(c) : _form(c),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _brand(AppColors c) => Column(
        children: [
          SvgPicture.asset('assets/icons/logo.svg', height: 74),
          const SizedBox(height: 14),
          Text('EcoFun', style: AppText.wordmark.c(c.brand)),
          const SizedBox(height: 8),
          Text('auth.tagline'.tr(), textAlign: TextAlign.center, style: AppText.callout.c(c.secondaryLabel)),
        ],
      );

  Widget _form(AppColors c) {
    final signUp = _mode == _Mode.signUp;
    return Column(
      key: const ValueKey('form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _brand(c),
        const SizedBox(height: 30),
        CupertinoSlidingSegmentedControl<_Mode>(
          groupValue: _mode,
          backgroundColor: c.fill,
          thumbColor: c.surface,
          padding: const EdgeInsets.all(3),
          children: {
            _Mode.signIn: _segment('auth.signIn'.tr()),
            _Mode.signUp: _segment('auth.createAccount'.tr()),
          },
          onValueChanged: (m) => _setMode(m ?? _Mode.signIn),
        ),
        const SizedBox(height: 18),
        if (signUp) ...[
          AppTextField(
            key: const ValueKey('name'),
            controller: _name,
            placeholder: 'auth.fullName'.tr(),
            icon: CupertinoIcons.person,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 10),
        ],
        AppTextField(
          key: const ValueKey('email'),
          controller: _email,
          placeholder: 'auth.email'.tr(),
          icon: CupertinoIcons.mail,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 10),
        AppTextField(
          key: const ValueKey('password'),
          controller: _password,
          placeholder: 'auth.password'.tr(),
          icon: CupertinoIcons.lock,
          obscure: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
        _errorText(c),
        const SizedBox(height: 18),
        AppButton(
          label: signUp ? 'auth.createAccount'.tr() : 'auth.signIn'.tr(),
          loading: _busy,
          onPressed: _submit,
        ),
        if (!signUp)
          Center(
            child: TextLink('auth.forgot'.tr(), onTap: () => Get.toNamed(Routes.reset, arguments: _email.text.trim())),
          ),
        if (AuthRepository.googleEnabled) ...[
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Divider(color: c.separator)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('auth.or'.tr(), style: AppText.footnote.c(c.tertiaryLabel)),
            ),
            Expanded(child: Divider(color: c.separator)),
          ]),
          const SizedBox(height: 12),
          _googleButton(c),
        ],
        const SizedBox(height: 24),
        Text('auth.terms'.tr(), textAlign: TextAlign.center, style: AppText.caption.c(c.tertiaryLabel)),
      ],
    );
  }

  Widget _segment(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Text(text, style: AppText.subhead.semibold),
      );

  Widget _errorText(AppColors c) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _error == null
            ? const SizedBox(width: double.infinity)
            : Padding(
                key: ValueKey(_error),
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(CupertinoIcons.exclamationmark_circle_fill, size: 17, color: c.danger),
                    const SizedBox(width: 6),
                    Expanded(child: Text(_error!, style: AppText.subhead.c(c.danger))),
                  ],
                ),
              ),
      );

  Widget _googleButton(AppColors c) => Pressable(
        onTap: _googleBusy ? null : _google,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: c.separator),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_googleBusy)
                const CupertinoActivityIndicator()
              else ...[
                SvgPicture.asset('assets/icons/google.svg', width: 19, height: 19),
                const SizedBox(width: 10),
                Text('auth.google'.tr(), style: AppText.headline.c(c.label)),
              ],
            ],
          ),
        ),
      );

  Widget _confirm(AppColors c) => Column(
        key: const ValueKey('confirm'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 76,
            height: 76,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.brandSoft, shape: BoxShape.circle),
            child: Icon(CupertinoIcons.envelope_open_fill, size: 34, color: c.brand),
          ),
          const SizedBox(height: 20),
          Text('auth.checkEmail'.tr(), textAlign: TextAlign.center, style: AppText.title2.c(c.label)),
          const SizedBox(height: 8),
          Text(
            'auth.checkEmailBody'.tr(args: [_email.text.trim()]),
            textAlign: TextAlign.center,
            style: AppText.callout.c(c.secondaryLabel),
          ),
          const SizedBox(height: 22),
          AppTextField(
            key: const ValueKey('code'),
            controller: _code,
            placeholder: 'auth.code'.tr(),
            icon: CupertinoIcons.number,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
            onSubmitted: (_) => _submit(),
          ),
          _errorText(c),
          const SizedBox(height: 16),
          AppButton(label: 'auth.verify'.tr(), loading: _busy, onPressed: _submit),
          const SizedBox(height: 10),
          AppButton(
            label: 'auth.confirmedSignIn'.tr(),
            kind: ButtonStyleKind.tinted,
            onPressed: _busy
                ? null
                : () => _run(() async {
                      await AuthRepository.signIn(_email.text.trim(), _password.text);
                      await _enterApp();
                    }),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextLink('auth.resend'.tr(), onTap: () async {
                try {
                  await AuthRepository.resendConfirmation(_email.text.trim());
                  showToast('auth.resent'.tr());
                } catch (e) {
                  showToast(friendlyError(e), error: true);
                }
              }),
              Text('·', style: AppText.callout.c(c.tertiaryLabel)),
              TextLink('auth.back'.tr(), color: c.secondaryLabel, onTap: () => _setMode(_Mode.signUp)),
            ],
          ),
        ],
      );
}
