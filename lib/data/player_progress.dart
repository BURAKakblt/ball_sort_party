import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/levels/level_data.dart';

/// Prices (in coins) for items sold in the shop.
abstract final class Prices {
  static const shuffle3 = 150;
  static const extraBottle3 = 200;
  static const refillLives = 250;
}

/// Player economy and progress, persisted locally (offline-first).
class PlayerProgress extends ChangeNotifier {
  PlayerProgress(this._prefs, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now {
    _load();
  }

  static Future<PlayerProgress> load({DateTime Function()? clock}) async {
    final prefs = await SharedPreferences.getInstance();
    return PlayerProgress(prefs, clock: clock);
  }

  static const maxLives = 5;
  static const lifeRegen = Duration(minutes: 20);
  static const dailyRewards = [50, 75, 100, 150, 200, 250, 500];
  static const startingCoins = 200;

  final SharedPreferences _prefs;
  final DateTime Function() _now;

  late int _coins;
  late int _lives;
  int? _nextLifeAtMs;
  late int _unlockedLevel;
  late Map<int, int> _stars;
  late int _shuffles;
  late int _extraBottles;
  String? _lastDailyClaim;
  late int _dailyStreak;
  late bool soundOn;
  late bool musicOn;
  late bool hapticsOn;

  int get coins => _coins;
  int get unlockedLevel => _unlockedLevel;
  int get shuffles => _shuffles;
  int get extraBottles => _extraBottles;
  int starsFor(int level) => _stars[level] ?? 0;
  int get totalStars => _stars.values.fold(0, (a, b) => a + b);
  int get levelCount => kLevels.length;

  /// Level the PLAY button opens: first unbeaten level, or the last one.
  int get currentLevel => min(_unlockedLevel, levelCount);
  bool isUnlocked(int level) => level <= _unlockedLevel;

  // ---------------------------------------------------------------- lives

  int get lives {
    _regenerate();
    return _lives;
  }

  bool get hasLives => lives > 0;

  /// Time until the next life regenerates, or null when full.
  Duration? get timeToNextLife {
    _regenerate();
    if (_lives >= maxLives || _nextLifeAtMs == null) return null;
    final ms = _nextLifeAtMs! - _now().millisecondsSinceEpoch;
    return Duration(milliseconds: max(0, ms));
  }

  void _regenerate() {
    if (_lives >= maxLives) {
      _nextLifeAtMs = null;
      return;
    }
    final next = _nextLifeAtMs;
    if (next == null) {
      _nextLifeAtMs = _now().add(lifeRegen).millisecondsSinceEpoch;
      _save();
      return;
    }
    final now = _now().millisecondsSinceEpoch;
    if (now < next) return;
    final gained = 1 + (now - next) ~/ lifeRegen.inMilliseconds;
    _lives = min(maxLives, _lives + gained);
    _nextLifeAtMs = _lives >= maxLives
        ? null
        : next + gained * lifeRegen.inMilliseconds;
    _save();
  }

  /// Call periodically (e.g. every second) so listeners see regenerated lives.
  void tick() {
    final before = _lives;
    _regenerate();
    if (_lives != before) notifyListeners();
  }

  /// Uses a life (e.g. restarting or quitting an unfinished level).
  void loseLife() {
    _regenerate();
    if (_lives <= 0) return;
    if (_lives == maxLives) {
      _nextLifeAtMs = _now().add(lifeRegen).millisecondsSinceEpoch;
    }
    _lives--;
    _commit();
  }

  bool buyLifeRefill() {
    if (_lives >= maxLives || !_spend(Prices.refillLives)) return false;
    _lives = maxLives;
    _nextLifeAtMs = null;
    _commit();
    return true;
  }

  // ---------------------------------------------------------------- coins & items

  bool _spend(int amount) {
    if (_coins < amount) return false;
    _coins -= amount;
    return true;
  }

  void addCoins(int amount) {
    _coins += amount;
    _commit();
  }

  bool buyShuffles() {
    if (!_spend(Prices.shuffle3)) return false;
    _shuffles += 3;
    _commit();
    return true;
  }

  bool buyExtraBottles() {
    if (!_spend(Prices.extraBottle3)) return false;
    _extraBottles += 3;
    _commit();
    return true;
  }

  bool useShuffle() {
    if (_shuffles <= 0) return false;
    _shuffles--;
    _commit();
    return true;
  }

  bool useExtraBottle() {
    if (_extraBottles <= 0) return false;
    _extraBottles--;
    _commit();
    return true;
  }

  /// Gives back an item when the power-up could not actually be applied.
  void refundShuffle() {
    _shuffles++;
    _commit();
  }

  // ---------------------------------------------------------------- levels

  /// Records a win. Returns the coins awarded.
  int completeLevel(int level, int stars, int coinReward) {
    final best = _stars[level] ?? 0;
    final firstClear = best == 0;
    if (stars > best) _stars[level] = stars;
    if (level >= _unlockedLevel) _unlockedLevel = level + 1;
    // Full reward on first clear, a smaller one for replays.
    final reward = firstClear ? coinReward : (coinReward / 4).round();
    _coins += reward;
    _commit();
    return reward;
  }

  // ---------------------------------------------------------------- daily reward

  static String _day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool get canClaimDaily => _lastDailyClaim != _day(_now());

  /// Day index (0-6) of the reward that is/was claimable today.
  int get dailyIndex {
    if (!canClaimDaily) return (_dailyStreak - 1) % dailyRewards.length;
    final yesterday = _day(_now().subtract(const Duration(days: 1)));
    final continues = _lastDailyClaim == yesterday;
    return continues ? _dailyStreak % dailyRewards.length : 0;
  }

  int get dailyAmount => dailyRewards[dailyIndex];

  /// Returns the coins granted, or 0 if already claimed today.
  int claimDaily() {
    if (!canClaimDaily) return 0;
    final index = dailyIndex;
    final amount = dailyRewards[index];
    _dailyStreak = index + 1;
    _lastDailyClaim = _day(_now());
    _coins += amount;
    _commit();
    return amount;
  }

  Duration get timeUntilNextDaily {
    final n = _now();
    final tomorrow = DateTime(n.year, n.month, n.day + 1);
    return tomorrow.difference(n);
  }

  // ---------------------------------------------------------------- settings

  void setSound(bool v) {
    soundOn = v;
    _commit();
  }

  void setMusic(bool v) {
    musicOn = v;
    _commit();
  }

  void setHaptics(bool v) {
    hapticsOn = v;
    _commit();
  }

  Future<void> resetAll() async {
    await _prefs.remove(_key);
    _load();
    notifyListeners();
  }

  // ---------------------------------------------------------------- persistence

  static const _key = 'player_progress_v1';

  void _load() {
    Map<String, dynamic> m = {};
    final raw = _prefs.getString(_key);
    if (raw != null) {
      try {
        m = jsonDecode(raw) as Map<String, dynamic>;
      } on FormatException {
        m = {};
      }
    }
    _coins = m['coins'] as int? ?? startingCoins;
    _lives = m['lives'] as int? ?? maxLives;
    _nextLifeAtMs = m['nextLifeAt'] as int?;
    _unlockedLevel = m['unlocked'] as int? ?? 1;
    _stars = {
      for (final e in (m['stars'] as Map<String, dynamic>? ?? {}).entries)
        int.parse(e.key): e.value as int,
    };
    _shuffles = m['shuffles'] as int? ?? 3;
    _extraBottles = m['extraBottles'] as int? ?? 2;
    _lastDailyClaim = m['dailyClaim'] as String?;
    _dailyStreak = m['dailyStreak'] as int? ?? 0;
    soundOn = m['sound'] as bool? ?? true;
    musicOn = m['music'] as bool? ?? true;
    hapticsOn = m['haptics'] as bool? ?? true;
  }

  void _save() {
    _prefs.setString(
      _key,
      jsonEncode({
        'coins': _coins,
        'lives': _lives,
        'nextLifeAt': _nextLifeAtMs,
        'unlocked': _unlockedLevel,
        'stars': {for (final e in _stars.entries) '${e.key}': e.value},
        'shuffles': _shuffles,
        'extraBottles': _extraBottles,
        'dailyClaim': _lastDailyClaim,
        'dailyStreak': _dailyStreak,
        'sound': soundOn,
        'music': musicOn,
        'haptics': hapticsOn,
      }),
    );
  }

  void _commit() {
    _save();
    notifyListeners();
  }
}
