import 'dart:math';

enum GiftKind { coins, lives, extraBottles, shuffles }

/// One entry in the surprise-gift pool.
class GiftReward {
  const GiftReward(this.id, this.kind, this.amount, this.weight);

  /// Stable id used for persistence.
  final String id;
  final GiftKind kind;
  final int amount;

  /// Relative weight; probability = weight / total weight.
  final int weight;

  String get label => switch (kind) {
    GiftKind.coins => '$amount Altın',
    GiftKind.lives => '$amount Can',
    GiftKind.extraBottles => '$amount Ekstra Şişe',
    GiftKind.shuffles => '$amount Karıştırma',
  };
}

/// Gift pool and odds. The odds are shown to players in the gift screen.
abstract final class GiftConfig {
  static const pool = [
    GiftReward('coins100', GiftKind.coins, 100, 30),
    GiftReward('coins150', GiftKind.coins, 150, 25),
    GiftReward('coins250', GiftKind.coins, 250, 10),
    GiftReward('lives2', GiftKind.lives, 2, 15),
    GiftReward('bottle1', GiftKind.extraBottles, 1, 10),
    GiftReward('shuffle2', GiftKind.shuffles, 2, 10),
  ];

  static int get totalWeight => pool.fold(0, (a, g) => a + g.weight);

  static double probability(GiftReward g) => g.weight / totalWeight;

  static GiftReward? byId(String? id) {
    for (final g in pool) {
      if (g.id == id) return g;
    }
    return null;
  }

  /// Weighted pick. The reward does not depend on which box was tapped, so
  /// every box has exactly the published odds.
  static GiftReward pick(Random random) {
    var roll = random.nextInt(totalWeight);
    for (final g in pool) {
      if (roll < g.weight) return g;
      roll -= g.weight;
    }
    return pool.last;
  }
}
