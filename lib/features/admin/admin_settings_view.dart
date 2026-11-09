import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Trans;

import '../../app/routes.dart';
import '../../app/session_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/language.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/large_title_page.dart';
import '../../core/widgets/photos.dart';
import '../../data/supa.dart';

class AdminSettingsView extends StatelessWidget {
  const AdminSettingsView({super.key});

  void _language(BuildContext context) {
    final current = context.locale.languageCode;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('profile.language'.tr(), style: AppText.headline),
            const SizedBox(height: 14),
            GroupedSection(children: [
              for (final (code, _, label, flag) in const [('en', 'US', 'English', '🇬🇧'), ('rw', 'RW', 'Ikinyarwanda', '🇷🇼')])
                GroupedRow(
                  icon: CupertinoIcons.globe,
                  title: '$flag  $label',
                  showChevron: false,
                  trailing: current == code ? Icon(CupertinoIcons.checkmark_alt, color: context.colors.brand) : null,
                  onTap: () async {
                    Navigator.pop(ctx);
                    if (current == code) return;
                    await applyLanguage(context, code);
                  },
                ),
            ]),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final session = SessionController.to;
    final email = supa.auth.currentUser?.email ?? '';
    return LargeTitlePage(
      title: 'admin.settings'.tr(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.list(children: [
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Obx(() => Avatar(name: session.profile?.fullName ?? 'Admin', url: session.profile?.avatarUrl, size: 56)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Obx(() => Text(session.profile?.fullName ?? 'EcoFun Admin', style: AppText.title3.c(c.label))),
                    Text(email, style: AppText.footnote.c(c.secondaryLabel)),
                    const SizedBox(height: 4),
                    Text('admin.roleLine'.tr(), style: AppText.caption.semibold.c(const Color(0xFF8E5CF7))),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 18),
            GroupedSection(children: [
              GroupedRow(
                icon: CupertinoIcons.bell_fill,
                iconColor: const Color(0xFFFF9500),
                title: 'notif.title'.tr(),
                onTap: () => Get.toNamed(Routes.notifications),
              ),
              GroupedRow(
                icon: CupertinoIcons.globe,
                iconColor: const Color(0xFF0A84FF),
                title: 'profile.language'.tr(),
                value: context.locale.languageCode == 'rw' ? 'Ikinyarwanda' : 'English',
                onTap: () => _language(context),
              ),
              GroupedRow(
                icon: CupertinoIcons.device_phone_portrait,
                iconColor: c.brand,
                title: 'admin.previewApp'.tr(),
                onTap: () => Get.toNamed(Routes.shell),
              ),
            ]),
            const SizedBox(height: 18),
            GroupedSection(
              footer: 'admin.settingsFooter'.tr(),
              children: [
                GroupedRow(
                  icon: CupertinoIcons.square_arrow_right,
                  title: 'profile.signOut'.tr(),
                  destructive: true,
                  showChevron: false,
                  onTap: () async {
                    final ok = await showCupertinoDialog<bool>(
                      context: context,
                      builder: (ctx) => CupertinoAlertDialog(
                        title: Text('profile.signOut'.tr()),
                        content: Text('profile.signOutConfirm'.tr()),
                        actions: [
                          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx, false), child: Text('common.cancel'.tr())),
                          CupertinoDialogAction(isDestructiveAction: true, onPressed: () => Navigator.pop(ctx, true),
                              child: Text('profile.signOut'.tr())),
                        ],
                      ),
                    );
                    if (ok == true) await session.signOut();
                  },
                ),
              ],
            ),
          ]),
        ),
      ],
    );
  }
}
