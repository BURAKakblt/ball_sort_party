import 'dart:math';

import 'package:ball_sort_party/data/economy_config.dart';
import 'package:ball_sort_party/data/gift_config.dart';
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

  test('pool matches the design and odds sum to 100%', () {
    expect(GiftConfig.pool.map((g) => g.label), [
      '100 Altın',
      '150 Altın',
      '250 Altın',
      '2 Can',
      '1 Ekstra Şişe',
      '2 Karıştırma',
    ]);
    final total = GiftConfig.pool.fold<double>(0, (a, g) => a + GiftConfig.probability(g));
    expect(total, closeTo(1, 1e-9));
  });

  test('weighted pick roughly follows the published odds', () {
    final rnd = Random(42);
    final counts = <String, int>{};
    const n = 20000;
    for (var i = 0; i < n; i++) {
      final g = GiftConfig.pick(rnd);
      counts[g.id] = (counts[g.id] ?? 0) + 1;
    }
    for (final g in GiftConfig.pool) {
      expect(counts[g.id]! / n, closeTo(GiftConfig.probability(g), 0.02));
    }
  });

  test('a gift can be opened once every 48 hours', () async {
    final p = await fresh();
    expect(p.canOpenGift, isTrue);
    expect(p.openGift(Random(1)), isNotNull);
    expect(p.canOpenGift, isFalse);
    expect(p.openGift(Random(1)), isNull, reason: 'same gift never granted twice');

    now = now.add(const Duration(hours: 47, minutes: 59));
    expect(p.canOpenGift, isFalse);
    expect(p.timeUntilGift, const Duration(minutes: 1));
    now = now.add(const Duration(minutes: 1));
    expect(p.canOpenGift, isTrue);
  });

  test('reward is added to the account exactly once', () async {
    final p = await fresh();
    final coins = p.coins, lives = p.lives, bottles = p.extraBottles, shuffles = p.shuffles;
    final g = p.openGift(Random(3))!;
    p.openGift(Random(3)); // ignored
    switch (g.kind) {
      case GiftKind.coins:
        expect(p.coins, coins + g.amount);
      case GiftKind.lives:
        expect(p.lives, lives + g.amount);
      case GiftKind.extraBottles:
        expect(p.extraBottles, bottles + g.amount);
      case GiftKind.shuffles:
        expect(p.shuffles, shuffles + g.amount);
    }
  });

  test('gift lives may exceed the max and are not lost', () async {
    final p = await fresh();
    p.addLives(2);
    expect(p.lives, EconomyConfig.maxLives + 2);
    expect(p.timeToNextLife, isNull);
  });

  test('cooldown and reward survive an app restart', () async {
    final p = await fresh();
    final g = p.openGift(Random(5))!;
    final reloaded = await PlayerProgress.load(clock: clock);
    expect(reloaded.canOpenGift, isFalse);
    expect(reloaded.lastGift?.id, g.id);
    expect(reloaded.coins, p.coins);
    expect(reloaded.timeUntilGift, EconomyConfig.giftCooldown);
  });

  test('clock moved backwards never shows more than 48h', () async {
    final p = await fresh();
    p.openGift(Random(5));
    now = now.subtract(const Duration(days: 10));
    expect(p.timeUntilGift, lessThanOrEqualTo(EconomyConfig.giftCooldown));
  });
}
