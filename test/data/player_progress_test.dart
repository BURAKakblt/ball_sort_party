import 'dart:convert';

import 'package:ball_sort_party/data/economy_config.dart';
import 'package:ball_sort_party/data/player_progress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late DateTime now;
  DateTime clock() => now;

  Future<PlayerProgress> fresh([Map<String, Object> prefs = const {}]) async {
    SharedPreferences.setMockInitialValues(prefs);
    return PlayerProgress.load(clock: clock);
  }

  setUp(() => now = DateTime(2026, 11, 9, 12));

  group('lives', () {
    test('starts with full lives and starting coins', () async {
      final p = await fresh();
      expect(p.lives, PlayerProgress.maxLives);
      expect(p.coins, EconomyConfig.startingCoins);
      expect(p.unlockedLevel, 1);
      expect(p.timeToNextLife, isNull);
    });

    test('lives regenerate every 20 minutes up to the max', () async {
      final p = await fresh();
      p.loseLife();
      p.loseLife();
      expect(p.lives, 3);
      now = now.add(const Duration(minutes: 19));
      expect(p.lives, 3);
      now = now.add(const Duration(minutes: 1));
      expect(p.lives, 4);
      now = now.add(PlayerProgress.lifeRegen * 5);
      expect(p.lives, PlayerProgress.maxLives);
      expect(p.timeToNextLife, isNull);
    });

    test('lives never go below zero', () async {
      final p = await fresh();
      for (var i = 0; i < 10; i++) {
        p.loseLife();
      }
      expect(p.lives, 0);
      expect(p.hasLives, isFalse);
      expect(p.loseLife(), isFalse);
    });

    test('a clock moved backwards does not freeze regeneration forever', () async {
      final p = await fresh();
      p.loseLife();
      now = now.subtract(const Duration(days: 3));
      expect(p.timeToNextLife!.inMinutes, lessThanOrEqualTo(20));
    });
  });

  group('economy', () {
    test('level reward is 20..50 and paid only on first clear', () async {
      final p = await fresh();
      expect(EconomyConfig.levelReward(1, 10), 20);
      expect(EconomyConfig.levelReward(10, 10), 50);
      final first = p.completeLevel(1, 2);
      expect(first, 20);
      expect(p.unlockedLevel, 2);
      expect(p.starsFor(1), 2);
      expect(p.completeLevel(1, 3), 0, reason: 'replays pay nothing');
      expect(p.starsFor(1), 3);
      expect(p.coins, EconomyConfig.startingCoins + 20);
    });

    test('purchases deduct exact prices and grant items', () async {
      final p = await fresh();
      p.addCoins(1000); // 1200
      expect(p.buyShuffle(), isTrue);
      expect(p.buyExtraBottle(), isTrue);
      expect(p.buyUndoPack(), isTrue);
      expect(p.shuffles, EconomyConfig.startingShuffles + 1);
      expect(p.extraBottles, EconomyConfig.startingExtraBottles + 1);
      expect(p.undos, EconomyConfig.startingUndos + EconomyConfig.undoPackSize);
      expect(p.coins, 1200 - 150 - 200 - 100);
    });

    test('insufficient coins blocks purchase and never goes negative', () async {
      final p = await fresh(); // 200
      expect(p.buyShuffle(), isTrue); // 50 left
      final shuffles = p.shuffles;
      expect(p.buyShuffle(), isFalse);
      expect(p.buyExtraBottle(), isFalse);
      expect(p.coins, 50);
      expect(p.shuffles, shuffles);
      expect(p.spend(-10, () => true), isFalse);
      expect(p.coins, greaterThanOrEqualTo(0));
    });

    test('spend is atomic: no charge when the item cannot be applied', () async {
      final p = await fresh();
      expect(p.spend(100, () => false), isFalse);
      expect(p.coins, EconomyConfig.startingCoins);
      var applied = 0;
      expect(p.spend(100, () => ++applied > 0), isTrue);
      expect(applied, 1);
      expect(p.coins, EconomyConfig.startingCoins - 100);
    });

    test('lives cannot be bought above the max', () async {
      final p = await fresh();
      p.addCoins(2000);
      final coins = p.coins;
      expect(p.buyOneLife(), isFalse);
      expect(p.buyLifeRefill(), isFalse);
      expect(p.coins, coins, reason: 'no charge for nothing');
    });

    test('one life costs 150, refill is priced by missing lives (max 600)', () async {
      final p = await fresh();
      p.addCoins(2000);
      for (var i = 0; i < 5; i++) {
        p.loseLife();
      }
      expect(p.refillPrice, EconomyConfig.fullLivesPrice);
      var coins = p.coins;
      expect(p.buyOneLife(), isTrue);
      expect(p.coins, coins - 150);
      expect(p.lives, 1);
      expect(p.refillPrice, 4 * 150);
      coins = p.coins;
      expect(p.buyLifeRefill(), isTrue);
      expect(p.lives, PlayerProgress.maxLives);
      expect(p.coins, coins - 600);
    });

    test('items are consumed one at a time and never below zero', () async {
      final p = await fresh();
      for (var i = 0; i < EconomyConfig.startingUndos; i++) {
        expect(p.useUndo(), isTrue);
      }
      expect(p.useUndo(), isFalse);
      expect(p.undos, 0);
    });
  });

  group('daily reward', () {
    test('+50 once per day, streak advances and resets', () async {
      final p = await fresh();
      expect(p.canClaimDaily, isTrue);
      expect(p.claimDaily(), 50);
      expect(p.canClaimDaily, isFalse);
      expect(p.claimDaily(), 0);

      now = now.add(const Duration(days: 1));
      expect(p.dailyIndex, 1);
      expect(p.claimDaily(), 50);

      now = now.add(const Duration(days: 3)); // missed days
      expect(p.dailyIndex, 0);
      expect(p.claimDaily(), 50);
    });
  });

  group('persistence', () {
    test('progress, purchases and settings survive a restart', () async {
      final p = await fresh();
      p.completeLevel(1, 3);
      p.loseLife();
      p.buyShuffle();
      p.setMusicVolume(0.3);
      p.setSfxVolume(0.6);
      p.setMusic(false);
      p.setSound(false);
      p.setReduceMotion(true);
      final reloaded = await PlayerProgress.load(clock: clock);
      expect(reloaded.unlockedLevel, 2);
      expect(reloaded.starsFor(1), 3);
      expect(reloaded.lives, PlayerProgress.maxLives - 1);
      expect(reloaded.coins, p.coins);
      expect(reloaded.shuffles, p.shuffles);
      expect(reloaded.musicVolume, 0.3);
      expect(reloaded.sfxVolume, 0.6);
      expect(reloaded.musicOn, isFalse);
      expect(reloaded.soundOn, isFalse);
      expect(reloaded.reduceMotion, isTrue);
    });

    test('old v1 saves load with defaults for new fields', () async {
      final p = await fresh({
        'player_progress_v1': jsonEncode({
          'coins': 321,
          'lives': 4,
          'unlocked': 3,
          'stars': {'1': 3, '2': 1},
          'shuffles': 7,
          'extraBottles': 1,
          'sound': false,
        }),
      });
      expect(p.coins, 321);
      expect(p.unlockedLevel, 3);
      expect(p.shuffles, 7);
      expect(p.undos, EconomyConfig.startingUndos);
      expect(p.soundOn, isFalse);
      expect(p.musicVolume, 0.8);
      expect(p.canOpenGift, isTrue);
    });

    test('corrupt save falls back to defaults', () async {
      final p = await fresh({'player_progress_v1': '{not json'});
      expect(p.coins, EconomyConfig.startingCoins);
    });

    test('reset clears everything', () async {
      final p = await fresh();
      p.completeLevel(1, 3);
      await p.resetAll();
      expect(p.unlockedLevel, 1);
      expect(p.coins, EconomyConfig.startingCoins);
    });
  });
}
