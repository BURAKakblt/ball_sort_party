import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../engine/ball_type.dart';

/// Draws glossy, shaded 2.5D sport balls procedurally (no image assets).
///
/// Pictures are cached per (type, radius) so the board can redraw cheaply
/// every frame.
abstract final class BallArt {
  static final Map<(BallType, int), (ui.Picture, ui.Picture)> _cache = {};

  /// Draws [type] centered at the canvas origin with radius [r].
  /// [rotation] spins the ball's pattern while lighting stays fixed.
  static void draw(Canvas canvas, BallType type, double r, {double rotation = 0}) {
    final key = (type, (r * 4).round());
    final (body, shade) = _cache.putIfAbsent(key, () {
      ui.Picture record(void Function(Canvas) paint) {
        final recorder = ui.PictureRecorder();
        paint(Canvas(recorder));
        return recorder.endRecording();
      }

      return (record((c) => _paintBody(c, type, r)), record((c) => _paintShade(c, type, r)));
    });
    if (rotation != 0) {
      canvas.save();
      canvas.rotate(rotation);
      canvas.drawPicture(body);
      canvas.restore();
    } else {
      canvas.drawPicture(body);
    }
    canvas.drawPicture(shade);
  }

  /// Soft contact shadow under a ball.
  static void drawShadow(Canvas canvas, double r, {double opacity = 0.35}) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, r * 0.92), width: r * 1.6, height: r * 0.42),
      Paint()
        ..color = const Color(0xFF000000).withValues(alpha: opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.12),
    );
  }

  /// Base color and pattern (rotatable).
  static void _paintBody(Canvas canvas, BallType type, double r) {
    final circle = Rect.fromCircle(center: Offset.zero, radius: r);
    final spec = _specs[type]!;

    canvas.save();
    canvas.clipPath(Path()..addOval(circle));

    // Base body with an off-center light source.
    canvas.drawRect(
      circle,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(-r * 0.35, -r * 0.4),
          r * 1.45,
          [spec.light, spec.base, spec.dark],
          [0, 0.55, 1],
        ),
    );

    switch (type) {
      case BallType.basketball:
        _basketball(canvas, r);
      case BallType.football:
        _football(canvas, r);
      case BallType.baseball:
        _baseball(canvas, r);
      case BallType.tennis:
        _tennis(canvas, r);
      case BallType.volleyball:
        _volleyball(canvas, r);
    }
    canvas.restore();
  }

  /// Lighting: core shadow, rim light, highlights and outline (fixed).
  static void _paintShade(Canvas canvas, BallType type, double r) {
    final circle = Rect.fromCircle(center: Offset.zero, radius: r);
    final spec = _specs[type]!;
    canvas.save();
    canvas.clipPath(Path()..addOval(circle));

    // Core shadow towards the bottom-right for volume.
    canvas.drawRect(
      circle,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(-r * 0.3, -r * 0.35),
          r * 1.55,
          [const Color(0x00000000), const Color(0x00000000), const Color(0x73000000)],
          [0, 0.55, 1],
        ),
    );
    // Rim light from the environment.
    canvas.drawCircle(
      Offset.zero,
      r * 0.97,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.07
        ..shader = ui.Gradient.linear(
          Offset(0, r),
          Offset(0, -r),
          [const Color(0x55FFFFFF), const Color(0x00FFFFFF)],
          [0, 0.45],
        ),
    );
    canvas.restore();

    // Specular highlights.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-r * 0.32, -r * 0.45),
        width: r * 0.9,
        height: r * 0.55,
      ),
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(-r * 0.32, -r * 0.48),
          r * 0.48,
          [const Color(0xCCFFFFFF), const Color(0x00FFFFFF)],
        ),
    );
    canvas.drawCircle(
      Offset(-r * 0.42, -r * 0.5),
      r * 0.09,
      Paint()..color = const Color(0xE6FFFFFF),
    );
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, r * 0.04)
        ..color = spec.dark.withValues(alpha: 0.8),
    );
  }

  static Paint _stroke(Color c, double w) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..color = c;

  static void _basketball(Canvas canvas, double r) {
    final p = _stroke(const Color(0xFF3A1606), r * 0.075);
    canvas.drawPath(
      Path()
        ..moveTo(0, -r)
        ..quadraticBezierTo(r * 0.12, 0, 0, r),
      p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-r, r * 0.02)
        ..quadraticBezierTo(0, r * 0.14, r, r * 0.02),
      p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-r * 0.62, -r * 0.82)
        ..quadraticBezierTo(-r * 0.1, 0, -r * 0.62, r * 0.82),
      p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(r * 0.62, -r * 0.82)
        ..quadraticBezierTo(r * 0.1, 0, r * 0.62, r * 0.82),
      p,
    );
  }

  static Path _polygon(Offset c, double radius, double rotation, int sides) {
    final path = Path();
    for (var i = 0; i < sides; i++) {
      final a = rotation + i * 2 * math.pi / sides;
      final pt = c + Offset(math.cos(a), math.sin(a)) * radius;
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    return path..close();
  }

  static void _football(Canvas canvas, double r) {
    const ink = Color(0xFF1D2235);
    final fill = Paint()..color = ink;
    final seam = _stroke(const Color(0xFF7A8098), r * 0.035);
    const up = -math.pi / 2;
    final center = Offset(r * 0.04, r * 0.06);
    final centerRadius = r * 0.33;
    canvas.drawPath(_polygon(center, centerRadius, up, 5), fill);
    for (var i = 0; i < 5; i++) {
      final a = up + i * 2 * math.pi / 5;
      final dir = Offset(math.cos(a), math.sin(a));
      final vertex = center + dir * centerRadius;
      final outer = center + dir * r * 0.98;
      canvas.drawLine(vertex, center + dir * r * 0.62, seam);
      canvas.drawPath(_polygon(outer, r * 0.32, a + math.pi, 5), fill);
      // Seams between neighbouring outer patches.
      final b = a + math.pi / 5;
      final mid = Offset(math.cos(b), math.sin(b));
      canvas.drawLine(center + mid * r * 0.5, center + mid * r * 1.1, seam);
    }
  }

  static void _stitchedSeam(Canvas canvas, double r, Path path, Color color, double width,
      {bool stitches = true}) {
    canvas.drawPath(path, _stroke(color, width));
    if (!stitches) return;
    final stitch = _stroke(color, width * 0.7);
    for (final metric in path.computeMetrics()) {
      for (var d = metric.length * 0.06; d < metric.length * 0.95; d += r * 0.16) {
        final t = metric.getTangentForOffset(d)!;
        final n = Offset(-t.vector.dy, t.vector.dx);
        final back = t.position - t.vector * r * 0.05;
        canvas.drawLine(back + n * r * 0.1, t.position, stitch);
        canvas.drawLine(back - n * r * 0.1, t.position, stitch);
      }
    }
  }

  static void _baseball(Canvas canvas, double r) {
    const red = Color(0xFFD7263D);
    final left = Path()
      ..moveTo(-r * 0.5, -r * 0.92)
      ..quadraticBezierTo(r * 0.05, 0, -r * 0.5, r * 0.92);
    final right = Path()
      ..moveTo(r * 0.5, -r * 0.92)
      ..quadraticBezierTo(-r * 0.05, 0, r * 0.5, r * 0.92);
    _stitchedSeam(canvas, r, left, red, r * 0.05);
    _stitchedSeam(canvas, r, right, red, r * 0.05);
  }

  static void _tennis(Canvas canvas, double r) {
    // Subtle felt texture.
    final rnd = math.Random(3);
    final felt = Paint()..color = const Color(0x22FFFFFF);
    for (var i = 0; i < 70; i++) {
      final a = rnd.nextDouble() * math.pi * 2;
      final d = math.sqrt(rnd.nextDouble()) * r;
      canvas.drawCircle(Offset(math.cos(a) * d, math.sin(a) * d), r * 0.03, felt);
    }
    final white = _stroke(const Color(0xFFF7FFE8), r * 0.11);
    canvas.drawPath(
      Path()
        ..moveTo(-r * 0.95, -r * 0.45)
        ..cubicTo(-r * 0.2, -r * 0.35, -r * 0.2, r * 0.35, -r * 0.95, r * 0.45),
      white,
    );
    canvas.drawPath(
      Path()
        ..moveTo(r * 0.95, -r * 0.45)
        ..cubicTo(r * 0.2, -r * 0.35, r * 0.2, r * 0.35, r * 0.95, r * 0.45),
      white,
    );
  }

  static void _volleyball(Canvas canvas, double r) {
    const colors = [Color(0xFF2F6BFF), Color(0xFFFFC83A), Color(0xFFF7F8FF)];
    final seam = _stroke(const Color(0xFF1B2D6B), r * 0.045);
    for (var k = 0; k < 3; k++) {
      final a = -math.pi / 2 + k * 2 * math.pi / 3;
      final b = a + 2 * math.pi / 3;
      Offset at(double ang, double d) => Offset(math.cos(ang), math.sin(ang)) * d;
      final panel = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(at(a + 0.6, r * 0.55).dx, at(a + 0.6, r * 0.55).dy,
            at(a, r * 1.3).dx, at(a, r * 1.3).dy)
        ..lineTo(at((a + b) / 2, r * 1.6).dx, at((a + b) / 2, r * 1.6).dy)
        ..lineTo(at(b, r * 1.3).dx, at(b, r * 1.3).dy)
        ..quadraticBezierTo(at(b + 0.6, r * 0.55).dx, at(b + 0.6, r * 0.55).dy, 0, 0)
        ..close();
      canvas.drawPath(panel, Paint()..color = colors[k]);
      // Inner stripe lines that follow the panel curve.
      for (final s in [0.45, 0.75]) {
        canvas.drawPath(
          Path()
            ..moveTo(at(a + 0.25, r * s).dx, at(a + 0.25, r * s).dy)
            ..quadraticBezierTo(at(a + 0.9, r * (s + 0.25)).dx, at(a + 0.9, r * (s + 0.25)).dy,
                at(a + 0.2, r * 1.3).dx, at(a + 0.2, r * 1.3).dy),
          _stroke(const Color(0x401B2D6B), r * 0.03),
        );
      }
      canvas.drawPath(
        Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(at(a + 0.6, r * 0.55).dx, at(a + 0.6, r * 0.55).dy,
              at(a, r * 1.3).dx, at(a, r * 1.3).dy),
        seam,
      );
    }
  }

  static const _specs = {
    BallType.basketball: _Spec(Color(0xFFFFB067), Color(0xFFF2711C), Color(0xFF9E3A06)),
    BallType.football: _Spec(Color(0xFFFFFFFF), Color(0xFFEDEFF6), Color(0xFF9DA3B8)),
    BallType.baseball: _Spec(Color(0xFFFFFEF8), Color(0xFFF4ECDD), Color(0xFFB3A48F)),
    BallType.tennis: _Spec(Color(0xFFF4FF8A), Color(0xFFCBEA2C), Color(0xFF6E9010)),
    BallType.volleyball: _Spec(Color(0xFFFFFFFF), Color(0xFFF0F2FF), Color(0xFF8E97C2)),
  };
}

class _Spec {
  const _Spec(this.light, this.base, this.dark);
  final Color light;
  final Color base;
  final Color dark;
}

/// Flutter widget that renders a single ball (used in menus).
class BallView extends StatelessWidget {
  const BallView(this.type, {super.key, this.size = 48, this.shadow = true});

  final BallType type;
  final double size;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * (shadow ? 1.12 : 1),
      child: CustomPaint(painter: _BallPainter(type, shadow)),
    );
  }
}

class _BallPainter extends CustomPainter {
  _BallPainter(this.type, this.shadow);

  final BallType type;
  final bool shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    canvas.translate(r, r);
    if (shadow) {
      canvas.save();
      canvas.translate(0, r * 0.18);
      BallArt.drawShadow(canvas, r);
      canvas.restore();
    }
    BallArt.draw(canvas, type, r);
  }

  @override
  bool shouldRepaint(_BallPainter old) => old.type != type || old.shadow != shadow;
}
