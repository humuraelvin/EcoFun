import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Trans;

import '../../app/routes.dart';
import '../../app/session_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/large_title_page.dart';
import '../../core/widgets/photos.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models.dart';
import '../../data/storage_service.dart';
import '../scan/waste_widgets.dart';

class HistoryDetailView extends StatelessWidget {
  const HistoryDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final item = Get.arguments as MissionCompletion;
    final lang = SessionController.to.language.value;
    final m = item.mission;
    return Scaffold(
      backgroundColor: c.background,
      appBar: appTopBar(context, title: Fmt.date(item.day)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 4, 16, MediaQuery.paddingOf(context).bottom + 24),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: AspectRatio(aspectRatio: 4 / 3.4, child: StoragePhoto(bucket: Bucket.missions, path: item.imagePath)),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Text(m?.icon ?? '🌱', style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 10),
            Expanded(child: Text(m?.title(lang) ?? 'mission.title'.tr(), style: AppText.title2.c(c.label))),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            Pill(label: '+${item.pointsAwarded} ${'common.pts'.tr()}', icon: CupertinoIcons.star_fill),
            Pill(label: Fmt.longDay(item.day), icon: CupertinoIcons.calendar, color: c.secondaryLabel),
          ]),
          const SizedBox(height: 18),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('history.myStory'.tr(), style: AppText.subhead.semibold.c(c.secondaryLabel)),
              const SizedBox(height: 8),
              Text(item.story, style: AppText.body.c(c.label)),
            ]),
          ),
          if (m != null) ...[
            const SizedBox(height: 12),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('history.theMission'.tr(), style: AppText.subhead.semibold.c(c.secondaryLabel)),
                const SizedBox(height: 8),
                Text(m.description(lang), style: AppText.callout.c(c.label)),
              ]),
            ),
          ],
          if (item.scan != null) ...[
            SectionHeader('history.aiCheck'.tr(), padding: const EdgeInsets.fromLTRB(4, 22, 4, 10)),
            Pressable(
              onTap: () => Get.toNamed(Routes.scanResult, arguments: {'scan': item.scan}),
              child: AppCard(
                child: Row(children: [
                  Expanded(child: Align(alignment: Alignment.centerLeft, child: WasteChip(scan: item.scan!))),
                  Icon(CupertinoIcons.chevron_right, size: 16, color: c.tertiaryLabel),
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
