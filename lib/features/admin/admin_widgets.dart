import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/format.dart';

class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.icon, required this.color, required this.value, required this.label, this.sub});
  final IconData icon;
  final Color color;
  final int value;
  final String label;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(height: 10),
        Text(Fmt.points(value), style: AppText.title2.c(c.label)),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.footnote.c(c.secondaryLabel)),
        if (sub != null) ...[
          const SizedBox(height: 2),
          Text(sub!, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption.semibold.c(color)),
        ],
      ]),
    );
  }
}

/// Two-column grid of [StatTile]s without nested scrolling.
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      rows.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: children[i]),
        const SizedBox(width: 10),
        Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox.shrink()),
      ]));
      if (i + 2 < children.length) rows.add(const SizedBox(height: 10));
    }
    return Column(children: rows);
  }
}

/// Simple bar chart: one bar per day, labelled with weekday initials.
class DailyBars extends StatelessWidget {
  const DailyBars({super.key, required this.days});
  final List<(DateTime, int)> days;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final maxV = days.fold<int>(0, (m, d) => d.$2 > m ? d.$2 : m);
    return SizedBox(
      height: 130,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (final (day, v) in days)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                if (v > 0) Text('$v', style: AppText.caption.c(c.secondaryLabel).copyWith(fontSize: 10)),
                const SizedBox(height: 2),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  height: maxV == 0 ? 3 : 3 + 82 * v / maxV,
                  decoration: BoxDecoration(
                    color: v == 0 ? c.fill : c.brand,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                const SizedBox(height: 6),
                Text(Fmt.weekdayShort(day).characters.first, style: AppText.caption.c(c.tertiaryLabel).copyWith(fontSize: 10)),
              ]),
            ),
          ),
      ]),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(99)),
        child: Text(label, style: AppText.caption.semibold.c(color)),
      );
}
