import 'dart:collection';

import 'game_state.dart';

/// Result of a bounded solvability search.
enum Solvability {
  solvable,

  /// The whole reachable state space was searched: no solution exists.
  unsolvable,

  /// The search hit [Solver.maxStates]; nothing can be concluded.
  unknown,
}

/// Finds solutions for a [GameState]. Used to validate levels and to make
/// sure the shuffle power-up never produces an unsolvable board.
class Solver {
  const Solver({this.maxStates = 200000});

  /// Safety cap on explored states so the solver never freezes the UI.
  final int maxStates;

  /// Depth-first search; fast, returns *a* solution (not necessarily optimal).
  List<Move>? solve(GameState start) => _search(start).$1;

  bool isSolvable(GameState state) => solve(state) != null;

  /// Like [solve] but distinguishes "proven unsolvable" from "gave up".
  Solvability analyze(GameState start) {
    final (path, capped) = _search(start);
    if (path != null) return Solvability.solvable;
    return capped ? Solvability.unknown : Solvability.unsolvable;
  }

  (List<Move>?, bool capped) _search(GameState start) {
    if (start.isSolved) return (const [], false);
    final visited = <String>{start.canonicalKey};
    final path = <Move>[];
    var explored = 0;
    var capped = false;

    bool dfs(GameState state) {
      if (++explored > maxStates) {
        capped = true;
        return false;
      }
      for (final move in _usefulMoves(state)) {
        if (capped) return false;
        final next = state.apply(move);
        if (!visited.add(next.canonicalKey)) continue;
        path.add(move);
        if (next.isSolved || dfs(next)) return true;
        path.removeLast();
      }
      return false;
    }

    final found = dfs(start);
    return (found ? List<Move>.unmodifiable(path) : null, capped);
  }

  /// Breadth-first search; returns the minimum number of moves, or null.
  /// Only used offline (tests / level tooling) because it can be expensive.
  int? minimumMoves(GameState start) {
    if (start.isSolved) return 0;
    final visited = <String>{start.canonicalKey};
    final queue = Queue<(GameState, int)>()..add((start, 0));
    while (queue.isNotEmpty) {
      final (state, depth) = queue.removeFirst();
      if (visited.length > maxStates) return null;
      for (final move in _usefulMoves(state)) {
        final next = state.apply(move);
        if (!visited.add(next.canonicalKey)) continue;
        if (next.isSolved) return depth + 1;
        queue.add((next, depth + 1));
      }
    }
    return null;
  }

  /// Valid moves minus the obviously pointless ones.
  Iterable<Move> _usefulMoves(GameState s) sync* {
    var emptyTargetUsed = false;
    var currentFrom = -1;
    for (final move in s.validMoves()) {
      if (move.from != currentFrom) {
        currentFrom = move.from;
        emptyTargetUsed = false;
      }
      final source = s.bottles[move.from];
      final sourceUniform = source.every((t) => t == source.first);
      if (s.isEmpty(move.to)) {
        // Moving a uniform stack into an empty bottle changes nothing, and
        // all empty bottles are equivalent so try only one per source.
        if (sourceUniform) continue;
        if (emptyTargetUsed) continue;
        emptyTargetUsed = true;
      }
      yield move;
    }
  }
}
