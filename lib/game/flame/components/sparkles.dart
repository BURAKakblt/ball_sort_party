import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flutter/animation.dart';

const _palette = [
  Color(0xFFFFE27A),
  Color(0xFF2EE6D6),
  Color(0xFFFFFFFF),
  Color(0xFFB58CFF),
  Color(0xFFFF8AAA),
];

Path _star(double r) {
  final p = Path();
  for (var i = 0; i < 8; i++) {
    final a = i * math.pi / 4 - math.pi / 2;
    final d = i.isEven ? r : r * 0.38;
    final pt = Offset(math.cos(a) * d, math.sin(a) * d);
    i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
  }
  return p..close();
}

/// Burst of twinkling stars, used when a bottle is completed.
ParticleSystemComponent sparkleBurst(Vector2 at, double scale, {int count = 26}) {
  final rnd = math.Random();
  return ParticleSystemComponent(
    position: at,
    priority: 30,
    particle: Particle.generate(
      count: count,
      lifespan: 0.9,
      generator: (i) {
        final angle = -math.pi / 2 + (rnd.nextDouble() - 0.5) * math.pi * 1.3;
        final speed = (120 + rnd.nextDouble() * 200) * scale;
        final color = _palette[rnd.nextInt(_palette.length)];
        final size = (3 + rnd.nextDouble() * 5) * scale;
        final star = _star(size);
        return AcceleratedParticle(
          speed: Vector2(math.cos(angle), math.sin(angle)) * speed,
          acceleration: Vector2(0, 420 * scale),
          child: ComputedParticle(
            renderer: (canvas, particle) {
              final fade = 1 - particle.progress;
              canvas.save();
              canvas.rotate(particle.progress * 4);
              canvas.drawPath(star, Paint()..color = color.withValues(alpha: fade));
              canvas.restore();
            },
          ),
        );
      },
    ),
  );
}

/// Expanding golden ring: a cheap, readable "bottle complete" accent
/// (one stroke per frame instead of many particles).
class ShockRing extends PositionComponent {
  ShockRing({required Vector2 center, required this.maxRadius, this.color = const Color(0xFFFFD45C)})
    : super(position: center, priority: 30, anchor: Anchor.center);

  final double maxRadius;
  final Color color;
  double _t = 0;
  static const _duration = 0.55;

  @override
  void update(double dt) {
    _t += dt / _duration;
    if (_t >= 1) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final k = Curves.easeOutCubic.transform(_t.clamp(0, 1));
    canvas.drawCircle(
      Offset.zero,
      maxRadius * (0.35 + 0.65 * k),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = maxRadius * 0.12 * (1 - k) + 1
        ..color = color.withValues(alpha: (1 - k) * 0.9),
    );
  }
}
