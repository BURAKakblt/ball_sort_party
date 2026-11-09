import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart' show EdgeInsets;
import 'package:flutter/services.dart';

import '../engine/game_engine.dart';
import 'components/ball_component.dart';
import 'components/bottle_component.dart';
import 'components/sparkles.dart';

/// Callbacks from the board to the surrounding Flutter UI.
class BoardListener {
  const BoardListener({
    this.onChanged,
    this.onInvalid,
    this.onSolved,
    this.onStuck,
  });

  /// Board state changed (move count, undo availability…).
  final VoidCallback? onChanged;
  final void Function(InvalidReason reason)? onInvalid;

  /// Fired after the victory animation has played.
  final VoidCallback? onSolved;

  /// No valid moves are left.
  final VoidCallback? onStuck;
}

/// Renders a [GameEngine] and turns taps into animated moves.
///
/// All rule decisions are delegated to the engine; this class is only
/// responsible for visuals, input and feedback.
class BallSortGame extends FlameGame {
  BallSortGame({
    required this.engine,
    this.listener = const BoardListener(),
    this.hapticsEnabled = _alwaysTrue,
  });

  static bool _alwaysTrue() => true;

  final GameEngine engine;
  final BoardListener listener;
  final bool Function() hapticsEnabled;

  final List<BottleComponent> _bottles = [];
  final List<List<BallComponent>> _balls = [];

