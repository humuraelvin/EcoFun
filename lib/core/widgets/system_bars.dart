import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';

/// Solid bars behind the phone's status bar (top) and navigation buttons (bottom), on every screen.
///
/// The app draws edge-to-edge, so without these, scrolled content would show through the clock,
/// battery and navigation icons. Content scrolls underneath and disappears cleanly instead.
class SystemBarGuard extends StatelessWidget {
  const SystemBarGuard({super.key, required this.child});
  final Widget child;

  /// Full-screen pages (the camera) switch the guards off while they are open.
  static final hidden = ValueNotifier<bool>(false);

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final color = context.colors.background;
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        child,
        ValueListenableBuilder<bool>(
          valueListenable: hidden,
          builder: (context, isHidden, _) {
            if (isHidden) return const SizedBox.shrink();
            return Positioned.fill(
              child: IgnorePointer(
                child: Column(children: [
                  if (padding.top > 0) Container(height: padding.top, color: color),
                  const Spacer(),
                  if (padding.bottom > 0) Container(height: padding.bottom, color: color),
                ]),
              ),
            );
          },
        ),
      ],
    );
  }
}
