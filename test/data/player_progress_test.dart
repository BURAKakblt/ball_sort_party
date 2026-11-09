import 'package:ball_sort_party/data/player_progress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late DateTime now;
  DateTime clock() => now;

  Future<PlayerProgress> fresh() async {
    SharedPreferences.setMockInitialValues({});
    return PlayerProgress.load(clock: clock);
  }

  setUp(() => now = DateTime(2026, 11, 9, 12));

  test('starts with full lives and starting coins', () async {
    final p = await fresh();
    expect(p.lives, PlayerProgress.maxLives);
    expect(p.coins, PlayerProgress.startingCoins);
    expect(p.unlockedLevel, 1);
    expect(p.timeToNextLife, isNull);
  });

  test('lives regenerate over time', () async {
    final p = await fresh();
    p.loseLife();
    p.loseLife();
    expect(p.lives, 3);
    now = now.add(PlayerProgress.lifeRegen);
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
  });

  test('completing a level unlocks the next and pays out once fully', () async {
    final p = await fresh();
    final first = p.completeLevel(1, 2, 100);
    expect(first, 100);
    expect(p.unlockedLevel, 2);
    expect(p.starsFor(1), 2);
    final replay = p.completeLevel(1, 3, 100);
    expect(replay, 25);
    expect(p.starsFor(1), 3);
    expect(p.coins, PlayerProgress.startingCoins + 125);
  });

  test('daily reward: once per day, streak advances and resets', () async {
    final p = await fresh();
    expect(p.canClaimDaily, isTrue);
    expect(p.claimDaily(), PlayerProgress.dailyRewards[0]);
    expect(p.canClaimDaily, isFalse);
    expect(p.claimDaily(), 0);

    now = now.add(const Duration(days: 1));
    expect(p.claimDaily(), PlayerProgress.dailyRewards[1]);

    now = now.add(const Duration(days: 3)); // missed days
    expect(p.dailyIndex, 0);
    expect(p.claimDaily(), PlayerProgress.dailyRewards[0]);
  });

  test('shop purchases spend coins and fail when too poor', () async {
    final p = await fresh();
    final shuffles = p.shuffles;
    expect(p.buyShuffles(), isTrue);
    expect(p.shuffles, shuffles + 3);
    expect(p.coins, PlayerProgress.startingCoins - Prices.shuffle3);
    expect(p.buyExtraBottles(), isFalse, reason: 'only 50 coins left');
  });

  test('progress persists across instances', () async {
    final p = await fresh();
    p.completeLevel(1, 3, 50);
    p.loseLife();
    final reloaded = await PlayerProgress.load(clock: clock);
    expect(reloaded.unlockedLevel, 2);
    expect(reloaded.starsFor(1), 3);
    expect(reloaded.lives, PlayerProgress.maxLives - 1);
  });

  test('reset clears everything', () async {
    final p = await fresh();
    p.completeLevel(1, 3, 50);
    await p.resetAll();
    expect(p.unlockedLevel, 1);
    expect(p.coins, PlayerProgress.startingCoins);
  });
}
