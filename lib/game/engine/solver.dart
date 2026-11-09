import 'dart:collection';

import 'game_state.dart';

/// Finds solutions for a [GameState]. Used to validate levels and to make
/// sure the shuffle power-up never produces an unsolvable board.
class Solver {
  const Solver({this.maxStates = 200000});

  /// Safety cap on explored states so the solver never freezes the UI.
  final int maxStates;

  /// Depth-first search; fast, returns *a* solution (not necessarily optimal).
  List<Move>? solve(GameState start) {
    if (start.isSolved) return const [];
    final visited = <String>{start.canonicalKey};
    final path = <Move>[];
    var explored = 0;

    bool dfs(GameState state) {
      if (++explored > maxStates) return false;
      for (final move in _usefulMoves(state)) {
        final next = state.apply(move);
        if (!visited.add(next.canonicalKey)) continue;
        path.add(move);
        if (next.isSolved || dfs(next)) return true;
        path.removeLast();
      }
      return false;
    }

    return dfs(start) ? List.unmodifiable(path) : null;
  }

  bool isSolvable(GameState state) => solve(state) != null;

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
