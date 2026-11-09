import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'pressable.dart';

enum ButtonStyleKind { filled, tinted, plain, danger }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.kind = ButtonStyleKind.filled,
    this.expand = true,
    this.height = 52,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final ButtonStyleKind kind;
  final bool expand;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final disabled = onPressed == null && !loading;
    final (bg, fg) = switch (kind) {
      ButtonStyleKind.filled => (c.brand, c.onBrand),
      ButtonStyleKind.tinted => (c.brandSoft, c.brand),
      ButtonStyleKind.plain => (Colors.transparent, c.brand),
      ButtonStyleKind.danger => (c.danger.withValues(alpha: 0.12), c.danger),
    };
    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: height,
      width: expand ? double.infinity : null,
      padding: EdgeInsets.symmetric(horizontal: expand ? 16 : 20),
      decoration: BoxDecoration(
        color: disabled ? c.fill : bg,
        borderRadius: BorderRadius.circular(height / 3.4),
      ),
      alignment: Alignment.center,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 160),
        child: loading
            ? CupertinoActivityIndicator(key: const ValueKey('l'), color: fg)
            : Row(
                key: const ValueKey('c'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 19, color: disabled ? c.tertiaryLabel : fg),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.headline.c(disabled ? c.tertiaryLabel : fg),
                    ),
                  ),
                ],
              ),
      ),
    );
    return Pressable(onTap: loading ? null : onPressed, child: child);
  }
}

/// Small round icon button used on top of photos and in bars.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 36,
    this.background,
    this.foreground,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color? background;
  final Color? foreground;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final w = Pressable(
      onTap: onTap,
      scale: 0.9,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: background ?? c.fill, shape: BoxShape.circle),
        child: Icon(icon, size: size * 0.5, color: foreground ?? c.label),
      ),
    );
    return tooltip == null ? w : Semantics(label: tooltip, button: true, child: w);
  }
}

class TextLink extends StatelessWidget {
  const TextLink(this.label, {super.key, required this.onTap, this.color});
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Text(label, style: AppText.callout.semibold.c(color ?? context.colors.brand)),
        ),
      );
}
