import 'dart:convert';
import 'dart:math';

import 'package:ball_sort_party/data/economy_config.dart';
import 'package:ball_sort_party/data/player_progress.dart';
import 'package:ball_sort_party/data/progress_store.dart';
import 'package:ball_sort_party/game/engine/failure_monitor.dart';
import 'package:ball_sort_party/game/levels/level_data.dart';
import 'package:ball_sort_party/game/session/level_session.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory store that can simulate failed writes.
class MemoryStore implements ProgressStore {
  final Map<String, String> data = {};
  bool failWrites = false;
  int writes = 0;

  @override
  String? read(String key) => data[key];

  @override
  Future<bool> write(String key, String value) async {
    writes++;
    if (failWrites) return false;
    data[key] = value;
    return true;
  }

  @override
  Future<void> remove(String key) async => data.remove(key);
}

void main() {
  late MemoryStore store;
  final now = DateTime(2026, 11, 9, 12);
  PlayerProgress open() => PlayerProgress.withStore(store, clock: () => now);
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() => store = MemoryStore());

  /// Level 1 attempt with one move played, then marked FAILED.
  LevelSession failed(PlayerProgress p) {
    final s = LevelSession(kLevels.first, p);
    final m = s.engine.state.validMoves().first;
    s.engine.move(m.from, m.to);
    s.save();
    s.fail(BoardStatus.deadlock);
    return s;
  }

  group('coin rescue is atomic', () {
    test('coins + extra bottle + board are saved in ONE write', () async {
      final p = open();
      final s = failed(p);
      await settle();
      final before = store.writes;
      final r = s.paidRescue(EconomyConfig.rescueWithCoinsPrice, s.engine.addExtraBottle);
      await settle();
      expect(r, PurchaseResult.success);
      expect(store.writes - before, 1);
      final saved = open();
      expect(saved.coins, EconomyConfig.startingCoins - 200);
      expect(saved.runFor(1)!.extraBottlesAdded, 1);
    });

    test('a failed write persists neither the charge nor the bottle', () async {
      final p = open();
      final s = failed(p);
      await settle();
      store.failWrites = true;
      s.paidRescue(EconomyConfig.rescueWithCoinsPrice, s.engine.addExtraBottle);
      await settle();
      expect(p.hasUnsavedChanges, isTrue);
      // "Crash" now: the stored save is the consistent pre-purchase state.
      final crashed = open();
      expect(crashed.coins, EconomyConfig.startingCoins);
      expect(crashed.runFor(1)!.extraBottlesAdded, 0);
      expect(crashed.isLevelFailed(1), isTrue);
      // Storage recovers: the next save writes both changes together.
      store.failWrites = false;
      expect(await p.flush(), isTrue);
      expect(p.hasUnsavedChanges, isFalse);
      final recovered = open();
      expect(recovered.coins, EconomyConfig.startingCoins - 200);
      expect(recovered.runFor(1)!.extraBottlesAdded, 1);
    });

    test('no charge when the bottle cannot be added', () async {
      final p = open();
      final s = failed(p);
      s.engine.addExtraBottle(); // slot already used
      final r = s.paidRescue(EconomyConfig.rescueWithCoinsPrice, s.engine.addExtraBottle);
      expect(r, PurchaseResult.notApplicable);
      expect(p.coins, EconomyConfig.startingCoins);
    });

    test('no bottle without enough coins', () async {
      final p = open();
      p.spend(150, () => true); // 50 left
      final s = failed(p);
      final r = s.paidRescue(EconomyConfig.rescueWithCoinsPrice, s.engine.addExtraBottle);
      expect(r, PurchaseResult.insufficientCoins);
      expect(s.engine.state.bottleCount, kLevels.first.createState().bottleCount);
      expect(p.coins, 50);
    });

    test('the same rescue request twice is charged once (also after restart)', () async {
      final p = open();
      final s = failed(p);
      var applied = 0;
      bool apply() {
        applied++;
        return true;
      }

      expect(s.paidRescue(200, apply), PurchaseResult.success);
      expect(s.paidRescue(200, apply), PurchaseResult.alreadyProcessed);
      expect(applied, 1);
      expect(p.coins, EconomyConfig.startingCoins - 200);
      await settle();
      // Same failure after an app restart: still recognised.
      final again = LevelSession(kLevels.first, open());
      expect(again.rescueRequestId, s.rescueRequestId);
      expect(again.paidRescue(200, apply), PurchaseResult.alreadyProcessed);
      expect(applied, 1);
    });

    test('an exception inside a transaction rolls everything back', () async {
      final p = open();
      await settle();
      final writes = store.writes;
      expect(
        () => p.transaction(() {
          p.addCoins(999);
          p.buyUndoPack();
          throw StateError('boom');
        }),
        throwsStateError,
      );
      expect(p.coins, EconomyConfig.startingCoins);
      expect(p.undos, EconomyConfig.startingUndos);
      await settle();
      expect(store.writes, writes, reason: 'nothing written');
    });
  });

  group('save migration', () {
    // Exact shapes written by earlier releases (all under player_progress_v1).
    final e0aeffc = {
      'coins': 410, 'lives': 3, 'nextLifeAt': null, 'unlocked': 4,
      'stars': {'1': 3, '2': 2, '3': 1}, 'shuffles': 5, 'extraBottles': 1,
      'dailyClaim': '2026-11-08', 'dailyStreak': 2,
      'sound': true, 'music': false, 'haptics': false,
    };
    final c616e29c = {
      ...e0aeffc, 'undos': 2, 'giftAt': now.millisecondsSinceEpoch, 'giftId': 'coins150',
      'sfxVolume': 0.4, 'musicVolume': 0.25, 'reduceMotion': true,
    };
    Map<String, Object?> fafe9d6() {
      final s = LevelSession(kLevels.first, open());
      final m = s.engine.state.validMoves().first;
      s.engine.move(m.from, m.to);
      final run = {
        'status': 'failed', 'reason': 'deadlock', 'layout': s.engine.state.toLayout(),
        'history': [[m.from, m.to]], 'moves': 1, 'extra': 0, // no failId yet
      };
      store.data.clear();
      return {...c616e29c, 'runs': {'1': run}};
    }

    test('first release save (e0aeffc) loads with defaults', () {
      store.data[SaveSchema.legacyKey] = jsonEncode(e0aeffc);
      final p = open();
      expect(p.coins, 410);
      expect(p.unlockedLevel, 4);
      expect(p.starsFor(2), 2);
      expect(p.shuffles, 5);
      expect(p.musicOn, isFalse);
      expect(p.hapticsOn, isFalse);
      expect(p.undos, EconomyConfig.startingUndos);
      expect(p.canOpenGift, isTrue);
    });

    test('616e29c save keeps audio settings, undos and gift timer', () {
      store.data[SaveSchema.legacyKey] = jsonEncode(c616e29c);
      final p = open();
      expect(p.undos, 2);
      expect(p.sfxVolume, 0.4);
      expect(p.musicVolume, 0.25);
      expect(p.reduceMotion, isTrue);
      expect(p.canOpenGift, isFalse);
      expect(p.lastGift?.id, 'coins150');
    });

    test('fafe9d6 save keeps FAILED attempts and gets a stable rescue id', () {
      store.data[SaveSchema.legacyKey] = jsonEncode(fafe9d6());
      final p = open();
      expect(p.isLevelFailed(1), isTrue);
      final a = LevelSession(kLevels.first, p).rescueRequestId;
      final b = LevelSession(kLevels.first, open()).rescueRequestId;
      expect(a, isNotNull);
      expect(a, b, reason: 'same id across restarts → no double charge');
    });

    test('upgrade writes schema 2 and leaves the old save untouched', () async {
      final legacy = jsonEncode(c616e29c);
      store.data[SaveSchema.legacyKey] = legacy;
      final p = open();
      p.addCoins(10); // any change saves in the new format
      await settle();
      expect(store.data[SaveSchema.legacyKey], legacy);
      final saved = jsonDecode(store.data[SaveSchema.key]!) as Map;
      expect(saved['schema'], SaveSchema.current);
      expect(saved['coins'], 420);
      // Next launch reads the new key (old one ignored).
      expect(open().coins, 420);
    });

    test('a corrupted new save falls back to the legacy one', () {
      store.data[SaveSchema.legacyKey] = jsonEncode(e0aeffc);
      store.data[SaveSchema.key] = '{broken';
      expect(open().coins, 410);
    });

    test('migration is idempotent', () {
      final once = SaveSchema.migrate(Map<String, dynamic>.of(c616e29c));
      final twice = SaveSchema.migrate(once);
      expect(twice, once);
      expect(once['schema'], SaveSchema.current);
    });
  });

  group('progress and rewards persist', () {
    test('level unlocks, stars and first-clear coins survive restarts', () async {
      final p = open();
      var expected = p.coins;
      for (var level = 1; level <= 3; level++) {
        expected += p.completeLevel(level, 3);
      }
      await settle();
      final r = open();
      expect(r.unlockedLevel, 4);
      expect([r.starsFor(1), r.starsFor(2), r.starsFor(3)], [3, 3, 3]);
      expect(r.coins, expected);
      expect(r.completeLevel(2, 3), 0, reason: 'replay after restart pays nothing');
    });

    test('gift and daily reward are saved once and survive restarts', () async {
      final p = open();
      final coins = p.coins;
      p.claimDaily();
      final g = p.openGift(Random(9))!;
      await settle();
      final r = open();
      expect(r.canClaimDaily, isFalse);
      expect(r.canOpenGift, isFalse);
      expect(r.lastGift?.id, g.id);
      expect(r.claimDaily(), 0);
      expect(r.openGift(Random(9)), isNull);
      expect(r.coins, greaterThanOrEqualTo(coins + 50));
    });

    test('lives spent on a FAILED retry stay spent after restart', () async {
      final p = open();
      final s = failed(p);
      expect(s.restart(), RestartResult.restartedPaidLife);
      await settle();
      final r = open();
      expect(r.lives, PlayerProgress.maxLives - 1);
      expect(r.isLevelFailed(1), isFalse);
    });
  });
}
