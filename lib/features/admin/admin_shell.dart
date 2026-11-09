import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Trans;

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import 'admin_announce_view.dart';
import 'admin_controller.dart';
import 'admin_overview_view.dart';
import 'admin_posts_view.dart';
import 'admin_settings_view.dart';
import 'admin_users_view.dart';

/// The admin portal: its own tab bar, opened automatically when an admin signs in.
class AdminShell extends StatelessWidget {
  const AdminShell({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.isRegistered<AdminController>() ? AdminController.to : Get.put(AdminController());
    const pages = [AdminOverviewView(), AdminUsersView(), AdminPostsView(), AdminAnnounceView(), AdminSettingsView()];
    return Obx(() => PopScope(
          canPop: ctrl.tab.value == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) ctrl.tab.value = 0;
          },
          child: Scaffold(
            extendBody: true,
            body: IndexedStack(
              index: ctrl.tab.value,
              children: [for (var i = 0; i < pages.length; i++) TickerMode(enabled: i == ctrl.tab.value, child: pages[i])],
            ),
            bottomNavigationBar: _AdminTabBar(ctrl: ctrl),
          ),
        ));
  }
}

class _AdminTabBar extends StatelessWidget {
  const _AdminTabBar({required this.ctrl});
  final AdminController ctrl;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final items = [
      (CupertinoIcons.chart_bar_square, CupertinoIcons.chart_bar_square_fill, 'admin.tabOverview'.tr()),
      (CupertinoIcons.person_2, CupertinoIcons.person_2_fill, 'admin.tabMembers'.tr()),
      (CupertinoIcons.photo_on_rectangle, CupertinoIcons.photo_fill_on_rectangle_fill, 'admin.tabPosts'.tr()),
      (CupertinoIcons.speaker_2, CupertinoIcons.speaker_2_fill, 'admin.tabAnnounce'.tr()),
      (CupertinoIcons.gear, CupertinoIcons.gear_solid, 'admin.tabSettings'.tr()),
    ];
    return Container(
      decoration: BoxDecoration(color: c.background, border: Border(top: BorderSide(color: c.separator, width: 0.5))),
      padding: EdgeInsets.only(bottom: bottom > 0 ? bottom : 6, top: 6),
      child: Obx(() {
        final current = ctrl.tab.value;
        return Row(children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => ctrl.tab.value = i,
                child: SizedBox(
                  height: 50,
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(current == i ? items[i].$2 : items[i].$1, size: 24, color: current == i ? c.brand : c.secondaryLabel),
                    const SizedBox(height: 3),
                    Text(
                      items[i].$3,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: AppText.caption.copyWith(
                        fontSize: 10.5,
                        color: current == i ? c.brand : c.secondaryLabel,
                        fontWeight: current == i ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ]),
                ),
              ),
            ),
        ]);
      }),
    );
  }
}
