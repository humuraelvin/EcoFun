import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Trans;

import '../../app/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/large_title_page.dart';
import '../../core/widgets/photos.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/states.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../data/storage_service.dart';
import '../shell/shell_view.dart';
import 'waste_widgets.dart';

class ScanController extends GetxController {
  final recent = <WasteScan>[].obs;
  final loading = true.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    try {
      final list = await ScanRepository.mine(limit: 6);
      StorageService.instance.preload(Bucket.scans, list.map((s) => s.imagePath).whereType<String>());
      recent.assignAll(list);
    } catch (_) {
    } finally {
      loading.value = false;
    }
  }
}

Future<void> startScan() async {
  final path = await Get.toNamed(Routes.camera);
  if (path is String) {
    await Get.toNamed(Routes.scanResult, arguments: {'path': path});
    if (Get.isRegistered<ScanController>()) Get.find<ScanController>().load();
  }
}

class ScanView extends StatelessWidget {
  const ScanView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ctrl = Get.isRegistered<ScanController>() ? Get.find<ScanController>() : Get.put(ScanController());
    return LargeTitlePage(
      title: 'scan.title'.tr(),
      controller: ShellController.to.scrollers[2],
      onRefresh: ctrl.load,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.list(children: [
            AppCard(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Bubble(icon: CupertinoIcons.leaf_arrow_circlepath, color: c.bio, soft: c.bioSoft),
                    const SizedBox(width: 14),
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(color: c.brand, borderRadius: BorderRadius.circular(26)),
                      child: Icon(CupertinoIcons.viewfinder, color: c.onBrand, size: 42),
                    ),
                    const SizedBox(width: 14),
                    _Bubble(icon: CupertinoIcons.trash_fill, color: c.nonBio, soft: c.nonBioSoft),
                  ],
                ),
                const SizedBox(height: 18),
                Text('scan.heroTitle'.tr(), textAlign: TextAlign.center, style: AppText.title2.c(c.label)),
                const SizedBox(height: 6),
                Text('scan.heroBody'.tr(), textAlign: TextAlign.center, style: AppText.callout.c(c.secondaryLabel)),
                const SizedBox(height: 20),
                AppButton(label: 'scan.open'.tr(), icon: CupertinoIcons.camera_fill, onPressed: startScan),
              ]),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _Legend(color: c.bio, soft: c.bioSoft, title: 'scan.bio'.tr(), body: 'scan.bioExamples'.tr())),
              const SizedBox(width: 10),
              Expanded(child: _Legend(color: c.nonBio, soft: c.nonBioSoft, title: 'scan.nonBio'.tr(), body: 'scan.nonBioExamples'.tr())),
            ]),
          ]),
        ),
        SliverToBoxAdapter(
          child: Obx(() => ctrl.recent.isEmpty
              ? const SizedBox.shrink()
              : SectionHeader('scan.recent'.tr(), action: 'common.seeAll'.tr(), onAction: () => Get.toNamed(Routes.scans))),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: Obx(() {
            if (ctrl.loading.value && ctrl.recent.isEmpty) {
              return const SliverToBoxAdapter(child: SizedBox.shrink());
            }
            return SliverList.builder(
              itemCount: ctrl.recent.length,
              itemBuilder: (_, i) => Padding(padding: const EdgeInsets.only(bottom: 10), child: ScanRow(scan: ctrl.recent[i])),
            );
          }),
        ),
      ],
    );
  }
}

class ScanRow extends StatelessWidget {
  const ScanRow({super.key, required this.scan});
  final WasteScan scan;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: () => Get.toNamed(Routes.scanResult, arguments: {'scan': scan}),
      scale: 0.985,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          SizedBox(width: 60, height: 60, child: StoragePhoto(bucket: Bucket.scans, path: scan.imagePath, radius: 12)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                scan.item.isEmpty ? scan.category.label : scan.item[0].toUpperCase() + scan.item.substring(1),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.headline.c(c.label),
              ),
              const SizedBox(height: 4),
              Row(children: [
                Icon(scan.category.icon, size: 13, color: scan.category.color(c)),
                const SizedBox(width: 4),
                Flexible(child: Text(scan.category.label, style: AppText.footnote.semibold.c(scan.category.color(c)))),
                Text('  ·  ${Fmt.ago(scan.createdAt)}', style: AppText.footnote.c(c.secondaryLabel)),
              ]),
            ]),
          ),
          Icon(CupertinoIcons.chevron_right, size: 16, color: c.tertiaryLabel),
        ]),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.icon, required this.color, required this.soft});
  final IconData icon;
  final Color color;
  final Color soft;

  @override
  Widget build(BuildContext context) => Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(color: soft, shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 24),
      );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.soft, required this.title, required this.body});
  final Color color;
  final Color soft;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: AppText.subhead.bold.c(color)),
          const SizedBox(height: 4),
          Text(body, style: AppText.footnote.c(context.colors.secondaryLabel)),
        ]),
      );
}

class ScansView extends StatefulWidget {
  const ScansView({super.key});

  @override
  State<ScansView> createState() => _ScansViewState();
}

class _ScansViewState extends State<ScansView> {
  late Future<List<WasteScan>> _future = _load();

  Future<List<WasteScan>> _load() async {
    final list = await ScanRepository.mine();
    await StorageService.instance.preload(Bucket.scans, list.map((s) => s.imagePath).whereType<String>());
    return list;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: appTopBar(context, title: 'scan.myScans'.tr()),
        body: FutureBuilder<List<WasteScan>>(
          future: _future,
          builder: (context, snap) {
            if (snap.hasError) {
              return MessageView.error('errors.generic'.tr(), onRetry: () => setState(() => _future = _load()));
            }
            if (!snap.hasData) return const CenteredSpinner();
            final list = snap.data!;
            if (list.isEmpty) {
              return MessageView(
                icon: CupertinoIcons.viewfinder,
                title: 'scan.noneTitle'.tr(),
                message: 'scan.noneBody'.tr(),
                actionLabel: 'scan.open'.tr(),
                onAction: startScan,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => ScanRow(scan: list[i]),
            );
          },
        ),
      );
}
