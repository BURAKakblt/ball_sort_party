import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/animation.dart';

import '../../engine/ball_type.dart';
import '../../render/ball_painter.dart';

/// One tween segment of a ball's motion. Starts from wherever the ball is
/// when the segment begins, so animations can be interrupted smoothly.
class _Segment {
  _Segment({
    required this.duration,
    required this.target,
    this.curve = Curves.easeInOut,
    this.arcHeight = 0,
    this.onEnd,
  });

  final double duration;
  final Vector2 target;
  final Curve curve;

  /// When > 0 the path is a quadratic Bézier arcing above both endpoints.
  final double arcHeight;
  final VoidCallback? onEnd;

  late Vector2 start;
  double elapsed = 0;

  Vector2 at(double t) {
    final k = curve.transform(t.clamp(0, 1));
    if (arcHeight <= 0) return start + (target - start) * k;
    final control = Vector2(
      (start.x + target.x) / 2,
      math.min(start.y, target.y) - arcHeight,
    );
    final u = 1 - k;
    return start * (u * u) + control * (2 * u * k) + target * (k * k);
  }
}

/// A sport ball on the board with lift / arc / drop / bounce animations.
class BallComponent extends PositionComponent {
  BallComponent({required this.type, required double diameter, required Vector2 position})
    : super(
        position: position,
        size: Vector2.all(diameter),
        anchor: Anchor.center,
        priority: 5,
      );

  final BallType type;
  final List<_Segment> _queue = [];

  bool lifted = false;
  double _squash = 0; // seconds remaining
  double _wiggle = 0;
  double _popDelay = -1;
  double _pop = 1;
  double _hopDelay = -1;
  double _hop = 0;

  static const _squashTime = 0.18;
  static const _wiggleTime = 0.4;
  static const _hopTime = 0.45;

  double get radius => size.x * 0.47;
  bool get isAnimating => _queue.isNotEmpty;

  void resize(double diameter) => size = Vector2.all(diameter);

  void _go(List<_Segment> segments) {
    _queue
      ..clear()
      ..addAll(segments);
    if (_queue.isNotEmpty) _queue.first.start = position.clone();
  }

  /// Pick the ball up above its bottle.
  void lift(Vector2 liftPos) {
    lifted = true;
    _go([_Segment(duration: 0.16, target: liftPos, curve: Curves.easeOutBack)]);
  }

  /// Put the ball back into a slot with a little bounce.
  void dropTo(Vector2 slot, {VoidCallback? onLand}) {
    lifted = false;
    _go(_dropSegments(slot, 0.17, onLand));
  }

  /// Full transfer: (lift) → arc over to [above] → drop into [slot] → bounce.
  void flyTo({
    required Vector2 liftPos,
    required Vector2 above,
    required Vector2 slot,
    VoidCallback? onLand,
  }) {
    final arc = math.max(size.x * 0.9, (above.x - position.x).abs() * 0.18);
    _go([
      if (!lifted) _Segment(duration: 0.12, target: liftPos, curve: Curves.easeOut),
      _Segment(
        duration: 0.3,
        target: above,
        curve: Curves.easeInOutSine,
        arcHeight: arc,
        onEnd: () => lifted = false,
      ),
      ..._dropSegments(slot, 0.15, onLand),
    ]);
    lifted = true;
  }

  List<_Segment> _dropSegments(Vector2 slot, double time, VoidCallback? onLand) {
    final bounce = slot - Vector2(0, size.x * 0.14);
    return [
      _Segment(
        duration: time,
        target: slot,
        curve: Curves.easeInQuad,
        onEnd: () {
          _squash = _squashTime;
          onLand?.call();
        },
      ),
      _Segment(duration: 0.09, target: bounce, curve: Curves.easeOut),
      _Segment(duration: 0.1, target: slot.clone(), curve: Curves.easeIn),
    ];
  }

  /// Plain move (used for re-layouts).
  void moveTo(Vector2 target, {double duration = 0.3}) {
    lifted = false;
    _go([_Segment(duration: duration, target: target, curve: Curves.easeOutCubic)]);
  }

  void wiggle() => _wiggle = _wiggleTime;

  void popIn(double delay) {
    _pop = 0;
    _popDelay = delay;
  }

  void hop(double delay) {
    _hopDelay = delay;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_queue.isNotEmpty) {
      final seg = _queue.first;
      seg.elapsed += dt;
      final t = seg.duration <= 0 ? 1.0 : seg.elapsed / seg.duration;
      position.setFrom(seg.at(t));
      if (t >= 1) {
        _queue.removeAt(0);
        if (_queue.isNotEmpty) _queue.first.start = position.clone();
        seg.onEnd?.call();
      }
    }
    if (_squash > 0) _squash = math.max(0, _squash - dt);
    if (_wiggle > 0) _wiggle = math.max(0, _wiggle - dt);
    if (_popDelay >= 0) {
      _popDelay -= dt;
      if (_popDelay < 0) _pop = 0.0001;
    } else if (_pop < 1) {
      _pop = math.min(1, _pop + dt / 0.35);
    }
    if (_hopDelay >= 0) {
      _hopDelay -= dt;
      if (_hopDelay < 0) _hop = _hopTime;
    } else if (_hop > 0) {
      _hop = math.max(0, _hop - dt);
    }
  }

  @override
  void render(Canvas canvas) {
    final r = radius;
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);

    var sx = 1.0, sy = 1.0;
    if (_squash > 0) {
      final k = math.sin(_squash / _squashTime * math.pi) * 0.13;
      sx += k;
      sy -= k;
    }
    if (_pop < 1) {
      final s = _popDelay >= 0 ? 0.0 : Curves.easeOutBack.transform(_pop);
      sx *= s;
      sy *= s;
    }
    var dy = 0.0;
    if (_hop > 0) {
      final p = 1 - _hop / _hopTime;
      dy = -math.sin(p * math.pi) * size.x * 0.35;
    }
    if (lifted) {
      canvas.save();
      canvas.translate(0, r * 0.35);
      BallArt.drawShadow(canvas, r, opacity: 0.22);
      canvas.restore();
    }
    canvas.translate(0, dy + r * (1 - sy));
    if (_wiggle > 0) {
      final p = 1 - _wiggle / _wiggleTime;
      canvas.rotate(math.sin(p * math.pi * 6) * 0.25 * (1 - p));
    }
    canvas.scale(sx, sy);
    BallArt.draw(canvas, type, r);
    canvas.restore();
  }
}
