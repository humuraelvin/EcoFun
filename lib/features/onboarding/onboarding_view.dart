import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart' hide Trans;

import '../../app/app_prefs.dart';
import '../../app/routes.dart';
import '../../app/session_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/language.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/pressable.dart';
import '../../data/supa.dart';

/// First launch: choose the language (used for everything, forever, until changed in settings),
/// then a short tour of EcoFun in that language.
class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final _pages = PageController();
  int _page = 0;
  String? _chosen;

  static const _tour = [
    (CupertinoIcons.book_fill, Color(0xFF0A84FF), 'onboarding.learnTitle', 'onboarding.learnBody'),
    (CupertinoIcons.viewfinder, Color(0xFF0C9F5C), 'onboarding.scanTitle', 'onboarding.scanBody'),
    (CupertinoIcons.person_2_fill, Color(0xFFFF9500), 'onboarding.communityTitle', 'onboarding.communityBody'),
  ];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _choose(String code) async {
    HapticFeedback.selectionClick();
    setState(() => _chosen = code);
    await applyLanguage(context, code);
    await Future<void>.delayed(const Duration(milliseconds: 220));
    _next();
  }

  void _next() {
    if (_page < _tour.length) {
      _pages.nextPage(duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    HapticFeedback.mediumImpact();
    await AppPrefs.setOnboarded();
    if (supa.auth.currentSession != null) {
      await SessionController.to.enterApp();
    } else {
      Get.offAllNamed(Routes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(children: [
          SizedBox(
            height: 48,
            child: _page == 0
                ? null
                : Row(children: [
                    IconButton(
                      onPressed: () => _pages.previousPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOut),
                      icon: Icon(CupertinoIcons.back, color: c.brand),
                    ),
                    const Spacer(),
                    TextButton(onPressed: _finish, child: Text('onboarding.skip'.tr(), style: AppText.body.c(c.secondaryLabel))),
                    const SizedBox(width: 8),
                  ]),
          ),
          Expanded(
            child: PageView(
              controller: _pages,
              // the language must be chosen first; after that members can swipe
              physics: _chosen == null ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
              onPageChanged: (i) => setState(() => _page = i),
              children: [
                _languagePage(c),
                for (final (icon, color, title, body) in _tour) _tourPage(c, icon, color, title.tr(), body.tr()),
              ],
            ),
          ),
          if (_page > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var i = 1; i <= _tour.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _page ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _page ? c.brand : c.fill,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ]),
                const SizedBox(height: 18),
                AppButton(
                  label: _page == _tour.length ? 'onboarding.start'.tr() : 'onboarding.next'.tr(),
                  onPressed: _next,
                ),
              ]),
            ),
        ]),
      ),
    );
  }

  /// Shown before any language is set, so it speaks both.
  Widget _languagePage(AppColors c) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(children: [
          const Spacer(flex: 2),
          SvgPicture.asset('assets/icons/logo.svg', height: 84),
          const SizedBox(height: 14),
          Text('EcoFun', style: AppText.wordmark.c(c.brand)),
          const SizedBox(height: 26),
          Text('Murakaza neza!', textAlign: TextAlign.center, style: AppText.title2.c(c.label)),
          const SizedBox(height: 2),
          Text('Welcome!', textAlign: TextAlign.center, style: AppText.title3.c(c.secondaryLabel)),
          const SizedBox(height: 18),
          Text('Hitamo ururimi', textAlign: TextAlign.center, style: AppText.headline.c(c.label)),
          Text('Choose your language', textAlign: TextAlign.center, style: AppText.subhead.c(c.secondaryLabel)),
          const SizedBox(height: 22),
          _LanguageCard(
            flag: '🇷🇼',
            label: 'Ikinyarwanda',
            hint: 'Porogaramu yose mu Kinyarwanda',
            selected: _chosen == 'rw',
            onTap: () => _choose('rw'),
          ),
          const SizedBox(height: 12),
          _LanguageCard(
            flag: '🇬🇧',
            label: 'English',
            hint: 'The whole app in English',
            selected: _chosen == 'en',
            onTap: () => _choose('en'),
          ),
          const Spacer(flex: 3),
          Text('Ushobora kuruhindura igihe cyose muri Igenamiterere.\nYou can change it any time in Settings.',
              textAlign: TextAlign.center, style: AppText.caption.c(c.tertiaryLabel)),
          const SizedBox(height: 16),
        ]),
      );

  Widget _tourPage(AppColors c, IconData icon, Color color, String title, String body) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
            child: Icon(icon, size: 70, color: color),
          ),
          const SizedBox(height: 34),
          Text(title, textAlign: TextAlign.center, style: AppText.title1.c(c.label)),
          const SizedBox(height: 12),
          Text(body, textAlign: TextAlign.center, style: AppText.body.c(c.secondaryLabel)),
        ]),
      );
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({required this.flag, required this.label, required this.hint, required this.selected, required this.onTap});
  final String flag;
  final String label;
  final String hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? c.brandSoft : c.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? c.brand : c.separator, width: selected ? 2 : 1),
        ),
        child: Row(children: [
          Text(flag, style: const TextStyle(fontSize: 34)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: AppText.title3.c(c.label)),
              Text(hint, style: AppText.footnote.c(c.secondaryLabel)),
            ]),
          ),
          Icon(selected ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.chevron_right,
              color: selected ? c.brand : c.tertiaryLabel),
        ]),
      ),
    );
  }
}
