import 'dart:math';

import 'package:ball_sort_party/game/engine/ball_type.dart';
import 'package:ball_sort_party/game/engine/game_engine.dart';
import 'package:ball_sort_party/game/engine/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GameState rules', () {
    test('can move onto empty bottle', () {
      final s = GameState.parse(['BF', '']);
      expect(s.canMove(0, 1), isTrue);
    });

    test('can move onto matching top', () {
      final s = GameState.parse(['BF', 'SF']);
      expect(s.canMove(0, 1), isTrue);
    });

    test('cannot move onto different type', () {
      final s = GameState.parse(['BF', 'FB']);
      expect(s.canMove(0, 1), isFalse);
    });

    test('cannot move into a full bottle', () {
      final s = GameState.parse(['BF', 'SFFF']);
      expect(s.canMove(0, 1), isFalse);
    });

    test('cannot move from empty or to itself', () {
      final s = GameState.parse(['', 'B']);
      expect(s.canMove(0, 1), isFalse);
      expect(s.canMove(1, 1), isFalse);
    });

    test('cannot move from a completed bottle', () {
      final s = GameState.parse(['BBBB', '']);
      expect(s.isComplete(0), isTrue);
      expect(s.canMove(0, 1), isFalse);
    });

    test('apply moves only the top ball', () {
      final s = GameState.parse(['BFF', 'F']).apply(const Move(0, 1));
      expect(s.toLayout(), ['BF', 'FF']);
    });

    test('solved when every bottle is empty or complete', () {
      expect(GameState.parse(['BBBB', 'FFFF', '']).isSolved, isTrue);
      expect(GameState.parse(['BBB', 'FFFF', 'B']).isSolved, isFalse);
    });

    test('custom capacity is respected', () {
      final s = GameState.parse(['BBB', 'B'], capacity: 3);
      expect(s.isComplete(0), isTrue);
      expect(s.canMove(1, 0), isFalse);
    });

    test('canonical key ignores bottle order', () {
      final a = GameState.parse(['BF', 'S', '']);
      final b = GameState.parse(['', 'S', 'BF']);
      expect(a.canonicalKey, b.canonicalKey);
    });

    test('parse rejects unknown codes', () {
      expect(() => GameState.parse(['BX']), throwsArgumentError);
    });
  });

  group('GameEngine tap flow', () {
    late GameEngine engine;
    setUp(() => engine = GameEngine(GameState.parse(['BF', 'BB', ''])));

    test('first tap selects, second tap on same bottle deselects', () {
      expect(engine.tap(0), isA<BallSelected>());
      expect(engine.selected, 0);
      expect(engine.tap(0), isA<BallDeselected>());
      expect(engine.selected, isNull);
    });

    test('tapping an empty bottle without selection is rejected', () {
      final r = engine.tap(2);
      expect(r, isA<MoveRejected>());
      expect((r! as MoveRejected).reason, InvalidReason.sourceEmpty);
      expect(engine.selected, isNull);
    });

    test('valid target moves the ball and clears selection', () {
      engine.tap(0);
      final r = engine.tap(2);
      expect(r, isA<BallMoved>());
      expect(engine.state.toLayout(), ['B', 'BB', 'F']);
      expect(engine.selected, isNull);
      expect(engine.moveCount, 1);
    });

    test('invalid target keeps selection and does not change state', () {
      engine.tap(0); // top = F
      final r = engine.tap(1); // top = B
      expect(r, isA<MoveRejected>());
      expect((r! as MoveRejected).reason, InvalidReason.mismatch);
      expect(engine.selected, 0);
      expect(engine.state.toLayout(), ['BF', 'BB', '']);
      expect(engine.moveCount, 0);
    });

    test('reports completed bottle and solved state', () {
      final e = GameEngine(GameState.parse(['BBB', 'FFFF', 'B']));
      e.tap(2);
      final r = e.tap(0) as BallMoved;
      expect(r.completedBottle, 0);
      expect(r.solved, isTrue);
      expect(e.isSolved, isTrue);
      expect(e.tap(0), isNull, reason: 'input ignored after win');
    });
  });

  group('Power-ups', () {
    test('undo restores the previous state', () {
      final e = GameEngine(GameState.parse(['BF', 'BB', '']));
      e.move(0, 2);
      expect(e.canUndo, isTrue);
      expect(e.undo(), const Move(0, 2));
      expect(e.state.toLayout(), ['BF', 'BB', '']);
      expect(e.canUndo, isFalse);
      expect(e.undo(), isNull);
    });

    test('extra bottle can be added once', () {
      final e = GameEngine(GameState.parse(['BF', 'FB']));
      expect(e.isStuck, isTrue);
      expect(e.addExtraBottle(), isTrue);
      expect(e.state.bottleCount, 3);
      expect(e.isStuck, isFalse);
      expect(e.addExtraBottle(), isFalse);
    });

    test('shuffle keeps balls, fill levels and completed bottles', () {
      final e = GameEngine(
        GameState.parse(['SSSS', 'BFBF', 'FBFB', '', '']),
      );
      expect(e.shuffle(Random(7)), isTrue);
      final s = e.state;
      expect(s.toLayout().first, 'SSSS');
      expect([for (final b in s.bottles) b.length], [4, 4, 4, 0, 0]);
      final counts = <BallType, int>{};
      for (final b in s.bottles) {
        for (final t in b) {
          counts[t] = (counts[t] ?? 0) + 1;
        }
      }
      expect(counts, {
        BallType.baseball: 4,
        BallType.basketball: 4,
        BallType.football: 4,
      });
      expect(s.isSolved, isFalse);
    });

    test('reset returns to the initial layout', () {
      final e = GameEngine(GameState.parse(['BF', 'BB', '']));
      e.move(0, 2);
      e.addExtraBottle();
      e.reset();
      expect(e.state.toLayout(), ['BF', 'BB', '']);
      expect(e.moveCount, 0);
      expect(e.canAddBottle, isTrue);
    });
  });
}
