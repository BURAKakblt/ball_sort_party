import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Color scheme for a gift box.
class GiftPalette {
  const GiftPalette(this.light, this.dark);

  final Color light;
  final Color dark;

  static const all = [
    GiftPalette(Color(0xFFB58CFF), Color(0xFF5B2BC9)), // purple
    GiftPalette(Color(0xFF6FD9FF), Color(0xFF1F5FD1)), // blue
    GiftPalette(Color(0xFF6FF5E4), Color(0xFF0F9AA8)), // turquoise
  ];
}

/// Procedurally drawn 2.5D gift box with gold ribbons.
///
/// [lidOpen] goes 0 → 1 as the lid pops off; [glow] adds light rays behind.
class GiftBoxPainter extends CustomPainter {
  GiftBoxPainter({
    required this.palette,
    this.lidOpen = 0,
    this.glow = 0,
    this.dimmed = false,
  });

  final GiftPalette palette;
  final double lidOpen;
  final double glow;
  final bool dimmed;

  static const _gold = [Color(0xFFFFF0A8), Color(0xFFFFC53D), Color(0xFFD98A00)];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cx = w / 2;
    final bodyW = w * 0.74, bodyH = h * 0.44;
    final depth = bodyH * 0.22; // visible top face
    final bodyTop = h * 0.5;
    final body = Rect.fromLTWH(cx - bodyW / 2, bodyTop, bodyW, bodyH);

    // Light rays and glow behind an opened box.
    if (glow > 0) {
      final center = Offset(cx, bodyTop);
      canvas.drawCircle(
        center,
        w * 0.55,
        Paint()
          ..shader = ui.Gradient.radial(center, w * 0.55, [
            Color.fromRGBO(255, 236, 160, 0.75 * glow),
            const Color(0x00FFE9A0),
          ]),
      );
      final rays = Paint()..color = Color.fromRGBO(255, 245, 200, 0.35 * glow);
      for (var i = 0; i < 10; i++) {
        final a = i * math.pi / 5 + glow * 0.6;
        final path = Path()
          ..moveTo(center.dx, center.dy)
          ..lineTo(center.dx + math.cos(a - 0.09) * w, center.dy + math.sin(a - 0.09) * w)
          ..lineTo(center.dx + math.cos(a + 0.09) * w, center.dy + math.sin(a + 0.09) * w)
          ..close();
        canvas.drawPath(path, rays);
      }
    }

    // Ground shadow.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, body.bottom + h * 0.02), width: bodyW * 1.1, height: h * 0.07),
      Paint()
        ..color = const Color(0x55000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Inside of the box (visible when the lid is off).
    final topFace = Path()
      ..moveTo(body.left, body.top)
      ..lineTo(body.left + depth * 0.6, body.top - depth)
      ..lineTo(body.right - depth * 0.6, body.top - depth)
      ..lineTo(body.right, body.top)
      ..close();
    canvas.drawPath(topFace, Paint()..color = Color.lerp(palette.dark, Colors.black, 0.45)!);

    // Front face.
    final front = RRect.fromRectAndCorners(
      body,
      bottomLeft: Radius.circular(w * 0.05),
      bottomRight: Radius.circular(w * 0.05),
    );
    canvas.drawRRect(
      front,
      Paint()
        ..shader = ui.Gradient.linear(body.topLeft, body.bottomRight, [palette.light, palette.dark]),
    );
    // Side shading for volume.
    canvas.drawRRect(
      front,
      Paint()
        ..shader = ui.Gradient.linear(body.centerLeft, body.centerRight, [
          const Color(0x00000000),
          const Color(0x00000000),
          const Color(0x40000000),
        ], [0, 0.6, 1]),
    );
    // Vertical gold ribbon on the body.
    final ribbonW = bodyW * 0.18;
    final ribbon = Rect.fromLTWH(cx - ribbonW / 2, body.top, ribbonW, bodyH);
    canvas.drawRect(ribbon, Paint()..shader = ui.Gradient.linear(ribbon.centerLeft, ribbon.centerRight, _gold, [0, 0.5, 1]));
    // Glossy highlight.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(body.left + bodyW * 0.07, body.top + bodyH * 0.1, bodyW * 0.1, bodyH * 0.6),
        Radius.circular(bodyW * 0.05),
      ),
      Paint()..color = const Color(0x40FFFFFF),
    );

    // Lid (lifts, tilts and fades as it opens).
    final t = Curves.easeOutBack.transform(lidOpen.clamp(0, 1));
    canvas.save();
    canvas.translate(cx + t * w * 0.18, body.top - t * h * 0.32);
    canvas.rotate(t * 0.55);
    final lidOpacity = (1 - lidOpen * 0.85).clamp(0.0, 1.0);
    _paintLid(canvas, bodyW * 1.12, bodyH * 0.3, depth, lidOpacity);
    canvas.restore();

    if (dimmed) {
      canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0x660A0628));
    }
  }

  void _paintLid(Canvas canvas, double lidW, double lidH, double depth, double opacity) {
    final rect = Rect.fromLTWH(-lidW / 2, -lidH, lidW, lidH);
    final paintLayer = Paint()..color = Color.fromRGBO(0, 0, 0, opacity);
    canvas.saveLayer(rect.inflate(lidW), paintLayer);

    // Top face of the lid.
    final top = Path()
      ..moveTo(rect.left, rect.top)
      ..lineTo(rect.left + depth * 0.6, rect.top - depth)
      ..lineTo(rect.right - depth * 0.6, rect.top - depth)
      ..lineTo(rect.right, rect.top)
      ..close();
    canvas.drawPath(top, Paint()..color = palette.light);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(lidH * 0.18)),
      Paint()..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter, [palette.light, palette.dark]),
    );
    final band = lidW * 0.16;
    // Ribbon across lid front and top.
    canvas.drawRect(
      Rect.fromLTWH(-band / 2, rect.top, band, lidH),
      Paint()..shader = ui.Gradient.linear(Offset(-band / 2, 0), Offset(band / 2, 0), _gold, [0, 0.5, 1]),
    );
    canvas.drawPath(
      Path()
        ..moveTo(-band / 2, rect.top)
        ..lineTo(-band / 2 + depth * 0.1, rect.top - depth)
        ..lineTo(band / 2 - depth * 0.1, rect.top - depth)
        ..lineTo(band / 2, rect.top)
        ..close(),
      Paint()..color = _gold[1],
    );
    // Bow: two loops and a knot.
    final knot = Offset(0, rect.top - depth * 0.6);
    final loop = Paint()..shader = ui.Gradient.radial(knot, lidW * 0.4, _gold, [0, 0.5, 1]);
    for (final dir in [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(knot.dx, knot.dy);
      canvas.rotate(dir * -0.45);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(dir * lidW * 0.17, -lidW * 0.05), width: lidW * 0.32, height: lidW * 0.2),
        loop,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(dir * lidW * 0.17, -lidW * 0.05), width: lidW * 0.14, height: lidW * 0.07),
        Paint()..color = const Color(0x55A35A00),
      );
      canvas.restore();
    }
    canvas.drawCircle(knot, lidW * 0.06, Paint()..color = _gold[2]);
    canvas.drawCircle(knot - Offset(lidW * 0.015, lidW * 0.015), lidW * 0.025, Paint()..color = _gold[0]);
    canvas.restore();
  }

  @override
  bool shouldRepaint(GiftBoxPainter old) =>
      old.lidOpen != lidOpen || old.glow != glow || old.dimmed != dimmed || old.palette != palette;
}
