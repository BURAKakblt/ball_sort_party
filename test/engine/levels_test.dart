import 'package:ball_sort_party/game/engine/ball_type.dart';
import 'package:ball_sort_party/game/engine/game_state.dart';
import 'package:ball_sort_party/game/engine/solver.dart';
import 'package:ball_sort_party/game/levels/difficulty.dart';
import 'package:ball_sort_party/game/levels/level_data.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/level_gen.dart' show distance, relabelKey;

void main() {
  const bigSolver = Solver(maxStates: 3000000);

  test('there are 50 levels numbered 1..50', () {
    expect(kLevels.map((l) => l.number), List.generate(50, (i) => i + 1));
  });

  for (final level in kLevels) {
    group('Level ${level.number}', () {
      test('every ball type appears exactly `capacity` times', () {
        final counts = <BallType, int>{};
        for (final b in level.createState().bottles) {
          expect(b.length, lessThanOrEqualTo(level.capacity));
          for (final t in b) {
            counts[t] = (counts[t] ?? 0) + 1;
          }
        }
        expect(counts.values.every((c) => c == level.capacity), isTrue);
      });

      test('is PROVEN solvable (no solver limit hit) and replays to a win', () {
        final state = level.createState();
        expect(state.isSolved, isFalse);
        expect(bigSolver.analyze(state), Solvability.solvable);
        final solution = bigSolver.solve(state)!;
        var s = state;
        for (final m in solution) {
          s = s.apply(m);
        }
        expect(s.isSolved, isTrue);
      });

      test('par is the true optimum', () {
        expect(bigSolver.minimumMoves(level.createState()), level.par);
      });

      test('star thresholds', () {
        expect(level.starsFor(level.par), 3);
        expect(level.starsFor(level.par * 10), 1);
      });
    });
  }

  test('no level is repeated, even with the sports renamed', () {
    final keys = <String, int>{};
    for (final l in kLevels) {
      final k = relabelKey(l.layout);
      expect(keys.containsKey(k), isFalse, reason: 'L${l.number} == L${keys[k]}');
      keys[k] = l.number;
    }
  });

  test('levels are not near-duplicates (≥25 % balls differ, ≤1 shared bottle)', () {
    for (var i = 0; i < kLevels.length; i++) {
      for (var j = i + 1; j < kLevels.length; j++) {
        final a = kLevels[i].layout, b = kLevels[j].layout;
        final shared = a.where((x) => x.isNotEmpty).toSet().intersection(b.toSet());
        expect(shared.length, lessThanOrEqualTo(1), reason: 'L${i + 1}/L${j + 1}');
        final d1 = distance(a, b);
        if (d1 == null) continue;
        final d2 = distance(b, a)!;
        expect(d1 < d2 ? d1 : d2, greaterThanOrEqualTo((a.join().length / 4).ceil()), reason: 'L${i + 1}/L${j + 1}');
      }
    }
  });

  test('new sports are introduced one at a time, all appear by level 9', () {
    var known = <BallType>{};
    for (final l in kLevels) {
      final added = l.ballTypes.difference(known);
      expect(added.length, lessThanOrEqualTo(l.number == 1 ? 2 : 1), reason: 'L${l.number}');
      known = {...known, ...l.ballTypes};
      if (l.number == 9) expect(known, BallType.values.toSet());
    }
  });

  group('difficulty curve (simulated casual player — an estimate, not real data)', () {
    late final List<double> rate = [
      for (final l in kLevels) casualWins(l.createState(), playouts: 1000),
    ];
    double avg(Iterable<double> xs) => xs.reduce((a, b) => a + b) / xs.length;
    List<double> band(LevelBand b) => rate.sublist(b.first - 1, b.last);
    double parAvg(LevelBand b) => avg(kLevels.sublist(b.first - 1, b.last).map((l) => l.par.toDouble()));

    test('level 1 is a 3-move tutorial; levels 1–3 are won by (almost) everyone', () {
      expect(kLevels.first.par, lessThanOrEqualTo(3));
      for (var i = 0; i < 3; i++) {
        expect(rate[i], greaterThanOrEqualTo(98), reason: 'L${i + 1}');
      }
    });

    test('each band stays in its window', () {
      const windows = {
        LevelBand.tutorial: (90.0, 100.0),
        LevelBand.easy: (60.0, 100.0),
        LevelBand.medium: (40.0, 75.0),
        LevelBand.mediumHard: (15.0, 52.0),
        LevelBand.hard: (1.5, 26.0),
      };
      for (final e in windows.entries) {
        for (final r in band(e.key)) {
          expect(r, inInclusiveRange(e.value.$1, e.value.$2), reason: '${e.key} $rate');
        }
      }
      expect(rate[9], greaterThan(50), reason: 'level 10 is no longer a wall');
    });

    test('bands get harder: lower win rate AND longer optimal solutions', () {
      const bands = LevelBand.values;
      for (var i = 1; i < bands.length; i++) {
        expect(avg(band(bands[i])), lessThan(avg(band(bands[i - 1]))), reason: '${bands[i]}');
        expect(parAvg(bands[i]), greaterThan(parAvg(bands[i - 1])), reason: '${bands[i]} par');
      }
    });

    test('no sudden walls or easy dips between neighbouring levels', () {
      for (var i = 1; i < rate.length; i++) {
        expect(rate[i - 1] - rate[i], lessThan(16), reason: 'wall at L${i + 1}: $rate');
        expect(rate[i] - rate[i - 1], lessThan(10), reason: 'dip at L${i + 1}: $rate');
      }
    });
  });

  test('solver detects an unsolvable board', () {
    expect(const Solver().isSolvable(GameState.parse(['BF', 'FB'])), isFalse);
  });

  test('BFS finds the optimum on a tiny board', () {
    expect(const Solver().minimumMoves(GameState.parse(['BBBF', 'B', 'FFF'])), 2);
  });
}
