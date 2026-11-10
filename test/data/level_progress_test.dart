import 'dart:convert';

import 'package:ball_sort_party/data/economy_config.dart';
import 'package:ball_sort_party/data/player_progress.dart';
import 'package:ball_sort_party/data/progress_store.dart';
import 'package:ball_sort_party/game/engine/failure_monitor.dart';
import 'package:ball_sort_party/game/levels/level_data.dart';
import 'package:ball_sort_party/game/session/level_run.dart';
import 'package:ball_sort_party/game/session/level_session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'persistence_test.dart' show MemoryStore;

void main() {
  late MemoryStore store;
  final now = DateTime(2026, 11, 10, 12);
  PlayerProgress open() => PlayerProgress.withStore(store, clock: () => now);
  Future<void> settle() => Future<void>.delayed(Duration.zero);
  int reward(int n) => EconomyConfig.levelReward(n, kLevels.length);

  setUp(() => store = MemoryStore());

  group('level locks', () {
    test('a new player can only open level 1', () {
      final p = open();
      expect(p.isUnlocked(1), isTrue);
      expect(p.isUnlocked(2), isFalse);
      expect(p.currentLevel, 1);
    });

    test('completing a level unlocks exactly the next one', () {
      final p = open();
      p.completeLevel(1, 3);
      expect(p.isUnlocked(2), isTrue);
      expect(p.isUnlocked(3), isFalse);
      p.completeLevel(1, 1); // replay
      expect(p.unlockedLevel, 2);
    });

    test('finishing all 50 never unlocks beyond the last level', () {
      final p = open();
      for (var n = 1; n <= kLevels.length; n++) {
        p.completeLevel(n, 2);
      }
      expect(p.unlockedLevel, kLevels.length + 1);
      expect(p.currentLevel, kLevels.length);
      p.completeLevel(kLevels.length, 3);
      expect(p.unlockedLevel, kLevels.length + 1);
    });
  });

  group('stars and rewards', () {
    test('best stars are kept and saved with the layout signature', () async {
      final p = open();
      p.completeLevel(5, 2);
      p.completeLevel(5, 1);
      expect(p.starsFor(5), 2);
      p.completeLevel(5, 3);
      expect(p.starsFor(5), 3);
      expect(p.starsAreCurrent(5), isTrue);
      await settle();
      final r = open();
      expect(r.starsFor(5), 3);
      expect(r.starsAreCurrent(5), isTrue);
    });

    test('first-clear coins are paid exactly once per level (also after restart)', () async {
      final p = open();
      expect(p.completeLevel(7, 3), reward(7));
      expect(p.completeLevel(7, 3), 0);
      await settle();
      expect(open().completeLevel(7, 3), 0);
    });

    test('first-clear rewards stay within 20–50 coins across all 50 levels', () {
      final p = open();
      final start = p.coins;
      var paid = 0;
      for (var n = 1; n <= kLevels.length; n++) {
        final r = p.completeLevel(n, 3);
        expect(r, inInclusiveRange(EconomyConfig.levelRewardMin, EconomyConfig.levelRewardMax));
        paid += r;
      }
      expect(p.coins, start + paid);
    });
  });

  group('migration from saves made before the 50-level update', () {
    /// A save from the 10-level version (schema 2, no star signatures).
    Map<String, dynamic> tenLevelSave() => {
      'schema': 2,
      'coins': 777,
      'lives': 4,
      'unlocked': 11,
      'stars': {for (var n = 1; n <= 10; n++) '$n': (n % 3) + 1},
      'shuffles': 6,
      'extraBottles': 3,
      'undos': 9,
      'giftAt': now.millisecondsSinceEpoch,
      'giftId': 'coins250',
      'processed': ['rescue:3:abc'],
    };

    test('progress, coins and purchased items are kept', () {
      store.data[SaveSchema.key] = jsonEncode(tenLevelSave());
      final p = open();
      expect(p.coins, 777);
      expect(p.shuffles, 6);
      expect(p.extraBottles, 3);
      expect(p.undos, 9);
      expect(p.lives, 4);
      expect(p.canOpenGift, isFalse);
      expect(p.wasProcessed('rescue:3:abc'), isTrue);
      expect(p.unlockedLevel, 11, reason: 'level 11 is the next new level');
      for (var n = 1; n <= 10; n++) {
        expect(p.isCleared(n), isTrue);
        expect(p.starsFor(n), (n % 3) + 1);
      }
    });

    test('old stars are marked legacy (layouts changed) and refreshed by a replay', () {
      store.data[SaveSchema.key] = jsonEncode(tenLevelSave());
      final p = open();
      expect(p.starsAreCurrent(4), isFalse);
      expect(p.completeLevel(4, 1), 0, reason: 'cleared before → no second payout');
      expect(p.starsFor(4), 1, reason: 'legacy record replaced by the current one');
      expect(p.starsAreCurrent(4), isTrue);
    });

    test('new levels pay their first-clear reward normally', () {
      store.data[SaveSchema.key] = jsonEncode(tenLevelSave());
      final p = open();
      expect(p.completeLevel(11, 3), reward(11));
      expect(p.coins, 777 + reward(11));
    });

    test('schema 1 save (first releases) migrates the same way', () {
      store.data[SaveSchema.legacyKey] = jsonEncode({
        'coins': 410,
        'unlocked': 4,
        'stars': {'1': 3, '2': 2, '3': 1},
      });
      final p = open();
      expect(p.coins, 410);
      expect(p.unlockedLevel, 4);
      expect(p.starsFor(2), 2);
      expect(p.starsAreCurrent(2), isFalse);
    });

    test('upgraded save is written as schema 3 with star signatures', () async {
      store.data[SaveSchema.key] = jsonEncode(tenLevelSave());
      final p = open();
      p.completeLevel(2, 3);
      await settle();
      final saved = jsonDecode(store.data[SaveSchema.key]!) as Map<String, dynamic>;
      expect(saved['schema'], 3);
      expect((saved['starSigs'] as Map)['2'], LevelRun.signatureOf(kLevels[1].layout));
      expect((saved['starSigs'] as Map)['3'], PlayerProgress.legacyStarSig);
    });
  });

  group('saved attempts across the update', () {
    test('attempts on a level whose layout changed are dropped without cost', () {
      // Level 6 now has a different layout; an attempt saved on the old one.
      const oldLayout = ['SFBT', 'TTFF', 'SBFS', 'TBSB', '', ''];
      store.data[SaveSchema.key] = jsonEncode({
        'schema': 2,
        'lives': 3,
        'runs': {
          '6': {
            'status': 'failed', 'reason': 'deadlock', 'layout': oldLayout,
            'history': [], 'moves': 1, 'extra': 0,
            'sig': LevelRun.signatureOf(oldLayout), 'failId': 'x',
          },
        },
      });
      final p = open();
      expect(p.runFor(6), isNull);
      expect(p.isLevelFailed(6), isFalse);
      expect(p.lives, 3, reason: 'no life taken for a discarded attempt');
      expect(LevelSession(kLevels[5], p).status, LevelStatus.playing);
    });

    test('FAILED attempts on unchanged levels survive the update', () async {
      final p = open();
      final s = LevelSession(kLevels.first, p);
      final m = s.engine.state.validMoves().first;
      s.engine.move(m.from, m.to);
      s.save();
      s.fail(BoardStatus.deadlock);
      await settle();
      final saved = jsonDecode(store.data[SaveSchema.key]!) as Map<String, dynamic>;
      saved['schema'] = 2; // pretend it came from the previous version
      saved.remove('starSigs');
      store.data[SaveSchema.key] = jsonEncode(saved);
      final r = open();
      expect(r.isLevelFailed(1), isTrue);
      expect(LevelSession(kLevels.first, r).isFailed, isTrue);
    });
  });

  group('damaged saves never crash the game', () {
    test('garbage values fall back to safe defaults', () {
      store.data[SaveSchema.key] = jsonEncode({
        'schema': 3,
        'coins': 'lots',
        'lives': -5,
        'unlocked': 999,
        'stars': {'1': 3, 'abc': 2, '77': 3, '2': 'x', '3': -1, '4': 9},
        'starSigs': 'oops',
        'runs': {'1': 'garbage', 'x': {}},
        'processed': 'nope',
        'sound': 'yes',
        'giftAt': 'later',
      });
      final p = open();
      expect(p.coins, EconomyConfig.startingCoins);
      expect(p.lives, 0);
      expect(p.unlockedLevel, kLevels.length + 1);
      expect(p.starsFor(1), 3);
      expect(p.starsFor(4), 3, reason: 'clamped to 3');
      expect(p.starsFor(2), 0);
      expect(p.starsFor(3), 0);
      expect(p.runFor(1), isNull);
      expect(p.soundOn, isTrue);
      expect(p.canOpenGift, isTrue);
      expect(p.buyShuffle(), isTrue, reason: 'economy still works');
    });

    test('stars on a level above the unlock mark unlock it (never lock cleared levels)', () {
      store.data[SaveSchema.key] = jsonEncode({'unlocked': 2, 'stars': {'5': 2}});
      expect(open().unlockedLevel, 6);
    });

    test('non-JSON save starts fresh instead of crashing', () {
      store.data[SaveSchema.key] = 'not json at all';
      expect(open().coins, EconomyConfig.startingCoins);
    });
  });
}
