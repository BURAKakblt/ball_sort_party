import 'dart:isolate';

import 'game_state.dart';
import 'solver.dart';

/// State of the board after the player's last move settled.
enum BoardStatus {
  won,
  playing,

  /// No valid move exists at all (certain dead end).
  deadlock,

  /// Moves exist, but the solver proved no solution remains.
  unsolvable,
}

typedef SolvabilityCheck = Future<Solvability> Function(GameState state);

/// Decides whether the player has failed, without blocking the UI.
class BoardAnalyzer {
  BoardAnalyzer({SolvabilityCheck? check}) : _check = check ?? isolateCheck;

  final SolvabilityCheck _check;

  /// Explored-state budget for the background check. Running out of budget
  /// yields [Solvability.unknown], which is never treated as a failure.
  static const budget = 150000;

  /// Runs the solver on a background isolate.
  static Future<Solvability> isolateCheck(GameState state) =>
      Isolate.run(() => const Solver(maxStates: budget).analyze(state));

  /// Runs the solver synchronously (tests).
  static Future<Solvability> syncCheck(GameState state) async =>
      const Solver(maxStates: budget).analyze(state);

  /// Order matters: a won board can never be reported as failed.
  Future<BoardStatus> evaluate(GameState state) async {
    if (state.isSolved) return BoardStatus.won;
    if (!state.hasValidMoves) return BoardStatus.deadlock;
    try {
      final result = await _check(state);
      return result == Solvability.unsolvable ? BoardStatus.unsolvable : BoardStatus.playing;
    } catch (_) {
      return BoardStatus.playing; // never show a false failure
    }
  }
}

/// Runs [BoardAnalyzer] after each settled move and decides when the rescue
/// screen should open: once per failed position, ignoring stale results.
class FailureMonitor {
  FailureMonitor(this.analyzer);

  final BoardAnalyzer analyzer;
  int _generation = 0;
  int? _shownForMove;

  /// Call when the board settled after move number [moveIndex]. Returns the
  /// failure status if the rescue screen should open now, otherwise null.
  Future<BoardStatus?> check(GameState state, int moveIndex) async {
    final generation = ++_generation;
    final status = await analyzer.evaluate(state);
    if (generation != _generation) return null; // board changed meanwhile
    final failed = status == BoardStatus.deadlock || status == BoardStatus.unsolvable;
    if (!failed || _shownForMove == moveIndex) return null;
    _shownForMove = moveIndex;
    return status;
  }

  /// Discards any pending check (undo, power-up, restart…).
  void invalidate() => _generation++;

  void reset() {
    _generation++;
    _shownForMove = null;
  }
}
