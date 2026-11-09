import 'package:ball_sort_party/game/engine/ball_type.dart';
import 'package:ball_sort_party/game/engine/game_state.dart';
import 'package:ball_sort_party/game/engine/solver.dart';
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

  test('difficulty never decreases', () {
    for (var i = 1; i < kLevels.length; i++) {
      expect(kLevels[i].par, greaterThanOrEqualTo(kLevels[i - 1].par));
    }
  });

  test('solver detects an unsolvable board', () {
    expect(const Solver().isSolvable(GameState.parse(['BF', 'FB'])), isFalse);
  });

  test('BFS finds the optimum on a tiny board', () {
    expect(const Solver().minimumMoves(GameState.parse(['BBBF', 'B', 'FFF'])), 2);
  });
}
