import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Trans;

import '../../app/notification_controller.dart';
import '../../app/routes.dart';
import '../../app/session_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/large_title_page.dart';
import '../../core/widgets/photos.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/states.dart';
import '../../data/models.dart';
import '../../data/storage_service.dart';

/// Bell with the unread count; opens the notifications page.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key, this.color});
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (!Get.isRegistered<NotificationController>()) return const SizedBox.shrink();
    final ctrl = NotificationController.to;
    return Pressable(
      onTap: () => Get.toNamed(Routes.notifications),
      child: Obx(() {
        final n = ctrl.unread.value;
        return SizedBox(
          width: 38,
          height: 34,
          child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
            Icon(n > 0 ? CupertinoIcons.bell_fill : CupertinoIcons.bell, size: 26, color: color ?? c.label),
            if (n > 0)
              Positioned(
                top: 0,
                right: 2,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.danger,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: c.background, width: 1.5),
                  ),
                  child: Text(n > 99 ? '99+' : '$n', style: AppText.caption.bold.c(Colors.white).copyWith(fontSize: 10.5, height: 1)),
                ),
              ),
          ]),
        );
      }),
    );
  }
}

class NotificationsView extends StatefulWidget {
  const NotificationsView({super.key});

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  final ctrl = NotificationController.to;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    ctrl.refreshList();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600) ctrl.loadMore();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _open(AppNotification n) {
    ctrl.markRead(n);
    switch (n.kind) {
      case 'rating':
      case 'comment':
      case 'new_post':
        if (n.postId != null) Get.toNamed(Routes.post, arguments: n.postId);
      case 'announcement':
        _showAnnouncement(n);
      case 'new_user':
        if (n.actorId != null) Get.toNamed(Routes.adminUser, arguments: n.actorId);
      default:
        break;
    }
  }

  void _showAnnouncement(AppNotification n) {
    final t = NotificationText.of(n, SessionController.to.language.value);
    final c = context.colors;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.8),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(CupertinoIcons.speaker_2_fill, color: t.color),
                const SizedBox(width: 8),
                Text('notif.announcement'.tr(), style: AppText.footnote.semibold.c(t.color)),
                const Spacer(),
                Text(Fmt.ago(n.createdAt), style: AppText.caption.c(c.tertiaryLabel)),
              ]),
              const SizedBox(height: 12),
              Text(t.title, style: AppText.title2.c(c.label)),
              const SizedBox(height: 10),
              Text(t.body, style: AppText.body.c(c.label)),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: appTopBar(context, title: 'notif.title'.tr(), actions: [
        Obx(() => ctrl.items.isEmpty
            ? const SizedBox.shrink()
            : PopupMenuButton<String>(
                icon: Icon(CupertinoIcons.ellipsis_circle, color: c.brand),
                color: c.surfaceRaised,
                onSelected: (v) => v == 'read' ? ctrl.markAllRead() : ctrl.clearAll(),
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'read', child: Text('notif.markAllRead'.tr())),
                  PopupMenuItem(value: 'clear', child: Text('notif.clearAll'.tr(), style: TextStyle(color: c.danger))),
                ],
              )),
      ]),
      body: RefreshIndicator(
        color: c.brand,
        onRefresh: ctrl.refreshList,
        child: Obx(() {
          final list = ctrl.items.toList();
          if (list.isEmpty) {
            if (ctrl.loading.value) return const CenteredSpinner();
            return ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
              SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
              ctrl.error.value != null
                  ? MessageView.error(ctrl.error.value!, onRetry: ctrl.refreshList)
                  : MessageView(icon: CupertinoIcons.bell, title: 'notif.emptyTitle'.tr(), message: 'notif.emptyBody'.tr()),
            ]);
          }
          return ListView.separated(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: EdgeInsets.fromLTRB(16, 6, 16, MediaQuery.paddingOf(context).bottom + 24),
            itemCount: list.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              if (i == list.length) {
                return Obx(() => Padding(
                      padding: const EdgeInsets.all(12),
                      child: ctrl.loadingMore.value ? const CupertinoActivityIndicator() : const SizedBox.shrink(),
                    ));
              }
              return _NotificationTile(item: list[i], onTap: () => _open(list[i]));
            },
          );
        }),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onTap});
  final AppNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = NotificationText.of(item, SessionController.to.language.value);
    return Pressable(
      onTap: onTap,
      scale: 0.985,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: item.read ? c.surface : c.brandSoft,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(clipBehavior: Clip.none, children: [
            item.actorName != null
                ? Avatar(name: item.actorName!, url: item.actorAvatar, size: 44)
                : Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: t.color.withValues(alpha: 0.14), shape: BoxShape.circle),
                    child: Icon(t.icon, color: t.color, size: 22),
                  ),
            if (item.actorName != null)
              Positioned(
                right: -3,
                bottom: -3,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(color: t.color, shape: BoxShape.circle, border: Border.all(color: c.surface, width: 2)),
                  child: Icon(t.icon, size: 11, color: Colors.white),
                ),
              ),
          ]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.title, style: AppText.subhead.semibold.c(c.label)),
              if (t.body.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(t.body, maxLines: 3, overflow: TextOverflow.ellipsis, style: AppText.footnote.c(c.secondaryLabel)),
              ],
              const SizedBox(height: 4),
              Text(Fmt.ago(item.createdAt), style: AppText.caption.c(c.tertiaryLabel)),
            ]),
          ),
          if (item.postImage != null) ...[
            const SizedBox(width: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 48,
                height: 48,
                child: NetPhoto(url: StorageService.instance.publicUrl(Bucket.community, item.postImage!)),
              ),
            ),
          ] else if (!item.read)
            Container(
              margin: const EdgeInsets.only(left: 8, top: 4),
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: c.brand, shape: BoxShape.circle),
            ),
        ]),
      ),
    );
  }
}
