import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'buttons.dart';

/// Gently pulsing placeholder. One animation drives all boxes inside it.
class SkeletonPulse extends StatefulWidget {
  const SkeletonPulse({super.key, required this.child});
  final Widget child;

  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: 0.45, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
        child: widget.child,
      );
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, required this.height, this.radius = 10});
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: context.colors.fill, borderRadius: BorderRadius.circular(radius)),
      );
}

class MessageView extends StatelessWidget {
  const MessageView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;

  factory MessageView.error(String message, {VoidCallback? onRetry}) => MessageView(
        icon: CupertinoIcons.wifi_exclamationmark,
        title: 'common.somethingWrong'.tr(),
        message: message,
        actionLabel: onRetry == null ? null : 'common.tryAgain'.tr(),
        onAction: onRetry,
      );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(color: (iconColor ?? c.brand).withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(icon, size: 30, color: iconColor ?? c.brand),
            ),
            const SizedBox(height: 18),
            Text(title, textAlign: TextAlign.center, style: AppText.title3.c(c.label)),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(message!, textAlign: TextAlign.center, style: AppText.callout.c(c.secondaryLabel)),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: 20),
              AppButton(label: actionLabel!, onPressed: onAction, expand: false, height: 44, kind: ButtonStyleKind.tinted),
            ],
          ],
        ),
      ),
    );
  }
}

class CenteredSpinner extends StatelessWidget {
  const CenteredSpinner({super.key, this.label});
  final String? label;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CupertinoActivityIndicator(radius: 13),
            if (label != null) ...[
              const SizedBox(height: 12),
              Text(label!, style: AppText.callout.c(context.colors.secondaryLabel)),
            ],
          ],
        ),
      );
}
