import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/cards.dart';
import '../../data/models.dart';

extension WasteCategoryUi on WasteCategory {
  String get label => switch (this) {
        WasteCategory.biodegradable => 'scan.bio'.tr(),
        WasteCategory.nonBiodegradable => 'scan.nonBio'.tr(),
        WasteCategory.uncertain => 'scan.uncertain'.tr(),
      };

  String get explainer => switch (this) {
        WasteCategory.biodegradable => 'scan.bioExplainer'.tr(),
        WasteCategory.nonBiodegradable => 'scan.nonBioExplainer'.tr(),
        WasteCategory.uncertain => 'scan.uncertainExplainer'.tr(),
      };

  IconData get icon => switch (this) {
        WasteCategory.biodegradable => CupertinoIcons.leaf_arrow_circlepath,
        WasteCategory.nonBiodegradable => CupertinoIcons.trash_fill,
        WasteCategory.uncertain => CupertinoIcons.question_circle_fill,
      };

  Color color(AppColors c) => switch (this) {
        WasteCategory.biodegradable => c.bio,
        WasteCategory.nonBiodegradable => c.nonBio,
        WasteCategory.uncertain => c.secondaryLabel,
      };

  Color soft(AppColors c) => switch (this) {
        WasteCategory.biodegradable => c.bioSoft,
        WasteCategory.nonBiodegradable => c.nonBioSoft,
        WasteCategory.uncertain => c.fill,
      };
}

/// The rich result: category hero + confidence + practical guidance.
class WasteResultDetails extends StatelessWidget {
  const WasteResultDetails({super.key, required this.scan});
  final WasteScan scan;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cat = scan.category;
    final color = cat.color(c);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: cat.soft(c), borderRadius: BorderRadius.circular(22)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  child: Icon(cat.icon, color: Colors.white, size: 23),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(cat.label.toUpperCase(), style: AppText.overline.c(color)),
                    const SizedBox(height: 2),
                    Text(_cap(scan.item), style: AppText.title2.c(c.label)),
                  ]),
                ),
              ]),
              const SizedBox(height: 12),
              Text(cat.explainer, style: AppText.subhead.c(c.secondaryLabel)),
              if (cat != WasteCategory.uncertain) ...[
                const SizedBox(height: 14),
                _Confidence(value: scan.confidence, color: color),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (cat != WasteCategory.uncertain)
          Row(children: [
            Expanded(child: _Fact(icon: CupertinoIcons.cube_box, label: 'scan.material'.tr(), value: _cap(scan.material))),
            const SizedBox(width: 10),
            Expanded(child: _Fact(icon: CupertinoIcons.hourglass, label: 'scan.breaksDown'.tr(), value: scan.decomposeTime)),
            const SizedBox(width: 10),
            Expanded(
              child: _Fact(
                icon: CupertinoIcons.arrow_3_trianglepath,
                label: 'scan.recyclable'.tr(),
                value: scan.recyclable ? 'common.yes'.tr() : 'common.no'.tr(),
              ),
            ),
          ]),
        const SizedBox(height: 14),
        if (scan.reason.isNotEmpty)
          _InfoCard(icon: CupertinoIcons.eye_fill, title: 'scan.why'.tr(), body: scan.reason, tint: c.brand),
        if (scan.disposal.isNotEmpty)
          _InfoCard(icon: CupertinoIcons.trash_circle_fill, title: 'scan.howToDispose'.tr(), body: scan.disposal, tint: color),
        if (scan.tip.isNotEmpty)
          _InfoCard(icon: CupertinoIcons.lightbulb_fill, title: 'scan.ecoTip'.tr(), body: scan.tip, tint: c.gold, highlighted: true),
        const SizedBox(height: 4),
        Row(children: [
          Icon(CupertinoIcons.sparkles, size: 13, color: c.tertiaryLabel),
          const SizedBox(width: 6),
          Expanded(child: Text('scan.disclaimer'.tr(), style: AppText.caption.c(c.tertiaryLabel))),
        ]),
      ],
    );
  }

  static String _cap(String s) => s.isEmpty ? '—' : s[0].toUpperCase() + s.substring(1);
}

class _Confidence extends StatelessWidget {
  const _Confidence({required this.value, required this.color});
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pct = (value * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('scan.confidence'.tr(), style: AppText.footnote.c(c.secondaryLabel)),
          const Spacer(),
          Text('$pct%', style: AppText.footnote.bold.c(color)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.clamp(0, 1)),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 7,
              color: color,
              backgroundColor: c.surface.withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      padding: const EdgeInsets.all(12),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: c.brand),
          const SizedBox(height: 8),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption.c(c.secondaryLabel)),
          const SizedBox(height: 2),
          Text(value.isEmpty ? '—' : value, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.subhead.semibold.c(c.label)),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.title, required this.body, required this.tint, this.highlighted = false});
  final IconData icon;
  final String title;
  final String body;
  final Color tint;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        color: highlighted ? tint.withValues(alpha: 0.12) : null,
        padding: const EdgeInsets.all(14),
        radius: 18,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: tint),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.subhead.semibold.c(c.label)),
                  const SizedBox(height: 3),
                  Text(body, style: AppText.subhead.c(c.secondaryLabel)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact result row (used in lists and the mission screen).
class WasteChip extends StatelessWidget {
  const WasteChip({super.key, required this.scan});
  final WasteScan scan;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pill(
      label: scan.category == WasteCategory.uncertain ? scan.category.label : '${scan.item} · ${scan.category.label}',
      icon: scan.category.icon,
      color: scan.category.color(c),
      background: scan.category.soft(c),
    );
  }
}

/// Animated "scanning" overlay drawn over the photo while the AI works.
class ScanningOverlay extends StatefulWidget {
  const ScanningOverlay({super.key});

  @override
  State<ScanningOverlay> createState() => _ScanningOverlayState();
}

class _ScanningOverlayState extends State<ScanningOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _a,
        builder: (context, _) => LayoutBuilder(builder: (context, box) {
          final y = Curves.easeInOut.transform(_a.value) * (box.maxHeight - 60);
          return Stack(children: [
            Positioned.fill(child: ColoredBox(color: Colors.black.withValues(alpha: 0.18))),
            Positioned(
              top: y,
              left: 0,
              right: 0,
              height: 60,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [c.brand.withValues(alpha: 0), c.brand.withValues(alpha: 0.55), c.brand.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ]);
        }),
      ),
    );
  }
}
