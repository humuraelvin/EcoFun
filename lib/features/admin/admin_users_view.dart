import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Trans;

import '../../app/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/large_title_page.dart';
import '../../core/widgets/photos.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/states.dart';
import '../../data/models.dart';
import 'admin_controller.dart';
import 'admin_widgets.dart';

class AdminUsersView extends StatefulWidget {
  const AdminUsersView({super.key});

  @override
  State<AdminUsersView> createState() => _AdminUsersViewState();
}

class _AdminUsersViewState extends State<AdminUsersView> {
  final ctrl = AdminController.to;
  final _scroll = ScrollController();
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600) ctrl.moreUsers();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LargeTitlePage(
      title: 'admin.members'.tr(),
      controller: _scroll,
      onRefresh: ctrl.refreshUsers,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          sliver: SliverToBoxAdapter(
            child: Column(children: [
              CupertinoSearchTextField(
                controller: _search,
                placeholder: 'admin.searchMembers'.tr(),
                style: AppText.body.c(c.label),
                backgroundColor: c.surface,
                onChanged: (v) => ctrl.search.value = v.trim(),
              ),
              const SizedBox(height: 10),
              Obx(() => SizedBox(
                    width: double.infinity,
                    child: CupertinoSlidingSegmentedControl<String>(
                      groupValue: ctrl.filter.value,
                      backgroundColor: c.fill,
                      thumbColor: c.surface,
                      children: {
                        'all': _seg('admin.filterAll'.tr()),
                        'active': _seg('admin.filterActive'.tr()),
                        'suspended': _seg('admin.filterSuspended'.tr()),
                        'admins': _seg('admin.filterAdmins'.tr()),
                      },
                      onValueChanged: (v) {
                        HapticFeedback.selectionClick();
                        ctrl.filter.value = v ?? 'all';
                      },
                    ),
                  )),
            ]),
          ),
        ),
        Obx(() {
          final list = ctrl.users.toList();
          if (list.isEmpty) {
            if (ctrl.usersLoading.value) {
              return const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(40), child: CupertinoActivityIndicator()));
            }
            return SliverFillRemaining(
              hasScrollBody: false,
              child: ctrl.usersError.value != null
                  ? MessageView.error(ctrl.usersError.value!, onRetry: ctrl.refreshUsers)
                  : MessageView(icon: CupertinoIcons.person_2, title: 'admin.noMembers'.tr()),
            );
          }
          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.separated(
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) => AdminUserRow(user: list[i]),
            ),
          );
        }),
      ],
    );
  }

  Widget _seg(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Text(t, maxLines: 1, style: AppText.footnote.semibold),
      );
}

class AdminUserRow extends StatelessWidget {
  const AdminUserRow({super.key, required this.user});
  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      scale: 0.985,
      onTap: () => Get.toNamed(Routes.adminUser, arguments: user.id),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Avatar(name: user.fullName, url: user.avatarUrl, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(user.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.headline.c(c.label)),
                ),
                if (user.isAdmin) ...[const SizedBox(width: 6), StatusPill(label: 'admin.badgeAdmin'.tr(), color: const Color(0xFF8E5CF7))],
                if (user.suspended) ...[const SizedBox(width: 6), StatusPill(label: 'admin.badgeSuspended'.tr(), color: c.danger)],
              ]),
              Text(user.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.footnote.c(c.secondaryLabel)),
              const SizedBox(height: 2),
              Text('admin.joined'.tr(args: [Fmt.ago(user.createdAt)]), style: AppText.caption.c(c.tertiaryLabel)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(Fmt.points(user.points), style: AppText.headline.c(c.brand)),
            Text('common.pts'.tr(), style: AppText.caption.c(c.secondaryLabel)),
          ]),
        ]),
      ),
    );
  }
}
