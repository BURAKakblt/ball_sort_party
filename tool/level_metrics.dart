// ignore_for_file: avoid_print
// Difficulty metrics for levels.
// Usage: dart run tool/level_metrics.dart          (report shipped levels)
import 'dart:math';

import 'package:ball_sort_party/game/levels/difficulty.dart';
import 'package:ball_sort_party/game/engine/solver.dart';
import 'package:ball_sort_party/game/levels/level.dart';
import 'package:ball_sort_party/game/levels/level_data.dart';

void main() {
  print('lvl types bottles par  states  deadEnd%  casualWin%  layout');
  for (final l in kLevels) {
    final r = analyze(l);
    print('${'${l.number}'.padLeft(3)} ${'${l.ballTypes.length}'.padLeft(5)} '
        '${'${l.layout.length}'.padLeft(7)} ${'${r.par}'.padLeft(3)} ${'${r.states}'.padLeft(7)} '
        '${r.deadEndPct.toStringAsFixed(1).padLeft(8)} ${r.randomWinPct.toStringAsFixed(1).padLeft(10)}  ${l.layout}');
  }
}

typedef Report = ({int par, int states, double deadEndPct, double randomWinPct});

/// Reachable state space + random-play success rate (a proxy for how
/// forgiving a level is: higher = easier).
Report analyze(Level level, {int playouts = 2000, int seed = 1}) {
  final start = level.createState();
  final par = const Solver(maxStates: 3000000).minimumMoves(start) ?? -1;
  final seen = <String>{start.canonicalKey};
  final queue = [start];
  var dead = 0;
  const solver = Solver(maxStates: 20000);
  for (var i = 0; i < queue.length && i < 60000; i++) {
    final s = queue[i];
    if (!s.isSolved && solver.analyze(s) == Solvability.unsolvable) dead++;
    for (final m in s.validMoves()) {
      final n = s.apply(m);
      if (seen.add(n.canonicalKey)) queue.add(n);
    }
  }
  final wins = casualWins(start, playouts: playouts, seed: seed);
  final checked = min(queue.length, 60000);
  return (par: par, states: queue.length, deadEndPct: 100 * dead / checked, randomWinPct: wins);
}
