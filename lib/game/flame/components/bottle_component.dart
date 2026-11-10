import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

/// Glass bottle. Renders the back of the glass; [BottleFront] renders the
/// reflective front layer above the balls.
class BottleComponent extends PositionComponent with TapCallbacks {
  BottleComponent({
    required this.index,
    required this.onTap,
    required Vector2 position,
    required Vector2 size,
    required this.hitPadding,
  }) : super(position: position, size: size, priority: 0);

  final int index;
  final void Function(int index) onTap;

  /// Extra touch area around the bottle (top, sides) for easier tapping.
  EdgeInsets hitPadding;

  bool selected = false;
  bool completed = false;
  double _shake = 0;
  double _glow = 0; // 0..1 selection glow
  double _complete = 0; // 0..1 completion glow
  double _pulse = 0;
  double _appear = 0;

  static const _shakeTime = 0.42;

  late final BottleFront front = BottleFront(this);

  double get shakeOffset {
    if (_shake <= 0) return 0;
    final p = 1 - _shake / _shakeTime;
    return math.sin(p * math.pi * 7) * size.x * 0.12 * (1 - p);
  }

  void shake() => _shake = _shakeTime;

  void celebrate() => _pulse = 1;

  @override
  bool containsLocalPoint(Vector2 point) {
    return point.x >= -hitPadding.left &&
        point.x <= size.x + hitPadding.right &&
        point.y >= -hitPadding.top &&
        point.y <= size.y + hitPadding.bottom;
  }

  @override
  void onTapDown(TapDownEvent event) => onTap(index);

  @override
  void update(double dt) {
    super.update(dt);
    if (_shake > 0) _shake = math.max(0, _shake - dt);
    _glow += ((selected ? 1 : 0) - _glow) * math.min(1, dt * 14);
    _complete += ((completed ? 1 : 0) - _complete) * math.min(1, dt * 6);
    if (_pulse > 0) _pulse = math.max(0, _pulse - dt * 1.6);
    if (_appear < 1) _appear = math.min(1, _appear + dt * 3);
  }

  /// Body outline: straight sides with a rounded "test tube" bottom.
  Path bodyPath() {
    final w = size.x, h = size.y;
    final r = w / 2;
    return Path()
      ..moveTo(0, 0)
      ..lineTo(0, h - r)
      ..arcToPoint(Offset(w, h - r), radius: Radius.circular(r), clockwise: false)
      ..lineTo(w, 0);
  }

  @override
  void render(ui.Canvas canvas) {
    final w = size.x, h = size.y;
    final appear = Curves.easeOutBack.transform(_appear);
    canvas.save();
    canvas.translate(shakeOffset + w / 2, h);
    canvas.scale(1, appear);
    canvas.translate(-w / 2, -h);

    final paints = _paints();
    final body = paints.body;

    // Contact shadow grounds the bottle on the board.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w / 2, h + w * 0.04), width: w * 1.35, height: w * 0.3),
      paints.contactShadow,
    );

    // Outer glow: turquoise when selected, gold when complete.
    final glowColor = Color.lerp(
      const Color(0xFF2EE6D6),
      const Color(0xFFFFC53D),
      _complete,
    )!;
    final glowStrength = math.max(_glow, _complete * 0.8) + _pulse * 0.8;
    if (glowStrength > 0.01) {
      canvas.drawPath(
        body,
        Paint()
          ..color = glowColor.withValues(alpha: 0.55 * glowStrength.clamp(0, 1))
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.22
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.16),
      );
    }

    // Back glass tint, inner edge shading (depth) and a soft base fill.
    canvas.drawPath(body, paints.backTint);
    canvas.drawPath(body, paints.innerShade);
    canvas.drawPath(body, paints.baseFill);
    canvas.restore();
  }

  _BottlePaints? _cache;

  /// Shaders depend only on the size: build them once per size instead of
  /// every frame.
  _BottlePaints _paints() {
    final c = _cache;
    if (c != null && c.size == size) return c;
    return _cache = _BottlePaints(size.clone(), bodyPath()..close());
  }
}

