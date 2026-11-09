import 'dart:math';

/// Every economy number in one place. Tweak values here only.
abstract final class EconomyConfig {
  // Starting inventory for a new player.
  static const startingCoins = 200;
  static const startingShuffles = 3;
  static const startingExtraBottles = 2;
  static const startingUndos = 5;

  // Lives.
  static const maxLives = 5;
  static const lifeRegen = Duration(minutes: 20);

  // Rewards.
  static const levelRewardMin = 20;
  static const levelRewardMax = 50;
  static const dailyLoginReward = 50;

  /// First-clear reward, scaled linearly from [levelRewardMin] (level 1) to
  /// [levelRewardMax] (last level). Replays pay nothing.
  static int levelReward(int level, int levelCount) {
    if (levelCount <= 1) return levelRewardMin;
    final t = ((level - 1) / (levelCount - 1)).clamp(0.0, 1.0);
    return (levelRewardMin + (levelRewardMax - levelRewardMin) * t).round();
  }

  // Prices (coins).
  static const oneLifePrice = 150;
  static const fullLivesPrice = 600; // 5 lives
  static const extraBottlePrice = 200;
  static const shufflePrice = 150;
  static const undoPackPrice = 100;
  static const undoPackSize = 5;
  static const rescueWithCoinsPrice = 200;

  /// Price to fill lives up to max; never more than buying them one by one.
  static int refillPrice(int currentLives) {
    final missing = max(0, maxLives - currentLives);
    return min(fullLivesPrice, missing * oneLifePrice);
  }

  // Surprise gifts.
  static const giftCooldown = Duration(hours: 48);
  static const giftBoxCount = 6;
}
