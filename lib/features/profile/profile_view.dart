import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Trans;

import '../../app/routes.dart';
import '../../app/session_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/format.dart';
import '../../core/utils/image_utils.dart';
import '../../core/utils/photo_picker.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/fields.dart';
import '../../core/widgets/large_title_page.dart';
import '../../core/widgets/photos.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/toast.dart';
import '../../data/auth_repository.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../data/supa.dart';
import '../history/history_view.dart';
import '../shell/shell_view.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final session = SessionController.to;
  List<MissionCompletion>? _recent;
  bool _uploading = false;
  bool _emailUpdates = AuthRepository.emailUpdates;
  Worker? _worker;
  int? _missions;

  @override
  void initState() {
    super.initState();
    _loadRecent();
    // Refresh the journey preview whenever a new mission is completed.
    _worker = ever<HomeData?>(session.home, (h) {
      final n = h?.stats.missions;
      if (n != null && _missions != null && n != _missions) _loadRecent();
      _missions = n;
    });
  }

  @override
  void dispose() {
    _worker?.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    try {
      final list = await MissionRepository.history(limit: 3);
      if (mounted) setState(() => _recent = list);
    } catch (_) {
      if (mounted) setState(() => _recent = const []);
    }
  }

  Future<void> _setEmailUpdates(bool on) async {
    setState(() => _emailUpdates = on);
    try {
      await AuthRepository.setEmailUpdates(on);
      showToast(on ? 'profile.emailUpdatesOn'.tr() : 'profile.emailUpdatesOff'.tr());
    } catch (e) {
      if (mounted) setState(() => _emailUpdates = !on);
      showToast(friendlyError(e), error: true);
    }
  }

  Future<void> _refresh() => Future.wait([session.refreshHome(), _loadRecent()]);

  Future<void> _changePhoto() async {
    final path = await pickPhoto(context);
    if (path == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await ImageUtils.compressForUpload(path, side: 400, quality: 80);
      await ProfileRepository.setAvatar(bytes);
      await session.refreshHome();
      showToast('profile.photoUpdated'.tr());
    } catch (e) {
      showToast(friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _rename(Profile p) async {
    final ctrl = TextEditingController(text: p.fullName);
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.viewInsetsOf(ctx).bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('profile.editName'.tr(), textAlign: TextAlign.center, style: AppText.headline),
          const SizedBox(height: 14),
          AppTextField(
            controller: ctrl,
            placeholder: 'auth.fullName'.tr(),
            autofocus: true,
            maxLength: 80,
            textCapitalization: TextCapitalization.words,
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
          const SizedBox(height: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: Text('common.save'.tr(), style: AppText.headline),
          ),
        ]),
      ),
    );
    ctrl.dispose();
    if (name == null || name.trim().length < 2 || name.trim() == p.fullName) return;
    try {
      await ProfileRepository.rename(name);
      await session.refreshHome();
      showToast('profile.nameUpdated'.tr());
    } catch (e) {
      showToast(friendlyError(e), error: true);
    }
  }

  void _language() {
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
              for (final (code, country, label, flag) in const [
                ('en', 'US', 'English', '🇬🇧'),
                ('rw', 'RW', 'Ikinyarwanda', '🇷🇼'),
              ])
                GroupedRow(
                  icon: CupertinoIcons.globe,
                  title: '$flag  $label',
                  showChevron: false,
                  trailing: current == code ? Icon(CupertinoIcons.checkmark_alt, color: context.colors.brand) : null,
                  onTap: () async {
                    Navigator.pop(ctx);
                    if (current == code) return;
                    final locale = Locale(code, country);
                    await context.setLocale(locale);
                    Get.updateLocale(locale);
                    session.language.value = code;
                    session.refreshHome();
                  },
                ),
            ]),
          ]),
        ),
      ),
    );
  }

  Future<void> _confirm({
    required String title,
    required String message,
    required String action,
    required Future<void> Function() onConfirm,
  }) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx, false), child: Text('common.cancel'.tr())),
          CupertinoDialogAction(isDestructiveAction: true, onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
        ],
      ),
    );
    if (ok == true) await onConfirm();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LargeTitlePage(
      title: 'tabs.profile'.tr(),
      controller: ShellController.to.scrollers[4],
      onRefresh: _refresh,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(
            child: Obx(() {
              final h = session.home.value;
              if (h == null) {
                return session.error.value != null
                    ? AppCard(child: MessageView.error(session.error.value!, onRetry: session.refreshHome))
                    : const SkeletonPulse(child: SkeletonBox(height: 180, radius: 20));
              }
              return Column(children: [
                _header(c, h),
                const SizedBox(height: 12),
                _stats(c, h),
              ]);
            }),
          ),
        ),
        SliverToBoxAdapter(
          child: SectionHeader('profile.journey'.tr(), action: 'common.seeAll'.tr(), onAction: () => Get.toNamed(Routes.history)),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(
            child: _recent == null
                ? const SkeletonPulse(child: SkeletonBox(height: 96, radius: 18))
                : _recent!.isEmpty
                    ? AppCard(
                        child: Row(children: [
                          Icon(CupertinoIcons.leaf_arrow_circlepath, color: c.brand),
                          const SizedBox(width: 12),
                          Expanded(child: Text('profile.noJourney'.tr(), style: AppText.subhead.c(c.secondaryLabel))),
                        ]),
                      )
                    : Column(children: [
                        for (final m in _recent!) Padding(padding: const EdgeInsets.only(bottom: 10), child: HistoryRow(item: m)),
                      ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          sliver: SliverToBoxAdapter(
            child: Column(children: [
              GroupedSection(children: [
                GroupedRow(
                  icon: CupertinoIcons.viewfinder,
                  title: 'scan.myScans'.tr(),
                  onTap: () => Get.toNamed(Routes.scans),
                ),
                GroupedRow(
                  icon: CupertinoIcons.calendar,
                  iconColor: const Color(0xFFFF8A00),
                  title: 'history.title'.tr(),
                  onTap: () => Get.toNamed(Routes.history),
                ),
                GroupedRow(
                  icon: CupertinoIcons.globe,
                  iconColor: const Color(0xFF0A84FF),
                  title: 'profile.language'.tr(),
                  value: context.locale.languageCode == 'rw' ? 'Ikinyarwanda' : 'English',
                  onTap: _language,
                ),
                GroupedRow(
                  icon: CupertinoIcons.envelope_fill,
                  iconColor: const Color(0xFFFF375F),
                  title: 'profile.emailUpdates'.tr(),
                  showChevron: false,
                  trailing: CupertinoSwitch(
                    value: _emailUpdates,
                    activeTrackColor: c.brand,
                    onChanged: _setEmailUpdates,
                  ),
                  onTap: () => _setEmailUpdates(!_emailUpdates),
                ),
                Obx(() => session.profile?.isAdmin == true
                    ? GroupedRow(
                        icon: CupertinoIcons.shield_lefthalf_fill,
                        iconColor: const Color(0xFF8E5CF7),
                        title: 'admin.portal'.tr(),
                        onTap: () => Get.toNamed(Routes.admin),
                      )
                    : const SizedBox.shrink()),
              ]),
              const SizedBox(height: 18),
              GroupedSection(
                footer: 'profile.about'.tr(),
                children: [
                  GroupedRow(
                    icon: CupertinoIcons.square_arrow_right,
                    title: 'profile.signOut'.tr(),
                    destructive: true,
                    showChevron: false,
                    onTap: () => _confirm(
                      title: 'profile.signOut'.tr(),
                      message: 'profile.signOutConfirm'.tr(),
                      action: 'profile.signOut'.tr(),
                      onConfirm: session.signOut,
                    ),
                  ),
                  GroupedRow(
                    icon: CupertinoIcons.delete,
                    title: 'profile.deleteAccount'.tr(),
                    destructive: true,
                    showChevron: false,
                    onTap: () => _confirm(
                      title: 'profile.deleteAccount'.tr(),
                      message: 'profile.deleteConfirm'.tr(),
                      action: 'profile.delete'.tr(),
                      onConfirm: () async {
                        try {
                          await ProfileRepository.deleteAccount();
                          await session.signOut();
                        } catch (e) {
                          showToast(friendlyError(e), error: true);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _header(AppColors c, HomeData h) {
    final p = h.profile;
    final email = supa.auth.currentUser?.email ?? '';
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Row(children: [
        Pressable(
          onTap: _uploading ? null : _changePhoto,
          child: Stack(clipBehavior: Clip.none, children: [
            Avatar(name: p.fullName, url: p.avatarUrl, size: 72),
            if (_uploading)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), shape: BoxShape.circle),
                  child: const CupertinoActivityIndicator(color: Colors.white),
                ),
              ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(color: c.brand, shape: BoxShape.circle, border: Border.all(color: c.surface, width: 2)),
                child: Icon(CupertinoIcons.camera_fill, size: 13, color: c.onBrand),
              ),
            ),
          ]),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Pressable(
              onTap: () => _rename(p),
              child: Row(children: [
                Flexible(child: Text(p.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.title3.c(c.label))),
                const SizedBox(width: 6),
                Icon(CupertinoIcons.pencil, size: 16, color: c.tertiaryLabel),
              ]),
            ),
            const SizedBox(height: 2),
            Text(email, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.footnote.c(c.secondaryLabel)),
            const SizedBox(height: 10),
            Row(children: [
              Pill(label: '${Fmt.points(p.points)} ${'common.pts'.tr()}', icon: CupertinoIcons.star_fill),
              const SizedBox(width: 8),
              Pill(label: 'home.streakDays'.plural(h.streak), icon: CupertinoIcons.flame_fill, color: const Color(0xFFE07000)),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _stats(AppColors c, HomeData h) {
    final items = [
      (CupertinoIcons.leaf_arrow_circlepath, '${h.stats.missions}', 'profile.missions'.tr(), c.brand),
      (CupertinoIcons.viewfinder, '${h.stats.scans}', 'profile.scans'.tr(), const Color(0xFF0A84FF)),
      (CupertinoIcons.question_circle, '${h.stats.quizzes}', 'profile.quizzes'.tr(), const Color(0xFF8E5CF7)),
      (CupertinoIcons.book, '${h.stats.articles}', 'profile.stories'.tr(), const Color(0xFFFF8A00)),
    ];
    return Row(children: [
      for (var i = 0; i < items.length; i++) ...[
        Expanded(
          child: AppCard(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            radius: 18,
            child: Column(children: [
              Icon(items[i].$1, color: items[i].$4, size: 20),
              const SizedBox(height: 6),
              Text(items[i].$2, style: AppText.title3.bold.c(c.label)),
              Text(items[i].$3, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption.c(c.secondaryLabel)),
            ]),
          ),
        ),
        if (i < items.length - 1) const SizedBox(width: 8),
      ],
    ]);
  }
}

