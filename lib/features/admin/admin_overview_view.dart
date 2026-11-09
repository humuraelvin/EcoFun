import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart' hide Trans;

import '../../app/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/large_title_page.dart';
import '../../core/widgets/photos.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/states.dart';
import '../../data/models.dart';
import '../notifications/notifications_view.dart';
import 'admin_controller.dart';
import 'admin_widgets.dart';

class AdminOverviewView extends StatelessWidget {
  const AdminOverviewView({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = AdminController.to;
    final c = context.colors;
    return LargeTitlePage(
      title: 'admin.overview'.tr(),
      onRefresh: ctrl.refreshDashboard,
      trailing: const NotificationBell(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(
            child: Obx(() {
              final d = ctrl.dashboard.value;
              if (d == null) {
                return ctrl.dashboardError.value != null
                    ? AppCard(child: MessageView.error(ctrl.dashboardError.value!, onRetry: ctrl.refreshDashboard))
                    : const SkeletonPulse(child: Column(children: [
                        SkeletonBox(height: 110, radius: 18), SizedBox(height: 10), SkeletonBox(height: 110, radius: 18),
                        SizedBox(height: 10), SkeletonBox(height: 180, radius: 18),
                      ]));
              }
              return _Body(d: d, c: c);
            }),
          ),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.d, required this.c});
  final AdminDashboard d;
  final AppColors c;

  @override
  Widget build(BuildContext context) {
    final signupTotal = d.signups.fold<int>(0, (s, e) => s + e.$2);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('admin.overviewSubtitle'.tr(), style: AppText.subhead.c(c.secondaryLabel)),
      const SizedBox(height: 14),
      StatGrid(children: [
        StatTile(icon: CupertinoIcons.person_2_fill, color: c.brand, value: d['members'], label: 'admin.statMembers'.tr(),
            sub: 'admin.statNewToday'.tr(args: ['${d['new_today']}'])),
        StatTile(icon: CupertinoIcons.bolt_fill, color: const Color(0xFFFF9500), value: d['active_today'],
            label: 'admin.statActive'.tr(), sub: 'admin.statNewWeek'.tr(args: ['${d['new_week']}'])),
        StatTile(icon: CupertinoIcons.question_circle_fill, color: const Color(0xFF8E5CF7), value: d['quizzes'],
            label: 'admin.statQuizzes'.tr(), sub: 'admin.statToday'.tr(args: ['${d['quizzes_today']}'])),
        StatTile(icon: CupertinoIcons.photo_fill, color: const Color(0xFF0A84FF), value: d['posts'],
            label: 'admin.statPosts'.tr(), sub: 'admin.statToday'.tr(args: ['${d['posts_today']}'])),
        StatTile(icon: CupertinoIcons.viewfinder, color: const Color(0xFF30B0C7), value: d['scans'],
            label: 'admin.statScans'.tr(), sub: 'admin.statDisposed'.tr(args: ['${d['disposals']}'])),
        StatTile(icon: CupertinoIcons.leaf_arrow_circlepath, color: c.bio, value: d['missions'], label: 'admin.statMissions'.tr()),
        StatTile(icon: CupertinoIcons.chat_bubble_2_fill, color: const Color(0xFF5856D6), value: d['comments'],
            label: 'admin.statComments'.tr(), sub: 'admin.statRatings'.tr(args: ['${d['ratings']}'])),
        StatTile(icon: CupertinoIcons.book_fill, color: const Color(0xFFFF2D55), value: d['stories_read'],
            label: 'admin.statStories'.tr(), sub: 'admin.statArticles'.tr(args: ['${d['articles']}'])),
        StatTile(icon: CupertinoIcons.star_fill, color: c.gold, value: d['points_total'], label: 'admin.statPoints'.tr()),
        StatTile(icon: CupertinoIcons.lightbulb_fill, color: const Color(0xFF34C759), value: d['quiz_questions'],
            label: 'admin.statPool'.tr()),
        StatTile(icon: CupertinoIcons.nosign, color: c.danger, value: d['suspended'], label: 'admin.statSuspended'.tr()),
        StatTile(icon: CupertinoIcons.hourglass, color: c.secondaryLabel, value: d['unverified'], label: 'admin.statUnverified'.tr()),
      ]),
      const SizedBox(height: 18),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('admin.signupsTitle'.tr(), style: AppText.headline.c(c.label))),
            Text('admin.signupsTotal'.tr(args: ['$signupTotal']), style: AppText.footnote.c(c.secondaryLabel)),
          ]),
          const SizedBox(height: 14),
          DailyBars(days: d.signups),
        ]),
      ),
      if (d.top.isNotEmpty) ...[
        SectionHeader('admin.topMembers'.tr(), padding: const EdgeInsets.fromLTRB(4, 22, 4, 8)),
        GroupedSection(children: [
          for (var i = 0; i < d.top.length; i++)
            _PersonRow(
              id: d.top[i].id,
              name: d.top[i].fullName,
              avatar: d.top[i].avatarUrl,
              leading: '${i + 1}',
              trailing: '${Fmt.points(d.top[i].points)} ${'common.pts'.tr()}',
            ),
        ]),
      ],
      if (d.recent.isNotEmpty) ...[
        SectionHeader('admin.newMembers'.tr(), padding: const EdgeInsets.fromLTRB(4, 22, 4, 8)),
        GroupedSection(children: [
          for (final u in d.recent)
            _PersonRow(id: u.id, name: u.fullName, avatar: u.avatarUrl, subtitle: u.email, trailing: Fmt.ago(u.createdAt)),
        ]),
      ],
    ]);
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.id, required this.name, this.avatar, this.subtitle, this.leading, required this.trailing});
  final String id;
  final String name;
  final String? avatar;
  final String? subtitle;
  final String? leading;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      scale: 1,
      onTap: () => Get.toNamed(Routes.adminUser, arguments: id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          if (leading != null) SizedBox(width: 26, child: Text(leading!, style: AppText.headline.c(c.secondaryLabel))),
          Avatar(name: name, url: avatar, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body.c(c.label)),
              if (subtitle != null)
                Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption.c(c.secondaryLabel)),
            ]),
          ),
          Text(trailing, style: AppText.footnote.semibold.c(c.brand)),
          const SizedBox(width: 4),
          Icon(CupertinoIcons.chevron_right, size: 15, color: c.tertiaryLabel),
        ]),
      ),
    );
  }
}
