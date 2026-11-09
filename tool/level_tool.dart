// ignore_for_file: avoid_print
// Generates candidate level layouts and prints their optimal move count.
// Usage: dart run tool/level_tool.dart
import 'dart:math';

import 'package:ball_sort_party/game/engine/ball_type.dart';
import 'package:ball_sort_party/game/engine/game_state.dart';
import 'package:ball_sort_party/game/engine/solver.dart';

void main() {
  // (types, empty bottles, min optimal moves, max optimal moves)
  const specs = [
    (2, 1, 3, 5),
    (3, 2, 5, 8),
    (3, 2, 8, 11),
    (3, 1, 9, 13),
    (3, 1, 12, 18),
    (4, 2, 12, 16),
    (4, 2, 15, 20),
    (4, 1, 15, 24),
    (5, 2, 18, 24),
    (5, 2, 22, 30),
  ];
  const solver = Solver(maxStates: 3000000);
  for (var i = 0; i < specs.length; i++) {
    final (types, empties, lo, hi) = specs[i];
    for (var seed = 1; seed < 5000; seed++) {
      final rnd = Random(seed * 31 + i);
      final balls = [
        for (final t in BallType.values.take(types)) ...List.filled(4, t),
      ]..shuffle(rnd);
      final bottles = [
        for (var b = 0; b < types; b++) balls.sublist(b * 4, b * 4 + 4),
        for (var e = 0; e < empties; e++) <BallType>[],
      ];
      final state = GameState(bottles);
      if (state.isSolved) continue;
      // Reject layouts where any bottle already has 3+ of a kind on the bottom.
      if (bottles.any((b) => b.length == 4 && b.toSet().length == 1)) continue;
      final min = solver.minimumMoves(state);
      if (min == null || min < lo || min > hi) continue;
      print("Level ${i + 1}: par=$min layout=${state.toLayout().map((s) => "'$s'").toList()}");
      break;
    }
  }
}
