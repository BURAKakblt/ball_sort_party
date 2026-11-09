import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Full-screen confetti burst that plays once.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, this.count = 140, this.duration = const Duration(milliseconds: 3200)});

  final int count;
  final Duration duration;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _Piece {
  _Piece(math.Random r)
    : x = 0.5 + (r.nextDouble() - 0.5) * 0.25,
      vx = (r.nextDouble() - 0.5) * 1.6,
      vy = -(0.9 + r.nextDouble() * 1.1),
      spin = (r.nextDouble() - 0.5) * 18,
      wobble = r.nextDouble() * math.pi * 2,
      w = 6 + r.nextDouble() * 6,
      h = 10 + r.nextDouble() * 8,
      round = r.nextDouble() < 0.25,
      color = _colors[r.nextInt(_colors.length)];

  static const _colors = [
    Color(0xFF2EE6D6),
    Color(0xFFFFC53D),
    Color(0xFFFF5C8A),
    Color(0xFF9B6BFF),
    Color(0xFF7CF7A0),
    Color(0xFFFFFFFF),
  ];

  final double x, vx, vy, spin, wobble, w, h;
  final bool round;
  final Color color;
}

class _ConfettiBurstState extends State<ConfettiBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration)
    ..forward();
  late final List<_Piece> _pieces = List.generate(widget.count, (_) => _Piece(_rnd));
  final _rnd = math.Random();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(_pieces, _c),
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.anim) : super(repaint: anim);

  final List<_Piece> pieces;
  final Animation<double> anim;

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value * 3.2; // seconds
    final fade = anim.value < 0.75 ? 1.0 : (1 - anim.value) / 0.25;
    final paint = Paint();
    for (final p in pieces) {
      // Ballistic launch from the lower middle, with air drag + wobble.
      final x = p.x * size.width + p.vx * size.width * (1 - math.exp(-t * 1.6)) / 1.6 +
          math.sin(t * 5 + p.wobble) * 10;
      final y = size.height * 0.62 +
          p.vy * size.height * (1 - math.exp(-t * 1.8)) / 1.8 +
          0.5 * 0.55 * size.height * t * t * 0.35;
      if (y > size.height + 20) continue;
      paint.color = p.color.withValues(alpha: fade.clamp(0, 1));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * p.spin);
      final flip = math.cos(t * p.spin * 0.7 + p.wobble);
      canvas.scale(1, flip);
      if (p.round) {
        canvas.drawCircle(Offset.zero, p.w * 0.5, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: p.w, height: p.h), const Radius.circular(2)),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => false;
}
