import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'pressable.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.radius = 20,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final double radius;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final box = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? c.surface,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: c.shadow.a == 0
            ? null
            : [BoxShadow(color: c.shadow, blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: child,
    );
    return onTap == null ? box : Pressable(onTap: onTap, scale: 0.98, child: box);
  }
}

/// iOS "inset grouped" list section.
class GroupedSection extends StatelessWidget {
  const GroupedSection({super.key, required this.children, this.header, this.footer});

  final List<Widget> children;
  final String? header;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) {
        rows.add(Padding(
          padding: const EdgeInsets.only(left: 56),
          child: Container(height: 0.6, color: c.separator),
        ));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(header!.toUpperCase(), style: AppText.overline.c(c.secondaryLabel)),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ColoredBox(color: c.surface, child: Column(children: rows)),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(footer!, style: AppText.footnote.c(c.secondaryLabel)),
          ),
      ],
    );
  }
}

class GroupedRow extends StatelessWidget {
  const GroupedRow({
    super.key,
    required this.icon,
    required this.title,
    this.iconColor,
    this.value,
    this.onTap,
    this.destructive = false,
    this.showChevron = true,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Color? iconColor;
  final String? value;
  final VoidCallback? onTap;
  final bool destructive;
  final bool showChevron;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tint = destructive ? c.danger : (iconColor ?? c.brand);
    return Pressable(
      onTap: onTap,
      scale: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: tint.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 17, color: tint),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title, style: AppText.body.c(destructive ? c.danger : c.label)),
            ),
            if (value != null) Text(value!, style: AppText.body.c(c.secondaryLabel)),
            ?trailing,
            if (showChevron && onTap != null) ...[
              const SizedBox(width: 6),
              Icon(CupertinoIcons.chevron_right, size: 16, color: c.tertiaryLabel),
            ],
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction, this.padding});

  final String title;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(20, 26, 20, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: Text(title, style: AppText.title3.bold.c(c.label))),
          if (action != null)
            Pressable(
              onTap: onAction,
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(action!, style: AppText.callout.c(c.brand)),
              ),
            ),
        ],
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill({super.key, required this.label, this.icon, this.color, this.background, this.dense = false});

  final String label;
  final IconData? icon;
  final Color? color;
  final Color? background;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = color ?? c.brand;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 11, vertical: dense ? 3 : 6),
      decoration: BoxDecoration(color: background ?? fg.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: dense ? 12 : 14, color: fg), const SizedBox(width: 4)],
          Text(label, style: (dense ? AppText.caption : AppText.footnote).semibold.c(fg)),
        ],
      ),
    );
  }
}