  double _d = 48; // ball diameter
  List<Rect> _rects = [];
  bool _celebrating = false;

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    _rebuild(animateIn: true);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) _relayout(animate: false);
  }

  // ------------------------------------------------------------------ layout

  /// Computes bottle rects for [count] bottles within the current canvas.
  void _computeLayout(int count) {
    final cap = engine.state.capacity;
    final rows = count <= 5 ? 1 : 2;
    final perRow = (count / rows).ceil();
    final w = size.x, h = size.y;
    const margin = 16.0;
    // In ball diameters:
    const bottleW = 1.24, gap = 0.55, headroom = 0.5, base = 0.12;
    const liftRoom = 1.25, rowGap = 0.35;
    final bottleH = cap + headroom + base;
    final byWidth = (w - margin * 2) / (perRow * bottleW + (perRow - 1) * gap);
    final byHeight = (h - 24) / (rows * (bottleH + liftRoom) + (rows - 1) * rowGap);
    _d = math.max(18, math.min(math.min(byWidth, byHeight), 74));

    final totalH = rows * (bottleH + liftRoom) * _d + (rows - 1) * rowGap * _d;
    var top = (h - totalH) / 2 + liftRoom * _d;
    _rects = [];
    var i = 0;
    for (var r = 0; r < rows; r++) {
      final inRow = math.min(perRow, count - i);
      final rowW = inRow * bottleW * _d + (inRow - 1) * gap * _d;
      var x = (w - rowW) / 2;
      for (var k = 0; k < inRow; k++) {
        _rects.add(Rect.fromLTWH(x, top, bottleW * _d, bottleH * _d));
        x += (bottleW + gap) * _d;
        i++;
      }
      top += (bottleH + liftRoom + rowGap) * _d;
    }
  }

  /// Bottle bounds in game coordinates (used by UI tests).
  Rect bottleRect(int index) => _rects[index];

  Vector2 _slot(int bottle, int index) {
    final r = _rects[bottle];
    return Vector2(r.center.dx, r.bottom - _d * 0.12 - _d / 2 - index * _d);
  }

  Vector2 _liftPos(int bottle) {
    final r = _rects[bottle];
    return Vector2(r.center.dx, r.top - _d * 0.62);
  }

  EdgeInsets get _hitPadding =>
      EdgeInsets.fromLTRB(_d * 0.27, _d * 1.2, _d * 0.27, _d * 0.3);

  void _rebuild({bool animateIn = false}) {
    for (final b in _bottles) {
      b.front.removeFromParent();
      b.removeFromParent();
    }
    for (final list in _balls) {
      for (final ball in list) {
        ball.removeFromParent();
      }
    }
    _bottles.clear();
    _balls.clear();
    _celebrating = false;

    final state = engine.state;
    _computeLayout(state.bottleCount);
    for (var i = 0; i < state.bottleCount; i++) {
      _addBottle(i);
      final list = <BallComponent>[];
      for (var k = 0; k < state.bottles[i].length; k++) {
        final ball = BallComponent(
          type: state.bottles[i][k],
          diameter: _d,
          position: _slot(i, k),
        );
        if (animateIn) ball.popIn(0.15 + i * 0.05 + k * 0.06);
        list.add(ball);
        add(ball);
      }
      _balls.add(list);
    }
  }

  void _addBottle(int i) {
    final r = _rects[i];
    final bottle = BottleComponent(
      index: i,
      onTap: _onBottleTap,
      position: Vector2(r.left, r.top),
      size: Vector2(r.width, r.height),
      hitPadding: _hitPadding,
    )..completed = engine.state.isComplete(i);
    _bottles.add(bottle);
    add(bottle);
    add(bottle.front);
  }

  void _relayout({required bool animate}) {
    _computeLayout(_bottles.length);
    for (var i = 0; i < _bottles.length; i++) {
      final r = _rects[i];
      _bottles[i]
        ..position = Vector2(r.left, r.top)
        ..size = Vector2(r.width, r.height)
        ..hitPadding = _hitPadding;
      for (var k = 0; k < _balls[i].length; k++) {
        final ball = _balls[i][k]..resize(_d);
        final target = engine.selected == i && k == _balls[i].length - 1
            ? _liftPos(i)
            : _slot(i, k);
        if (animate) {
          ball.moveTo(target, duration: 0.35);
          if (target == _liftPos(i)) ball.lifted = true;
        } else {
          ball.position = target;
        }
      }
    }
  }

  // ------------------------------------------------------------------ input

  void _haptic(Future<void> Function() fn) {
    if (hapticsEnabled()) fn();
  }

  void _onBottleTap(int index) {
    if (_celebrating) return;
    final previous = engine.selected;
    final result = engine.tap(index);
    switch (result) {
      case null:
        return;
      case BallSelected(:final bottle):
        _bottles[bottle].selected = true;
        _balls[bottle].last.lift(_liftPos(bottle));
        _haptic(HapticFeedback.selectionClick);
      case BallDeselected(:final bottle):
        _bottles[bottle].selected = false;
        final list = _balls[bottle];
        list.last.dropTo(_slot(bottle, list.length - 1));
      case BallMoved(:final move, :final completedBottle, :final solved):
        if (previous != null) _bottles[previous].selected = false;
        _animateTransfer(move.from, move.to, onLand: () {
          _haptic(HapticFeedback.lightImpact);
          if (completedBottle != null) _completeBottle(completedBottle);
          if (solved) {
            _celebrate();
          } else if (engine.isStuck) {
            listener.onStuck?.call();
          }
        });
        listener.onChanged?.call();
      case MoveRejected(:final target, :final reason, :final selected):
        _bottles[target].shake();
        if (selected != null) _balls[selected].last.wiggle();
        _haptic(HapticFeedback.mediumImpact);
        listener.onInvalid?.call(reason);
    }
  }

  void _animateTransfer(int from, int to, {VoidCallback? onLand}) {
    final ball = _balls[from].removeLast();
    _balls[to].add(ball);
    ball.priority = 10; // fly above other balls
    ball.flyTo(
      liftPos: _liftPos(from),
      above: _liftPos(to),
      slot: _slot(to, _balls[to].length - 1),
      onLand: () {
        ball.priority = 5;
        onLand?.call();
      },
    );
  }

  void _completeBottle(int index) {
    final bottle = _bottles[index];
    bottle
      ..completed = true
      ..celebrate();
    add(sparkleBurst(Vector2(_rects[index].center.dx, _rects[index].top), _d / 56));
  }

  void _dropSelection() {
    final sel = engine.selected;
    if (sel == null) return;
    engine.clearSelection();
    _bottles[sel].selected = false;
    final list = _balls[sel];
    list.last.dropTo(_slot(sel, list.length - 1));
  }

  void _celebrate() {
    _celebrating = true;
    _haptic(HapticFeedback.heavyImpact);
    var delay = 0.25;
    for (var i = 0; i < _balls.length; i++) {
      for (var k = _balls[i].length - 1; k >= 0; k--) {
        _balls[i][k].hop(delay + (_balls[i].length - 1 - k) * 0.05);
      }
      if (_balls[i].isNotEmpty) {
        final at = Vector2(_rects[i].center.dx, _rects[i].top);
        add(TimerComponent(
          period: delay + 0.2,
          removeOnFinish: true,
          onTick: () => add(sparkleBurst(at, _d / 56, count: 18)),
        ));
      }
      delay += 0.09;
    }
    add(TimerComponent(
      period: delay + 0.7,
      removeOnFinish: true,
      onTick: () => listener.onSolved?.call(),
    ));
  }

  // ------------------------------------------------------------------ power-ups

  /// Animated undo. Returns false if there is nothing to undo.
  bool undo() {
    if (_celebrating) return false;
    _dropSelection();
    final move = engine.undo();
    if (move == null) return false;
    _bottles[move.to].completed = false;
    _animateTransfer(move.to, move.from);
    listener.onChanged?.call();
    return true;
  }

  /// Adds an empty bottle and slides everything into the new layout.
  bool addExtraBottle() {
    if (_celebrating) return false;
    _dropSelection();
    if (!engine.addExtraBottle()) return false;
    _computeLayout(engine.state.bottleCount);
    _addBottle(engine.state.bottleCount - 1);
    _balls.add([]);
    _relayout(animate: true);
    listener.onChanged?.call();
    return true;
  }

  /// Shuffles unfinished bottles. Returns false if no shuffle was possible.
  bool shuffle(math.Random random) {
    if (_celebrating) return false;
    _dropSelection();
    if (!engine.shuffle(random)) return false;
    _rebuild(animateIn: true);
    listener.onChanged?.call();
    return true;
  }

  /// Restores the level's starting layout.
  void restart() {
    engine.reset();
    _rebuild(animateIn: true);
    listener.onChanged?.call();
  }
}