class _BottlePaints {
  _BottlePaints(this.size, this.body) {
    final w = size.x, h = size.y;
    backTint = Paint()
      ..shader = ui.Gradient.linear(Offset.zero, Offset(w, 0), [
        const Color(0x33FFFFFF),
        const Color(0x0FFFFFFF),
        const Color(0x08FFFFFF),
        const Color(0x2AFFFFFF),
      ], [0, 0.3, 0.7, 1]);
    innerShade = Paint()
      ..shader = ui.Gradient.linear(Offset.zero, Offset(w, 0), [
        const Color(0x330A0630),
        const Color(0x000A0630),
        const Color(0x000A0630),
        const Color(0x400A0630),
      ], [0, 0.22, 0.78, 1]);
    baseFill = Paint()
      ..shader = ui.Gradient.linear(Offset(0, h), Offset(0, h * 0.4), [
        const Color(0x337B5CFF),
        const Color(0x007B5CFF),
      ]);
    contactShadow = Paint()
      ..shader = ui.Gradient.radial(Offset(w / 2, h + w * 0.04), w * 0.68, [
        const Color(0x66050320),
        const Color(0x00050320),
      ]);
    final lipH = math.max(8.0, w * 0.16);
    final lip = RRect.fromRectAndRadius(
      Rect.fromLTWH(-w * 0.08, -h * 0.025, w * 1.16, lipH),
      Radius.circular(w * 0.1),
    );
    this.lip = lip;
    lipFill = Paint()
      ..shader = ui.Gradient.linear(lip.outerRect.topCenter, lip.outerRect.bottomCenter, [
        const Color(0xEEFFFFFF),
        const Color(0x88C9C2FF),
      ]);
    strip = Paint()
      ..shader = ui.Gradient.linear(Offset(0, h * 0.08), Offset(0, h * 0.8), [
        const Color(0x80FFFFFF),
        const Color(0x00FFFFFF),
      ]);
  }

  final Vector2 size;
  final Path body;
  late final Paint backTint, innerShade, baseFill, contactShadow, lipFill, strip;
  late final RRect lip;
}

/// Front glass layer drawn above the balls: rim, outline and reflections.
class BottleFront extends PositionComponent {
  BottleFront(this.bottle) : super(priority: 20);

  final BottleComponent bottle;

  @override
  void update(double dt) {
    super.update(dt);
    position.setFrom(bottle.position);
    size.setFrom(bottle.size);
  }

  @override
  void render(ui.Canvas canvas) {
    final w = size.x, h = size.y;
    final appear = Curves.easeOutBack.transform(bottle._appear);
    canvas.save();
    canvas.translate(bottle.shakeOffset + w / 2, h);
    canvas.scale(1, appear);
    canvas.translate(-w / 2, -h);

    final paints = bottle._paints();
    final outline = paints.body;
    final selected = bottle._glow;
    // Soft rim light just outside the glass edge (no blur: cheap).
    canvas.drawPath(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.12
        ..color = Color.lerp(const Color(0x14FFFFFF), const Color(0x402EE6D6), selected)!,
    );
    canvas.drawPath(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2, w * 0.045)
        ..strokeJoin = StrokeJoin.round
        ..shader = ui.Gradient.linear(Offset.zero, Offset(w, h), [
          Color.lerp(const Color(0xCCFFFFFF), const Color(0xFF7CFFF1), selected)!,
          const Color(0x66FFFFFF),
          const Color(0xAAFFFFFF),
        ], [0, 0.6, 1]),
    );

    // Vertical reflection strips.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.12, h * 0.08, w * 0.11, h * 0.72),
        Radius.circular(w * 0.06),
      ),
      paints.strip,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.78, h * 0.12, w * 0.05, h * 0.35),
        Radius.circular(w * 0.03),
      ),
      Paint()..color = const Color(0x33FFFFFF),
    );

    // Thick glass base: a bright arc inside the rounded bottom.
    final r = w / 2;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(r, h - r), radius: r * 0.8),
      math.pi * 0.2,
      math.pi * 0.6,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(1.5, w * 0.05)
        ..color = const Color(0x40FFFFFF),
    );

    // Rim / lip with a small specular glint.
    final lip = paints.lip;
    canvas.drawRRect(lip, paints.lipFill);
    canvas.drawRRect(
      lip,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0x66372A8A),
    );
    canvas.drawOval(
      Rect.fromLTWH(lip.left + w * 0.1, lip.top + lip.height * 0.18, w * 0.26, lip.height * 0.32),
      Paint()..color = const Color(0xCCFFFFFF),
    );

    // Completed: cork-like cap with a check mark.
    final c = bottle._complete;
    if (c > 0.02) {
      final capH = w * 0.32;
      final cap = RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.02, -capH * c - h * 0.01, w * 0.96, capH),
        Radius.circular(w * 0.14),
      );
      canvas.drawRRect(
        cap,
        Paint()
          ..shader = ui.Gradient.linear(cap.outerRect.topCenter, cap.outerRect.bottomCenter, [
            const Color(0xFFFFE27A).withValues(alpha: c),
            const Color(0xFFF29A12).withValues(alpha: c),
          ]),
      );
      final check = Path()
        ..moveTo(cap.left + w * 0.3, cap.center.dy)
        ..lineTo(cap.left + w * 0.45, cap.center.dy + capH * 0.22)
        ..lineTo(cap.left + w * 0.7, cap.center.dy - capH * 0.22);
      canvas.drawPath(
        check,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.07
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFFFFFFFF).withValues(alpha: c),
      );
    }
    canvas.restore();
  }
}
