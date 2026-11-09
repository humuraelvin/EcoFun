import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Trans;

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../community/community_view.dart';
import '../home/home_view.dart';
import '../news/news_view.dart';
import '../profile/profile_view.dart';
import '../scan/scan_view.dart';

class ShellController extends GetxController {
  static ShellController get to => Get.find();

  final index = 0.obs;
  final scrollers = List.generate(5, (_) => ScrollController());
  final _built = <int>{0}.obs;

  bool isBuilt(int i) => _built.contains(i);

  void select(int i) {
    if (index.value == i) {
      final s = scrollers[i];
      if (s.hasClients && s.offset > 0) {
        s.animateTo(0, duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
      }
      return;
    }
    HapticFeedback.selectionClick();
    _built.add(i);
    index.value = i;
  }
}

class ShellView extends StatelessWidget {
  const ShellView({super.key});

  @override
  Widget build(BuildContext context) {
    final shell = Get.isRegistered<ShellController>() ? ShellController.to : Get.put(ShellController());
    const pages = [HomeView(), NewsView(), ScanView(), CommunityView(), ProfileView()];

    return Obx(
      () => PopScope(
        // Android back: return to Today before leaving the app.
        canPop: shell.index.value == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) shell.select(0);
        },
        child: Scaffold(
          extendBody: true,
          body: Obx(() {
            final current = shell.index.value;
            // Lazy IndexedStack: a tab is only built the first time it is opened, then kept alive.
            return IndexedStack(
              index: current,
              children: [
                for (var i = 0; i < pages.length; i++)
                  shell.isBuilt(i) || i == current
                      ? TickerMode(enabled: i == current, child: pages[i])
                      : const SizedBox.shrink(),
              ],
            );
          }),
          bottomNavigationBar: const _TabBar(),
        ),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final shell = ShellController.to;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final items = [
      (CupertinoIcons.house, CupertinoIcons.house_fill, 'tabs.today'.tr()),
      (CupertinoIcons.news, CupertinoIcons.news_solid, 'tabs.news'.tr()),
      (CupertinoIcons.viewfinder, CupertinoIcons.viewfinder, 'tabs.scan'.tr()),
      (CupertinoIcons.person_2, CupertinoIcons.person_2_fill, 'tabs.community'.tr()),
      (CupertinoIcons.person_crop_circle, CupertinoIcons.person_crop_circle_fill, 'tabs.profile'.tr()),
    ];

    return Container(
      decoration: BoxDecoration(
        color: c.background,   // solid: content scrolls underneath without showing through
        border: Border(top: BorderSide(color: c.separator, width: 0.5)),
      ),
      padding: EdgeInsets.only(bottom: bottom > 0 ? bottom : 6, top: 6),
      child: Obx(() {
        final current = shell.index.value;
        return Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => shell.select(i),
                  child: i == 2
                      ? _ScanTab(label: items[i].$3, selected: current == i)
                      : _TabItem(
                          icon: current == i ? items[i].$2 : items[i].$1,
                          label: items[i].$3,
                          selected: current == i,
                        ),
                ),
              ),
          ],
        );
      }),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.icon, required this.label, required this.selected});
  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = selected ? c.brand : c.secondaryLabel;
    return SizedBox(
      height: 50,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedScale(
            scale: selected ? 1.06 : 1,
            duration: const Duration(milliseconds: 180),
            child: Icon(icon, size: 25, color: color),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: AppText.caption.copyWith(
              fontSize: 10.5,
              color: color,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanTab extends StatelessWidget {
  const _ScanTab({required this.label, required this.selected});
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: 50,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 40,
            height: 30,
            decoration: BoxDecoration(
              color: c.brand,
              borderRadius: BorderRadius.circular(11),
              boxShadow: selected
                  ? null
                  : [BoxShadow(color: c.brand.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Icon(CupertinoIcons.viewfinder, size: 20, color: c.onBrand),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: AppText.caption.copyWith(
              fontSize: 10.5,
              color: selected ? c.brand : c.secondaryLabel,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
