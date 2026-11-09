import 'dart:math';

import '../engine/game_state.dart';

/// Win rate (%) of a simulated casual player: usually stacks onto a matching
/// ball (75 %), sometimes experiments, never directly reverses its last move,
/// gives up after 150 moves. Higher = more forgiving. Used to tune the level
/// curve (`tool/level_metrics.dart`) and guard it in tests.
double casualWins(GameState start, {int playouts = 2000, int seed = 1}) {
  final rnd = Random(seed);
  var wins = 0;
  for (var p = 0; p < playouts; p++) {
    var s = start;
    Move? last;
    for (var step = 0; step < 150 && !s.isSolved; step++) {
      final prev = last;
      final moves = s
          .validMoves()
          .where((m) => prev == null || !(m.from == prev.to && m.to == prev.from))
          .toList();
      if (moves.isEmpty) break;
      final stacking = moves.where((m) => !s.isEmpty(m.to)).toList();
      final pool = stacking.isNotEmpty && rnd.nextDouble() < 0.75 ? stacking : moves;
      last = pool[rnd.nextInt(pool.length)];
      s = s.apply(last);
    }
    if (s.isSolved) wins++;
  }
  return 100 * wins / playouts;
}
