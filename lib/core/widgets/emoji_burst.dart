import 'dart:math';

import 'package:flutter/material.dart';

/// Full-screen celebration: a burst of eco emojis that fly up from the bottom and rain back down.
/// Driven by one AnimationController; each emoji is a lightweight Text placed by Transform.
class EmojiBurst extends StatefulWidget {
  const EmojiBurst({super.key, this.count = 70, this.duration = const Duration(milliseconds: 2600)});
  final int count;
  final Duration duration;

  static const emojis = ['🌱', '🌿', '♻️', '🌍', '💚', '🎉', '✨', '🌳', '⭐', '🍃', '🌸', '👏'];

  @override
  State<EmojiBurst> createState() => _EmojiBurstState();
}

class _Particle {
  _Particle(Random r)
      : emoji = EmojiBurst.emojis[r.nextInt(EmojiBurst.emojis.length)],
        x = 0.1 + r.nextDouble() * 0.8,
        angle = -pi / 2 + (r.nextDouble() - 0.5) * 1.6,
        speed = 0.9 + r.nextDouble() * 0.9,
        spin = (r.nextDouble() - 0.5) * 6,
        size = 22 + r.nextDouble() * 22,
        delay = r.nextDouble() * 0.25;
  final String emoji;
  final double x, angle, speed, spin, size, delay;
}

class _EmojiBurstState extends State<EmojiBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    final r = Random();
    _particles = List.generate(widget.count, (_) => _Particle(r));
    // `preserve`: plays at full length even on phones where Android animations are switched off
    // (Flutter would otherwise finish it in a split second).
    _c = AnimationController(vsync: this, duration: widget.duration, animationBehavior: AnimationBehavior.preserve)
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: LayoutBuilder(builder: (context, box) {
          final w = box.maxWidth, h = box.maxHeight;
          return AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = _c.value;
              return Stack(clipBehavior: Clip.none, children: [
                for (final p in _particles) ..._place(p, t, w, h),
              ]);
            },
          );
        }),
      );

  Iterable<Widget> _place(_Particle p, double t, double w, double h) sync* {
    final lt = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
    if (lt <= 0 || lt >= 1) return;
    // launched from below the bottom edge, slowed by gravity, then falling back down
    final v = p.speed * h * 1.25;
    final x = p.x * w + cos(p.angle) * v * lt;
    final y = h * 1.02 + sin(p.angle) * v * lt + 1.1 * h * lt * lt;
    final opacity = lt < 0.75 ? 1.0 : 1 - (lt - 0.75) / 0.25;
    Widget e = Text(p.emoji, style: TextStyle(fontSize: p.size, height: 1, decoration: TextDecoration.none));
    if (opacity < 1) e = Opacity(opacity: opacity, child: e);
    yield Positioned(
      left: x - p.size / 2,
      top: y - p.size / 2,
      child: Transform.rotate(angle: p.spin * lt, child: e),
    );
  }
}
