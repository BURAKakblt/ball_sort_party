// ignore_for_file: avoid_print
// Finds layouts for a difficulty target: (types, empty bottles, par range,
// casual-player win-rate range). Usage: dart run tool/level_search.dart
import 'dart:math';

import 'package:ball_sort_party/game/engine/ball_type.dart';
import 'package:ball_sort_party/game/engine/game_state.dart';
import 'package:ball_sort_party/game/engine/solver.dart';

import 'package:ball_sort_party/game/levels/difficulty.dart';

void main() {
  // (level, types, empties, parMin, parMax, winMin, winMax)
  const targets = [
    (2, 3, 2, 5, 8, 95, 100),
    (3, 3, 2, 8, 10, 90, 100),
    (4, 4, 2, 10, 13, 88, 97),
    (5, 4, 2, 12, 15, 75, 88),
    (6, 5, 2, 15, 19, 62, 76),
    (7, 3, 1, 9, 13, 48, 62),
    (8, 5, 2, 17, 22, 36, 48),
    (9, 4, 1, 13, 19, 22, 35),
    (10, 4, 1, 15, 22, 10, 20),
  ];
  const solver = Solver(maxStates: 3000000);
  for (final (n, types, empties, pMin, pMax, wMin, wMax) in targets) {
    String? hit;
    for (var seed = 1; seed < 3000 && hit == null; seed++) {
      final rnd = Random(seed * 7919 + n);
      final balls = [for (final t in BallType.values.take(types)) ...List.filled(4, t)]..shuffle(rnd);
      final bottles = [
        for (var b = 0; b < types; b++) balls.sublist(b * 4, b * 4 + 4),
        for (var e = 0; e < empties; e++) <BallType>[],
      ];
      if (bottles.any((b) => b.length == 4 && b.sublist(0, 3).toSet().length == 1)) continue;
      final state = GameState(bottles);
      // Cheapest filter first: BFS is fast for ≤4 types, playouts for 5.
      int? par;
      if (types <= 4) {
        par = solver.minimumMoves(state);
        if (par == null || par < pMin || par > pMax) continue;
      }
      final quick = casualWins(state, playouts: 150, seed: seed);
      if (quick < wMin - 6 || quick > wMax + 6) continue;
      final win = casualWins(state, playouts: 2000, seed: 1);
      if (win < wMin || win > wMax) continue;
      par ??= solver.minimumMoves(state);
      if (par == null || par < pMin || par > pMax) continue;
      hit = 'L$n par=$par win=${win.toStringAsFixed(1)}% ${state.toLayout()}';
    }
    print(hit ?? 'L$n: no match');
  }
}
