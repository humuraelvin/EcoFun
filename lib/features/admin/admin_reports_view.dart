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

/// Posts members reported. For each: keep it, remove it, or remove it and ban the author for good.
class AdminReportsView extends StatefulWidget {
  const AdminReportsView({super.key});

  @override
  State<AdminReportsView> createState() => _AdminReportsViewState();
}

class _AdminReportsViewState extends State<AdminReportsView> {
  List<ReportedPost>? _items;
  String? _error;
  final _busy = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await AdminRepository.reports();
      if (mounted) {
        setState(() {
          _items = list;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  Future<void> _act(ReportedPost r, String action) async {
    if (action != 'dismiss') {
      final ok = await showCupertinoDialog<bool>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: Text(action == 'ban' ? 'reports.banTitle'.tr(args: [r.post.authorName]) : 'reports.removeTitle'.tr()),
          content: Text(action == 'ban' ? 'reports.banMessage'.tr() : 'reports.removeMessage'.tr(args: [r.post.authorName])),
          actions: [
            CupertinoDialogAction(onPressed: () => Navigator.pop(ctx, false), child: Text('common.cancel'.tr())),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(action == 'ban' ? 'reports.ban'.tr() : 'reports.remove'.tr()),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _busy.add(r.post.id));
    try {
      await AdminRepository.resolveReports(r, action);
      HapticFeedback.mediumImpact();
      showToast(switch (action) {
        'ban' => 'reports.banned'.tr(),
        'remove' => 'reports.removed'.tr(),
        _ => 'reports.dismissed'.tr(),
      });
      setState(() => _items?.remove(r));
      if (Get.isRegistered<AdminController>()) {
        AdminController.to
          ..refreshDashboard()
          ..refreshPosts()
          ..refreshUsers();
      }
    } catch (e) {
      showToast(friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(r.post.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final items = _items;
    return Scaffold(
      backgroundColor: c.background,
      appBar: appTopBar(context, title: 'reports.title'.tr()),
      body: items == null
          ? (_error != null ? MessageView.error(_error!, onRetry: _load) : const CenteredSpinner())
          : RefreshIndicator(
              color: c.brand,
              onRefresh: _load,
              child: items.isEmpty
                  ? ListView(children: [
                      SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
                      MessageView(icon: CupertinoIcons.checkmark_shield_fill, title: 'reports.emptyTitle'.tr(), message: 'reports.emptyBody'.tr()),
                    ])
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(16, 6, 16, MediaQuery.paddingOf(context).bottom + 24),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (_, i) => _ReportCard(
                        item: items[i],
                        busy: _busy.contains(items[i].post.id),
                        onAction: (a) => _act(items[i], a),
                      ),
                    ),
            ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.item, required this.busy, required this.onAction});
  final ReportedPost item;
  final bool busy;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final p = item.post;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Pressable(
          scale: 1,
          onTap: () => Get.toNamed(Routes.adminUser, arguments: p.userId),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(children: [
              Avatar(name: p.authorName, url: p.authorAvatar, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.authorName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.headline.c(c.label)),
                  Text('${p.authorEmail ?? ''} · ${Fmt.ago(p.createdAt)}', maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: AppText.caption.c(c.secondaryLabel)),
                ]),
              ),
              StatusPill(label: 'reports.count'.plural(item.reports.length), color: c.danger),
            ]),
          ),
        ),
        AspectRatio(aspectRatio: 1.3, child: NetPhoto(url: StorageService.instance.publicUrl(Bucket.community, p.imagePath))),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (p.caption.isNotEmpty) ...[Text(p.caption, style: AppText.callout.c(c.label)), const SizedBox(height: 10)],
            if (item.hidden)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Icon(CupertinoIcons.eye_slash_fill, size: 15, color: c.secondaryLabel),
                  const SizedBox(width: 6),
                  Expanded(child: Text('reports.hiddenNote'.tr(), style: AppText.footnote.c(c.secondaryLabel))),
                ]),
              ),
            for (final r in item.reports)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(CupertinoIcons.flag_fill, size: 15, color: c.danger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('report.reason_${r.reason}'.tr(), style: AppText.subhead.semibold.c(c.label)),
                      if (r.details.isNotEmpty) Text('“${r.details}”', style: AppText.footnote.c(c.label)),
                      Text('${r.reporterName} · ${Fmt.ago(r.createdAt)}', style: AppText.caption.c(c.tertiaryLabel)),
                    ]),
                  ),
                ]),
              ),
            const SizedBox(height: 6),
            if (busy)
              const Center(child: Padding(padding: EdgeInsets.all(12), child: CupertinoActivityIndicator()))
            else ...[
              AppButton(label: 'reports.banAction'.tr(), icon: CupertinoIcons.nosign, kind: ButtonStyleKind.danger,
                  onPressed: () => onAction('ban')),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: AppButton(label: 'reports.remove'.tr(), icon: CupertinoIcons.trash, kind: ButtonStyleKind.tinted,
                    onPressed: () => onAction('remove'))),
                const SizedBox(width: 8),
                Expanded(child: AppButton(label: 'reports.keep'.tr(), icon: CupertinoIcons.checkmark_alt, kind: ButtonStyleKind.plain,
                    onPressed: () => onAction('dismiss'))),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }
}
