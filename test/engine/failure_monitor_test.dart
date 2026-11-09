import 'dart:async';

import 'package:ball_sort_party/game/engine/failure_monitor.dart';
import 'package:ball_sort_party/game/engine/game_state.dart';
import 'package:ball_sort_party/game/engine/solver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final analyzer = BoardAnalyzer(check: BoardAnalyzer.syncCheck);

  // 5 types, one empty bottle: has valid moves but is proven unsolvable.
  final unsolvableWithMoves = GameState.parse(['BBBF', 'TVVT', 'FFFS', 'BVTS', 'TSVS', '']);

  group('BoardAnalyzer', () {
    test('a solved board is always "won", never a failure', () async {
      expect(await analyzer.evaluate(GameState.parse(['BBBB', 'FFFF', ''])), BoardStatus.won);
    });

    test('no valid move = deadlock', () async {
      final dead = GameState.parse(['B', 'S', 'F'], capacity: 2);
      expect(dead.hasValidMoves, isFalse);
      expect(await analyzer.evaluate(dead), BoardStatus.deadlock);
    });

    test('valid moves but no solution = unsolvable', () async {
      expect(unsolvableWithMoves.hasValidMoves, isTrue);
      expect(await analyzer.evaluate(unsolvableWithMoves), BoardStatus.unsolvable);
    });

    test('solvable board keeps playing', () async {
      expect(await analyzer.evaluate(GameState.parse(['BF', 'FB', ''], capacity: 2)), BoardStatus.playing);
    });

    test('solver timeout is never reported as a failure', () async {
      expect(const Solver(maxStates: 5).analyze(unsolvableWithMoves), Solvability.unknown);
      final timedOut = BoardAnalyzer(check: (_) async => Solvability.unknown);
      expect(await timedOut.evaluate(unsolvableWithMoves), BoardStatus.playing);
    });

    test('solver errors are never reported as a failure', () async {
      final broken = BoardAnalyzer(check: (_) async => throw StateError('boom'));
      expect(await broken.evaluate(unsolvableWithMoves), BoardStatus.playing);
    });
  });

  group('FailureMonitor', () {
    test('opens the rescue only once per failed position', () async {
      final m = FailureMonitor(analyzer);
      expect(await m.check(unsolvableWithMoves, 7), BoardStatus.unsolvable);
      expect(await m.check(unsolvableWithMoves, 7), isNull);
      // A new failure after another move opens it again.
      expect(await m.check(unsolvableWithMoves, 9), BoardStatus.unsolvable);
    });

    test('stale results are ignored when the board changed meanwhile', () async {
      final gate = Completer<Solvability>();
      final m = FailureMonitor(BoardAnalyzer(check: (_) => gate.future));
      final pending = m.check(unsolvableWithMoves, 3);
      m.invalidate(); // e.g. player pressed undo
      gate.complete(Solvability.unsolvable);
      expect(await pending, isNull);
    });

    test('won board never triggers rescue', () async {
      final m = FailureMonitor(analyzer);
      expect(await m.check(GameState.parse(['BBBB', '']), 1), isNull);
    });

    test('reset allows the same move index to fail again (new attempt)', () async {
      final m = FailureMonitor(analyzer);
      expect(await m.check(unsolvableWithMoves, 2), isNotNull);
      m.reset();
      expect(await m.check(unsolvableWithMoves, 2), isNotNull);
    });
  });
}
