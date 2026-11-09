import 'dart:convert';

import 'package:ball_sort_party/data/economy_config.dart';
import 'package:ball_sort_party/data/player_progress.dart';
import 'package:ball_sort_party/data/progress_store.dart';
import 'package:ball_sort_party/game/engine/failure_monitor.dart';
import 'package:ball_sort_party/game/levels/level.dart';
import 'package:ball_sort_party/game/levels/level_data.dart';
import 'package:ball_sort_party/game/session/level_run.dart';
import 'package:ball_sort_party/game/session/level_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late DateTime now;
  DateTime clock() => now;
  final level1 = kLevels[0];
  final level2 = kLevels[1];

  Future<PlayerProgress> fresh() async {
    SharedPreferences.setMockInitialValues({});
    return PlayerProgress.load(clock: clock);
  }

  /// Simulates closing and reopening the app.
  Future<PlayerProgress> reopen() => PlayerProgress.load(clock: clock);

  /// Plays one valid move and fails the attempt.
  LevelSession failedSession(PlayerProgress p) {
    final s = LevelSession(level1, p);
    final m = s.engine.state.validMoves().first;
    s.engine.move(m.from, m.to);
    s.save();
    s.fail(BoardStatus.deadlock);
    return s;
  }

  setUp(() => now = DateTime(2026, 11, 9, 12));

  test('new attempt starts PLAYING and costs nothing', () async {
    final p = await fresh();
    final s = LevelSession(level1, p);
    expect(s.status, LevelStatus.playing);
    expect(p.lives, PlayerProgress.maxLives);
  });

  test('dead end → FAILED, persisted, no life lost', () async {
    final p = await fresh();
    final s = failedSession(p);
    expect(s.status, LevelStatus.failed);
    expect(p.isLevelFailed(1), isTrue);
    expect(p.lives, PlayerProgress.maxLives);
  });

  test('FAILED → main menu → same level → restart costs exactly 1 life', () async {
    final p = await fresh();
    failedSession(p); // then the player leaves to the menu
    final again = LevelSession(level1, p);
    expect(again.isFailed, isTrue, reason: 'leaving does not clear FAILED');
    expect(again.restart(), RestartResult.restartedPaidLife);
    expect(p.lives, PlayerProgress.maxLives - 1);
    expect(again.status, LevelStatus.playing);
    expect(again.engine.moveCount, 0);
    expect(p.isLevelFailed(1), isFalse);
  });

  test('FAILED survives closing and reopening the app (no automatic life loss)', () async {
    final p = await fresh();
    final s = failedSession(p);
    final layout = s.engine.state.toLayout();
    final reopened = await reopen();
    final restored = LevelSession(level1, reopened);
    expect(restored.isFailed, isTrue);
    expect(restored.failReason, BoardStatus.deadlock);
    expect(restored.engine.state.toLayout(), layout);
    expect(restored.engine.moveCount, 1);
    expect(reopened.lives, PlayerProgress.maxLives);
  });

  test('FAILED → undo → PLAYING (persisted)', () async {
    final p = await fresh();
    final s = failedSession(p);
    expect(s.engine.undo(), isNotNull);
    s.save(); // board change saved while still FAILED
    expect(p.isLevelFailed(1), isTrue);
    s.recover();
    expect(s.status, LevelStatus.playing);
    expect((await reopen()).isLevelFailed(1), isFalse);
  });

  test('FAILED → 200 coins rescue → PLAYING, coins charged once', () async {
    final p = await fresh();
    final s = failedSession(p);
    final ok = p.spend(EconomyConfig.rescueWithCoinsPrice, s.engine.addExtraBottle);
    expect(ok, isTrue);
    s.save();
    s.recover();
    expect(s.status, LevelStatus.playing);
    expect(p.coins, EconomyConfig.startingCoins - 200);
    // The level's extra bottle is used: a second coin rescue can't happen.
    expect(p.spend(EconomyConfig.rescueWithCoinsPrice, s.engine.addExtraBottle), isFalse);
    expect(p.coins, EconomyConfig.startingCoins - 200);
  });

  test('normal restart while PLAYING is free', () async {
    final p = await fresh();
    final s = LevelSession(level1, p);
    final m = s.engine.state.validMoves().first;
    s.engine.move(m.from, m.to);
    s.save();
    expect(s.restart(), RestartResult.restartedFree);
    expect(p.lives, PlayerProgress.maxLives);
    expect(p.runFor(1), isNull);
  });

  test('zero lives: a FAILED level cannot be restarted', () async {
    final p = await fresh();
    final s = failedSession(p);
    for (var i = 0; i < PlayerProgress.maxLives; i++) {
      p.loseLife();
    }
    final layout = s.engine.state.toLayout();
    expect(s.restart(), RestartResult.noLives);
    expect(s.isFailed, isTrue);
    expect(s.engine.state.toLayout(), layout);
    expect(p.isLevelFailed(1), isTrue);
  });

  test('retry spends exactly one life even if triggered twice', () async {
    final p = await fresh();
    final s = failedSession(p);
    expect(s.restart(), RestartResult.restartedPaidLife);
    expect(s.restart(), RestartResult.restartedFree, reason: 'now PLAYING');
    expect(p.lives, PlayerProgress.maxLives - 1);
    expect(p.payRetry(1), isFalse, reason: 'nothing left to pay for');
    expect(p.lives, PlayerProgress.maxLives - 1);
  });

  test('winning → COMPLETED, clears FAILED/run, rewards once', () async {
    final p = await fresh();
    final s = LevelSession(level1, p);
    s.save();
    final coins = s.complete(3);
    expect(s.status, LevelStatus.completed);
    expect(coins, EconomyConfig.levelReward(1, kLevels.length));
    expect(s.complete(3), coins);
    expect(p.coins, EconomyConfig.startingCoins + coins, reason: 'not paid twice');
    expect(p.runFor(1), isNull);
  });

  test('a recovered level can be completed and the FAILED flag is gone', () async {
    final p = await fresh();
    final s = failedSession(p);
    s.engine.undo();
    s.recover();
    s.complete(2);
    expect(p.isLevelFailed(1), isFalse);
    expect(p.runFor(1), isNull);
  });

  test('switching levels never clears another level\'s FAILED state', () async {
    final p = await fresh();
    failedSession(p);
    final other = LevelSession(level2, p);
    final m = other.engine.state.validMoves().first;
    other.engine.move(m.from, m.to);
    other.save();
    other.restart();
    other.complete(3);
    expect(p.isLevelFailed(1), isTrue);
  });

  test('FAILED cannot be overwritten by a PLAYING save or discarded', () async {
    final p = await fresh();
    final s = failedSession(p);
    expect(p.saveRun(1, LevelRun.fromEngine(s.engine, LevelStatus.playing)), isFalse);
    expect(p.discardRun(1), isFalse);
    expect(p.isLevelFailed(1), isTrue);
  });

  test('an unfinished PLAYING attempt is saved and resumed (incl. undo history)', () async {
    final p = await fresh();
    final s = LevelSession(level1, p);
    for (final m in s.engine.state.validMoves().take(1)) {
      s.engine.move(m.from, m.to);
    }
    s.engine.addExtraBottle();
    s.save();
    final resumed = LevelSession(level1, await reopen());
    expect(resumed.status, LevelStatus.playing);
    expect(resumed.engine.state.toLayout(), s.engine.state.toLayout());
    expect(resumed.engine.canUndo, isTrue);
    expect(resumed.engine.canAddBottle, isFalse, reason: 'extra bottle limit kept');
  });

  test('corrupted saved attempts are ignored', () async {
    SharedPreferences.setMockInitialValues({
      'player_progress_v1': jsonEncode({
        'runs': {
          '1': {'status': 'failed', 'layout': ['XX'], 'history': [], 'moves': 1, 'extra': 0},
          '2': 'garbage',
        },
      }),
    });
    final p = await PlayerProgress.load(clock: clock);
    expect(p.runFor(1), isNull);
    expect(p.runFor(2), isNull);
    expect(LevelSession(level1, p).status, LevelStatus.playing);
  });

  group('saved attempts after a level layout update', () {
    test('new saves carry the level signature and reject a changed level', () async {
      final p = await fresh();
      final s = LevelSession(level1, p);
      final m = s.engine.state.validMoves().first;
      s.engine.move(m.from, m.to);
      s.save();
      final run = p.runFor(1)!;
      expect(run.levelSig, LevelRun.signatureOf(level1.layout));
      expect(run.isValidFor(level1), isTrue);
      final changed = Level(number: 1, par: 3, layout: [...level1.layout.reversed]);
      expect(run.isValidFor(changed), isFalse);
    });

    test('legacy save (no signature) is kept only if its history leads to the level start', () {
      final s = LevelSession(level1, PlayerProgress.withStore(_NullStore()));
      final m = s.engine.state.validMoves().first;
      s.engine.move(m.from, m.to);
      final json = LevelRun.fromEngine(s.engine, LevelStatus.failed, failReason: BoardStatus.deadlock).toJson()
        ..remove('sig');
      final legacy = LevelRun.fromJson(json)!;
      expect(legacy.levelSig, isNull);
      expect(legacy.isValidFor(level1), isTrue);
      final changed = Level(number: 1, par: 3, layout: [...level1.layout.reversed]);
      expect(legacy.isValidFor(changed), isFalse);
    });
  });
}

class _NullStore implements ProgressStore {
  @override
  String? read(String key) => null;
  @override
  Future<bool> write(String key, String value) async => true;
  @override
  Future<void> remove(String key) async {}
}
