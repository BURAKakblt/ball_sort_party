import 'package:ball_sort_party/game/engine/ball_type.dart';
import 'package:ball_sort_party/game/engine/game_state.dart';
import 'package:ball_sort_party/game/engine/solver.dart';
import 'package:ball_sort_party/game/levels/difficulty.dart';
import 'package:ball_sort_party/game/levels/level_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('there are 10 levels numbered 1..10', () {
    expect(kLevels.map((l) => l.number), List.generate(10, (i) => i + 1));
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

      test('is not already solved and is solvable', () {
        final state = level.createState();
        expect(state.isSolved, isFalse);
        final solution = const Solver().solve(state);
        expect(solution, isNotNull);
        var s = state;
        for (final m in solution!) {
          s = s.apply(m);
        }
        expect(s.isSolved, isTrue);
      });

      test('star thresholds', () {
        expect(level.starsFor(level.par), 3);
        expect(level.starsFor(level.par * 10), 1);
      });
    });
  }

  test('level 1 is a short, forgiving tutorial', () {
    final l1 = kLevels.first;
    expect(l1.par, lessThanOrEqualTo(3));
    expect(l1.ballTypes.length, 2);
    expect(casualWins(l1.createState(), playouts: 500), 100);
  });

  test('difficulty rises gradually (casual-player win rate)', () {
    final rates = [for (final l in kLevels) casualWins(l.createState(), playouts: 1000)];
    for (var i = 1; i < rates.length; i++) {
      // Never noticeably easier than the previous level…
      expect(rates[i], lessThanOrEqualTo(rates[i - 1] + 3), reason: 'L${i + 1} $rates');
      // …and no sudden wall.
      expect(rates[i - 1] - rates[i], lessThan(30), reason: 'L${i + 1} $rates');
    }
    expect(rates.last, greaterThan(5), reason: 'last level stays beatable');
  });

  test('new ball types are introduced one at a time', () {
    var known = <BallType>{};
    for (final l in kLevels) {
      final added = l.ballTypes.difference(known);
      expect(added.length, lessThanOrEqualTo(l.number == 1 ? 2 : 1), reason: 'L${l.number}');
      known = {...known, ...l.ballTypes};
    }
    expect(known, BallType.values.toSet());
  });

  test('par values are the true optimum', () {
    for (final l in kLevels) {
      expect(const Solver(maxStates: 3000000).minimumMoves(l.createState()), l.par, reason: 'L${l.number}');
    }
  });

  test('solver detects an unsolvable board', () {
    expect(const Solver().isSolvable(GameState.parse(['BF', 'FB'])), isFalse);
  });

  test('BFS finds the optimum on a tiny board', () {
    expect(const Solver().minimumMoves(GameState.parse(['BBBF', 'B', 'FFF'])), 2);
  });
}
