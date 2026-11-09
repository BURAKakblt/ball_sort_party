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

    final body = bodyPath()..close();

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

    // Back glass tint.
    canvas.drawPath(
      body,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(w, 0), [
          const Color(0x33FFFFFF),
          const Color(0x0FFFFFFF),
          const Color(0x08FFFFFF),
          const Color(0x2AFFFFFF),
        ], [0, 0.3, 0.7, 1]),
    );
    // Soft liquid-like base fill.
    canvas.drawPath(
      body,
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, h), Offset(0, h * 0.4), [
          const Color(0x337B5CFF),
          const Color(0x007B5CFF),
        ]),
    );
    canvas.restore();
  }
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

    final outline = bottle.bodyPath();
    final selected = bottle._glow;
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
    final strip = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.12, h * 0.08, w * 0.11, h * 0.72),
      Radius.circular(w * 0.06),
    );
    canvas.drawRRect(
      strip,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, h * 0.08),
          Offset(0, h * 0.8),
          [const Color(0x80FFFFFF), const Color(0x00FFFFFF)],
        ),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.78, h * 0.12, w * 0.05, h * 0.35),
        Radius.circular(w * 0.03),
      ),
      Paint()..color = const Color(0x33FFFFFF),
    );

    // Rim / lip.
    final lip = RRect.fromRectAndRadius(
      Rect.fromLTWH(-w * 0.08, -h * 0.025, w * 1.16, math.max(8, w * 0.16)),
      Radius.circular(w * 0.1),
    );
    canvas.drawRRect(
      lip,
      Paint()
        ..shader = ui.Gradient.linear(lip.outerRect.topCenter, lip.outerRect.bottomCenter, [
          const Color(0xEEFFFFFF),
          const Color(0x88C9C2FF),
        ]),
    );
    canvas.drawRRect(
      lip,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0x66372A8A),
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
