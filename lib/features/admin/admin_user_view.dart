import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Trans;

import '../../app/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/fields.dart';
import '../../core/widgets/large_title_page.dart';
import '../../core/widgets/photos.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/toast.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../data/storage_service.dart';
import '../../data/supa.dart';
import 'admin_controller.dart';
import 'admin_widgets.dart';

/// Everything about one member, plus the admin actions: points, suspend, delete.
/// Argument: the member's id.
class AdminUserView extends StatefulWidget {
  const AdminUserView({super.key});

  @override
  State<AdminUserView> createState() => _AdminUserViewState();
}

class _AdminUserViewState extends State<AdminUserView> {
  late final String _id = Get.arguments as String;
  AdminUserDetail? _d;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await AdminRepository.user(_id);
      if (mounted) {
        setState(() {
          _d = d;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  void _changed() {
    if (Get.isRegistered<AdminController>()) AdminController.to.memberChanged();
  }

  Future<String?> _ask({required String title, required String message, required String action, bool destructive = false,
      String? placeholder, bool needText = false, bool numeric = false}) async {
    final ctrl = TextEditingController();
    final c = context.colors;
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.viewInsetsOf(ctx).bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, textAlign: TextAlign.center, style: AppText.headline.c(c.label)),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center, style: AppText.subhead.c(c.secondaryLabel)),
          if (placeholder != null) ...[
            const SizedBox(height: 14),
            AppTextField(
              controller: ctrl,
              placeholder: placeholder,
              autofocus: true,
              maxLength: numeric ? 5 : 200,
              keyboardType: numeric ? const TextInputType.numberWithOptions(signed: true) : TextInputType.text,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
          const SizedBox(height: 14),
          AppButton(
            label: action,
            kind: destructive ? ButtonStyleKind.danger : ButtonStyleKind.filled,
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          ),
          const SizedBox(height: 6),
          AppButton(label: 'common.cancel'.tr(), kind: ButtonStyleKind.plain, onPressed: () => Navigator.pop(ctx)),
        ]),
      ),
    );
    ctrl.dispose();
    if (result == null) return null;
    if (needText && result.length < 3) {
      showToast('errors.reason'.tr(), error: true);
      return null;
    }
    return result;
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      HapticFeedback.mediumImpact();
      showToast(done);
      _changed();
      await _load();
    } catch (e) {
      showToast(friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _points() async {
    final amount = await _ask(
      title: 'admin.pointsTitle'.tr(),
      message: 'admin.pointsMessage'.tr(),
      action: 'common.next'.tr(),
      placeholder: 'admin.pointsPlaceholder'.tr(),
      numeric: true,
    );
    final n = int.tryParse(amount ?? '');
    if (n == null || n == 0) {
      if (amount != null) showToast('errors.pointsRange'.tr(), error: true);
      return;
    }
    final reason = await _ask(
      title: n > 0 ? 'admin.giveN'.tr(args: ['$n']) : 'admin.removeN'.tr(args: ['${-n}']),
      message: 'admin.reasonMessage'.tr(),
      action: 'common.save'.tr(),
      placeholder: 'admin.reason'.tr(),
      needText: true,
    );
    if (reason == null) return;
    await _run(() => AdminRepository.adjustPoints(_id, n, reason), 'admin.pointsSaved'.tr());
  }

  Future<void> _suspend(AdminUser u) async {
    if (u.suspended) {
      return _run(() => AdminRepository.setSuspended(_id, false, ''), 'admin.unsuspended'.tr());
    }
    final reason = await _ask(
      title: 'admin.suspendTitle'.tr(args: [u.fullName]),
      message: 'admin.suspendMessage'.tr(),
      action: 'admin.suspend'.tr(),
      destructive: true,
      placeholder: 'admin.reason'.tr(),
    );
    if (reason == null) return;
    await _run(() => AdminRepository.setSuspended(_id, true, reason), 'admin.suspended'.tr());
  }

  Future<void> _delete(AdminUser u) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('admin.deleteTitle'.tr(args: [u.fullName])),
        content: Text('admin.deleteMessage'.tr()),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx, false), child: Text('common.cancel'.tr())),
          CupertinoDialogAction(isDestructiveAction: true, onPressed: () => Navigator.pop(ctx, true), child: Text('profile.delete'.tr())),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await AdminRepository.deleteUser(_id);
      _changed();
      Get.back();
      showToast('admin.deleted'.tr());
    } catch (e) {
      showToast(friendlyError(e), error: true);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = _d;
    return Scaffold(
      backgroundColor: c.background,
      appBar: appTopBar(context, title: 'admin.member'.tr()),
      body: d == null
          ? (_error != null ? MessageView.error(_error!, onRetry: _load) : const CenteredSpinner())
          : RefreshIndicator(
              color: c.brand,
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, 4, 16, MediaQuery.paddingOf(context).bottom + 28),
                children: [
                  _header(c, d),
                  const SizedBox(height: 14),
                  _actions(c, d.user),
                  SectionHeader('admin.activity'.tr(), padding: const EdgeInsets.fromLTRB(4, 22, 4, 8)),
                  StatGrid(children: [
                    StatTile(icon: CupertinoIcons.flame_fill, color: const Color(0xFFFF8A00), value: d.stats['streak'] ?? 0, label: 'admin.statStreak'.tr()),
                    StatTile(icon: CupertinoIcons.leaf_arrow_circlepath, color: c.bio, value: d.stats['missions'] ?? 0, label: 'admin.statMissions'.tr()),
                    StatTile(icon: CupertinoIcons.question_circle_fill, color: const Color(0xFF8E5CF7), value: d.stats['quizzes'] ?? 0,
                        label: 'admin.statQuizzes'.tr(), sub: 'admin.statCorrect'.tr(args: ['${d.stats['correct_answers'] ?? 0}'])),
                    StatTile(icon: CupertinoIcons.viewfinder, color: const Color(0xFF30B0C7), value: d.stats['scans'] ?? 0,
                        label: 'admin.statScans'.tr(), sub: 'admin.statDisposed'.tr(args: ['${d.stats['disposals'] ?? 0}'])),
                    StatTile(icon: CupertinoIcons.photo_fill, color: const Color(0xFF0A84FF), value: d.stats['posts'] ?? 0,
                        label: 'admin.statPosts'.tr(), sub: 'admin.statRatingsReceived'.tr(args: ['${d.stats['ratings_received'] ?? 0}'])),
                    StatTile(icon: CupertinoIcons.chat_bubble_2_fill, color: const Color(0xFF5856D6), value: d.stats['comments'] ?? 0,
                        label: 'admin.statComments'.tr(), sub: 'admin.statRatingsGiven'.tr(args: ['${d.stats['ratings_given'] ?? 0}'])),
                    StatTile(icon: CupertinoIcons.book_fill, color: const Color(0xFFFF2D55), value: d.stats['stories_read'] ?? 0,
                        label: 'admin.statStories'.tr()),
                    StatTile(icon: CupertinoIcons.star_fill, color: c.gold, value: d.user.points, label: 'admin.statPoints'.tr()),
                  ]),
                  if (d.points.isNotEmpty) ...[
                    SectionHeader('admin.pointsHistory'.tr(), padding: const EdgeInsets.fromLTRB(4, 22, 4, 8)),
                    GroupedSection(children: [for (final e in d.points) _PointRow(e: e)]),
                  ],
                  if (d.posts.isNotEmpty) ...[
                    SectionHeader('admin.sharedPhotos'.tr(), padding: const EdgeInsets.fromLTRB(4, 22, 4, 8)),
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      children: [
                        for (final p in d.posts)
                          Pressable(
                            onTap: () => Get.toNamed(Routes.post, arguments: p),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: NetPhoto(url: StorageService.instance.publicUrl(Bucket.community, p.imagePath)),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _header(AppColors c, AdminUserDetail d) {
    final u = d.user;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Row(children: [
          Avatar(name: u.fullName, url: u.avatarUrl, size: 64),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(u.fullName, style: AppText.title3.c(c.label)),
              const SizedBox(height: 2),
              SelectableText(u.email, style: AppText.footnote.c(c.secondaryLabel)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, children: [
                StatusPill(
                  label: u.suspended ? 'admin.badgeSuspended'.tr() : 'admin.badgeActive'.tr(),
                  color: u.suspended ? c.danger : c.bio,
                ),
                if (u.isAdmin) StatusPill(label: 'admin.badgeAdmin'.tr(), color: const Color(0xFF8E5CF7)),
                StatusPill(label: '${Fmt.points(u.points)} ${'common.pts'.tr()}', color: c.brand),
              ]),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Divider(color: c.separator, height: 1),
        const SizedBox(height: 10),
        _kv(c, 'admin.joinedOn'.tr(), Fmt.longDay(u.createdAt)),
        _kv(c, 'admin.lastSeen'.tr(), u.lastSeen == null ? '—' : Fmt.ago(u.lastSeen!)),
        if (u.suspended && (d.suspendedReason ?? '').isNotEmpty) _kv(c, 'admin.suspendReason'.tr(), d.suspendedReason!),
      ]),
    );
  }

  Widget _kv(AppColors c, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 110, child: Text(k, style: AppText.footnote.c(c.secondaryLabel))),
          Expanded(child: Text(v, style: AppText.footnote.semibold.c(c.label))),
        ]),
      );

  Widget _actions(AppColors c, AdminUser u) {
    if (u.isAdmin) {
      return Text('admin.adminProtected'.tr(), textAlign: TextAlign.center, style: AppText.footnote.c(c.secondaryLabel));
    }
    return Column(children: [
      AppButton(label: 'admin.adjustPoints'.tr(), icon: CupertinoIcons.star_circle_fill, onPressed: _busy ? null : _points),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: AppButton(
            label: u.suspended ? 'admin.unsuspend'.tr() : 'admin.suspend'.tr(),
            icon: u.suspended ? CupertinoIcons.play_circle_fill : CupertinoIcons.pause_circle_fill,
            kind: ButtonStyleKind.tinted,
            onPressed: _busy ? null : () => _suspend(u),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AppButton(
            label: 'admin.delete'.tr(),
            icon: CupertinoIcons.trash_fill,
            kind: ButtonStyleKind.danger,
            onPressed: _busy ? null : () => _delete(u),
          ),
        ),
      ]),
    ]);
  }
}

class _PointRow extends StatelessWidget {
  const _PointRow({required this.e});
  final PointEvent e;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final positive = e.amount >= 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('points.${e.reason}'.tr(), style: AppText.subhead.c(c.label)),
            if (e.note.isNotEmpty)
              Text(e.note, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption.c(c.secondaryLabel)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${positive ? '+' : ''}${e.amount}', style: AppText.headline.c(positive ? c.bio : c.danger)),
          Text(Fmt.ago(e.createdAt), style: AppText.caption.c(c.tertiaryLabel)),
        ]),
      ]),
    );
  }
}
