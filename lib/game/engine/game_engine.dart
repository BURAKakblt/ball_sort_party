import 'dart:math';

import 'ball_type.dart';
import 'game_state.dart';
import 'solver.dart';

/// Why a move was rejected.
enum InvalidReason { sameBottle, sourceEmpty, sourceComplete, targetFull, mismatch }

/// Outcome of tapping a bottle.
sealed class TapResult {
  const TapResult();
}

/// A ball was picked up from [bottle].
class BallSelected extends TapResult {
  const BallSelected(this.bottle);
  final int bottle;
}

/// The picked-up ball was put back into [bottle].
class BallDeselected extends TapResult {
  const BallDeselected(this.bottle);
  final int bottle;
}

/// The ball moved. [completedBottle] is set when the move completed a bottle.
class BallMoved extends TapResult {
  const BallMoved(this.move, {this.completedBottle, this.solved = false});
  final Move move;
  final int? completedBottle;
  final bool solved;
}

/// The move was rejected; selection is kept on [selected].
class MoveRejected extends TapResult {
  const MoveRejected(this.target, this.reason, {this.selected});
  final int target;
  final InvalidReason reason;
  final int? selected;
}

/// Gameplay rules: selection, moves, undo and power-ups. Contains no
/// rendering or animation code so it can be unit tested in isolation.
class GameEngine {
  GameEngine(
    GameState initial, {
    this.maxExtraBottles = 1,
    this.solver = const Solver(),
  }) : _state = initial,
       _initial = initial;

  final GameState _initial;
  final Solver solver;
  final int maxExtraBottles;

  GameState _state;
  final List<Move> _history = [];
  int? _selected;
  int _moveCount = 0;
  int _extraBottlesAdded = 0;

  GameState get state => _state;
  int? get selected => _selected;
  int get moveCount => _moveCount;
  bool get isSolved => _state.isSolved;
  bool get canUndo => _history.isNotEmpty;
  bool get canAddBottle => _extraBottlesAdded < maxExtraBottles && !isSolved;
  int get extraBottlesAdded => _extraBottlesAdded;

  /// True when the player cannot make any move (and the puzzle isn't solved).
  bool get isStuck => !isSolved && !_state.hasValidMoves;

  InvalidReason? validate(int from, int to) {
    if (from == to) return InvalidReason.sameBottle;
    if (_state.isEmpty(from)) return InvalidReason.sourceEmpty;
    if (_state.isComplete(from)) return InvalidReason.sourceComplete;
    if (_state.isFull(to)) return InvalidReason.targetFull;
    final top = _state.topOf(to);
    if (top != null && top != _state.topOf(from)) return InvalidReason.mismatch;
    return null;
  }

  /// Handles a tap on bottle [index] following the select → target flow.
  TapResult? tap(int index) {
    if (isSolved || index < 0 || index >= _state.bottleCount) return null;
    final sel = _selected;
    if (sel == null) {
      if (_state.isEmpty(index)) {
        return MoveRejected(index, InvalidReason.sourceEmpty);
      }
      if (_state.isComplete(index)) {
        return MoveRejected(index, InvalidReason.sourceComplete);
      }
      _selected = index;
      return BallSelected(index);
    }
    if (sel == index) {
      _selected = null;
      return BallDeselected(index);
    }
    final reason = validate(sel, index);
    if (reason != null) return MoveRejected(index, reason, selected: sel);
    _selected = null;
    return _commit(Move(sel, index));
  }

  /// Applies a move directly (bypassing selection). Returns null if invalid.
  BallMoved? move(int from, int to) {
    if (validate(from, to) != null) return null;
    _selected = null;
    return _commit(Move(from, to));
  }

  BallMoved _commit(Move m) {
    _state = _state.apply(m);
    _history.add(m);
    _moveCount++;
    return BallMoved(
      m,
      completedBottle: _state.isComplete(m.to) ? m.to : null,
      solved: _state.isSolved,
    );
  }

  /// Reverts the last move. Returns the reverted move (from→to as played).
  Move? undo() {
    if (_history.isEmpty) return null;
    final last = _history.removeLast();
    _state = _state.transferUnchecked(last.to, last.from);
    _selected = null;
    _moveCount++;
    return last;
  }

  void clearSelection() => _selected = null;

  /// Adds an empty bottle. Returns false if the limit was reached.
  bool addExtraBottle() {
    if (!canAddBottle) return false;
    _state = _state.withExtraBottle();
    _extraBottlesAdded++;
    _selected = null;
    return true;
  }

  /// Randomly redistributes balls of unfinished bottles, keeping each bottle's
  /// fill level, and guarantees the result is solvable and not already solved.
  /// Returns false if no valid shuffle was found.
  bool shuffle(Random random, {int attempts = 40}) {
    if (isSolved) return false;
    final locked = <int>{
      for (var i = 0; i < _state.bottleCount; i++)
        if (_state.isComplete(i)) i,
    };
    final pool = <BallType>[
      for (var i = 0; i < _state.bottleCount; i++)
        if (!locked.contains(i)) ..._state.bottles[i],
    ];
    for (var a = 0; a < attempts; a++) {
      pool.shuffle(random);
      var cursor = 0;
      final next = <List<BallType>>[];
      for (var i = 0; i < _state.bottleCount; i++) {
        if (locked.contains(i)) {
          next.add(_state.bottles[i]);
        } else {
          final n = _state.bottles[i].length;
          next.add(pool.sublist(cursor, cursor + n));
          cursor += n;
        }
      }
      final candidate = GameState(next, capacity: _state.capacity);
      if (candidate.isSolved) continue;
      if (candidate.canonicalKey == _state.canonicalKey) continue;
      if (!solver.isSolvable(candidate)) continue;
      _state = candidate;
      _history.clear();
      _selected = null;
      return true;
    }
    return false;
  }

  /// Restores the starting layout.
  void reset() {
    _state = _initial;
    _history.clear();
    _selected = null;
    _moveCount = 0;
    _extraBottlesAdded = 0;
  }
}
