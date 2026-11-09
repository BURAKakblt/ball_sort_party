import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/levels/level_data.dart';
import '../game/session/level_run.dart';
import 'economy_config.dart';
import 'gift_config.dart';
import 'progress_store.dart';

/// Outcome of [PlayerProgress.purchase].
enum PurchaseResult {
  success,

  /// This request id was already completed; nothing was charged again.
  alreadyProcessed,
  insufficientCoins,

  /// The item could not be applied (e.g. extra bottle already used);
  /// nothing was charged.
  notApplicable,
}

/// Player economy, progress and settings, persisted locally (offline-first).
///
/// Every mutating method validates first and then applies all of its changes
/// in a single save, so a purchase or reward is never half-applied.
///
/// Note: local storage is not tamper-proof. Changing the device clock can
/// speed up life regeneration / gift timers, and clearing app data resets
/// progress. A server-side economy is required to prevent that.
class PlayerProgress extends ChangeNotifier {
  PlayerProgress(SharedPreferences prefs, {DateTime Function()? clock})
    : this.withStore(SharedPreferencesStore(prefs), clock: clock);

  PlayerProgress.withStore(this._store, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now {
    _load();
  }

  static Future<PlayerProgress> load({DateTime Function()? clock}) async {
    final prefs = await SharedPreferences.getInstance();
    return PlayerProgress(prefs, clock: clock);
  }

  static const maxLives = EconomyConfig.maxLives;
  static const lifeRegen = EconomyConfig.lifeRegen;
  static const startingCoins = EconomyConfig.startingCoins;
  static const streakDays = 7;

  final ProgressStore _store;

  /// Ids of completed purchase requests (idempotency), newest last.
  late List<String> _processed;
  static const _processedLimit = 200;

  int _txDepth = 0;
  bool _txDirty = false;

  /// True when the last write failed; the next save retries the full state.
  bool _unsaved = false;
  bool get hasUnsavedChanges => _unsaved;
  final DateTime Function() _now;

  late int _coins;
  late int _lives;
  int? _nextLifeAtMs;
  late int _unlockedLevel;
  late Map<int, int> _stars;
  late int _shuffles;
  late int _extraBottles;
  late int _undos;
  String? _lastDailyClaim;
  late int _dailyStreak;
  int? _lastGiftAtMs;
  String? _lastGiftId;
  late Map<int, LevelRun> _runs;

  // Settings.
  late bool soundOn;
  late bool musicOn;
  late double sfxVolume;
  late double musicVolume;
  late bool hapticsOn;
  late bool reduceMotion;

  int get coins => _coins;
  int get unlockedLevel => _unlockedLevel;
  int get shuffles => _shuffles;
  int get extraBottles => _extraBottles;
  int get undos => _undos;
  int starsFor(int level) => _stars[level] ?? 0;
  int get totalStars => _stars.values.fold(0, (a, b) => a + b);
  int get levelCount => kLevels.length;

  /// Level the PLAY button opens: first unbeaten level, or the last one.
  int get currentLevel => min(_unlockedLevel, levelCount);
  bool isUnlocked(int level) => level <= _unlockedLevel;

  // ---------------------------------------------------------------- lives

  /// Current lives. Can exceed [maxLives] temporarily via gifts.
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
    return Duration(milliseconds: ms.clamp(0, lifeRegen.inMilliseconds));
  }

  void _regenerate() {
    if (_lives >= maxLives) {
      _nextLifeAtMs = null;
      return;
    }
    final now = _now().millisecondsSinceEpoch;
    final next = _nextLifeAtMs;
    // Missing timer, or clock moved backwards past one full period.
    if (next == null || next - now > lifeRegen.inMilliseconds) {
      _nextLifeAtMs = now + lifeRegen.inMilliseconds;
      _persist();
      return;
    }
    if (now < next) return;
    final gained = 1 + (now - next) ~/ lifeRegen.inMilliseconds;
    _lives = min(maxLives, _lives + gained);
    _nextLifeAtMs = _lives >= maxLives ? null : next + gained * lifeRegen.inMilliseconds;
    _persist();
  }

  /// Call periodically (e.g. every second) so listeners see regenerated lives.
  void tick() {
    final before = _lives;
    _regenerate();
    if (_lives != before) notifyListeners();
  }

  /// Uses one life. Only called when retrying a failed level.
  /// Returns false when there was no life to use.
  bool loseLife() {
    _regenerate();
    if (_lives <= 0) return false;
    if (_lives == maxLives) {
      _nextLifeAtMs = _now().add(lifeRegen).millisecondsSinceEpoch;
    }
    _lives--;
    _commit();
    return true;
  }

  /// Grants lives (gifts, future rewarded ads). May exceed [maxLives].
  void addLives(int amount) {
    _regenerate();
    _lives += amount;
    if (_lives >= maxLives) _nextLifeAtMs = null;
    _commit();
  }

  int get refillPrice => EconomyConfig.refillPrice(lives);
  bool get canBuyLife => lives < maxLives;

  bool buyOneLife() => spend(EconomyConfig.oneLifePrice, () {
    if (_lives >= maxLives) return false;
    _lives++;
    if (_lives >= maxLives) _nextLifeAtMs = null;
    return true;
  });

  bool buyLifeRefill() => spend(refillPrice, () {
    if (_lives >= maxLives) return false;
    _lives = maxLives;
    _nextLifeAtMs = null;
    return true;
  });

  // ---------------------------------------------------------------- coins & items

  /// Runs [body] as one unit: every change made inside (coins, items, saved
  /// board via [saveRun], …) is written in a SINGLE save at the end. If
  /// [body] throws, the in-memory state is rolled back and nothing is saved.
  T transaction<T>(T Function() body) {
    final snapshot = _txDepth == 0 ? _toJson() : null;
    _txDepth++;
    try {
      return body();
    } catch (_) {
      if (snapshot != null) {
        _fromJson(snapshot);
        _txDirty = false;
      }
      rethrow;
    } finally {
      _txDepth--;
      if (_txDepth == 0 && _txDirty) {
        _txDirty = false;
        _save();
        notifyListeners();
      }
    }
  }

  /// Atomic, idempotent purchase. Coins are deducted only if the player can
  /// afford [cost] AND [apply] succeeds; both changes are saved together.
  /// A repeated [requestId] is never charged or applied twice.
  PurchaseResult purchase(int cost, bool Function() apply, {String? requestId}) {
    if (requestId != null && _processed.contains(requestId)) {
      return PurchaseResult.alreadyProcessed;
    }
    _regenerate();
    if (cost < 0 || _coins < cost) return PurchaseResult.insufficientCoins;
    return transaction(() {
      if (!apply()) return PurchaseResult.notApplicable;
      _coins -= cost;
      if (requestId != null) {
        _processed.add(requestId);
        if (_processed.length > _processedLimit) _processed.removeAt(0);
      }
      _commit();
      return PurchaseResult.success;
    });
  }

  /// [purchase] without a request id; true on success.
  bool spend(int cost, bool Function() apply) => purchase(cost, apply) == PurchaseResult.success;

  bool wasProcessed(String requestId) => _processed.contains(requestId);

  bool canAfford(int cost) => _coins >= cost;

  void addCoins(int amount) {
    if (amount <= 0) return;
    _coins += amount;
    _commit();
  }

  bool buyShuffle() => spend(EconomyConfig.shufflePrice, () {
    _shuffles++;
    return true;
  });

  bool buyExtraBottle() => spend(EconomyConfig.extraBottlePrice, () {
    _extraBottles++;
    return true;
  });

  bool buyUndoPack() => spend(EconomyConfig.undoPackPrice, () {
    _undos += EconomyConfig.undoPackSize;
    return true;
  });

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

  bool useUndo() {
    if (_undos <= 0) return false;
    _undos--;
    _commit();
    return true;
  }

  // ---------------------------------------------------------------- levels

  /// Records a win. Coins are paid only on the first clear of a level.
  /// Clears any saved / FAILED attempt for it. Returns the coins awarded.
  int completeLevel(int level, int stars) {
    final best = _stars[level] ?? 0;
    final firstClear = best == 0;
    if (stars > best) _stars[level] = stars;
    if (level >= _unlockedLevel) _unlockedLevel = level + 1;
    final reward = firstClear ? EconomyConfig.levelReward(level, levelCount) : 0;
    _coins += reward;
    _runs.remove(level);
    _commit();
    return reward;
  }

  // ---------------------------------------------------------------- attempts
  // Unfinished attempts are saved per level, so failing level A and then
  // playing level B never clears A's FAILED state.

  LevelRun? runFor(int level) => _runs[level];

  bool isLevelFailed(int level) => _runs[level]?.isFailed ?? false;

  /// Saves an in-progress attempt. A FAILED attempt can't be overwritten by a
  /// PLAYING one here (use [recoverLevel]). Returns false if rejected.
  bool saveRun(int level, LevelRun run) {
    if (isLevelFailed(level) && !run.isFailed) return false;
    _runs[level] = run;
    _commit();
    return true;
  }

  /// FAILED → PLAYING after a successful rescue (undo / coins / ad).
  bool recoverLevel(int level, LevelRun run) {
    if (!isLevelFailed(level) || run.isFailed) return false;
    _runs[level] = run;
    _commit();
    return true;
  }

  /// Manual restart during normal play: free. Not allowed while FAILED.
  bool discardRun(int level) {
    if (isLevelFailed(level)) return false;
    if (_runs.remove(level) != null) _commit();
    return true;
  }

  /// Restarting a FAILED level: costs exactly one life and clears the
  /// attempt, in a single save. Returns false (and changes nothing) when the
  /// level isn't failed or there is no life left.
  bool payRetry(int level) {
    if (!isLevelFailed(level)) return false;
    _regenerate();
    if (_lives <= 0) return false;
    if (_lives == maxLives) {
      _nextLifeAtMs = _now().add(lifeRegen).millisecondsSinceEpoch;
    }
    _lives--;
    _runs.remove(level);
    _commit();
    return true;
  }

  // ---------------------------------------------------------------- daily reward

  static String _day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool get canClaimDaily => _lastDailyClaim != _day(_now());

  /// Streak day index (0-6) shown in the UI.
  int get dailyIndex {
    if (!canClaimDaily) return (_dailyStreak - 1) % streakDays;
    final yesterday = _day(_now().subtract(const Duration(days: 1)));
    final continues = _lastDailyClaim == yesterday;
    return continues ? _dailyStreak % streakDays : 0;
  }

  int get dailyAmount => EconomyConfig.dailyLoginReward;

  /// Returns the coins granted, or 0 if already claimed today.
  int claimDaily() {
    if (!canClaimDaily) return 0;
    _dailyStreak = dailyIndex + 1;
    _lastDailyClaim = _day(_now());
    _coins += dailyAmount;
    _commit();
    return dailyAmount;
  }

  Duration get timeUntilNextDaily {
    final n = _now();
    final tomorrow = DateTime(n.year, n.month, n.day + 1);
    return tomorrow.difference(n);
  }

  // ---------------------------------------------------------------- surprise gifts

  GiftReward? get lastGift => GiftConfig.byId(_lastGiftId);

  Duration get timeUntilGift {
    final last = _lastGiftAtMs;
    if (last == null) return Duration.zero;
    final remaining = last + EconomyConfig.giftCooldown.inMilliseconds - _now().millisecondsSinceEpoch;
    // A clock moved backwards never shows more than one full cooldown.
    return Duration(milliseconds: remaining.clamp(0, EconomyConfig.giftCooldown.inMilliseconds));
  }

  bool get canOpenGift => timeUntilGift == Duration.zero;

  /// Opens today's gift: picks a reward, grants it and starts the cooldown in
  /// one save. Returns null if the gift is not available yet.
  GiftReward? openGift(Random random) {
    if (!canOpenGift) return null;
    final gift = GiftConfig.pick(random);
    switch (gift.kind) {
      case GiftKind.coins:
        _coins += gift.amount;
      case GiftKind.lives:
        _regenerate();
        _lives += gift.amount;
        if (_lives >= maxLives) _nextLifeAtMs = null;
      case GiftKind.extraBottles:
        _extraBottles += gift.amount;
      case GiftKind.shuffles:
        _shuffles += gift.amount;
    }
    _lastGiftAtMs = _now().millisecondsSinceEpoch;
    _lastGiftId = gift.id;
    _commit();
    return gift;
  }

  // ---------------------------------------------------------------- settings

  void setSound(bool v) => _set(() => soundOn = v);
  void setMusic(bool v) => _set(() => musicOn = v);
  void setSfxVolume(double v) => _set(() => sfxVolume = v.clamp(0, 1));
  void setMusicVolume(double v) => _set(() => musicVolume = v.clamp(0, 1));
  void setHaptics(bool v) => _set(() => hapticsOn = v);
  void setReduceMotion(bool v) => _set(() => reduceMotion = v);

  void _set(void Function() f) {
    f();
    _commit();
  }

  Future<void> resetAll() async {
    await _store.remove(SaveSchema.key);
    await _store.remove(SaveSchema.legacyKey);
    _load();
    notifyListeners();
  }

  // ---------------------------------------------------------------- persistence

  void _load() => _fromJson(SaveSchema.load(_store) ?? {});

  void _fromJson(Map<String, dynamic> m) {
    int readInt(String k, int fallback) => max(0, (m[k] as num?)?.toInt() ?? fallback);
    double readVol(String k) => ((m[k] as num?)?.toDouble() ?? 0.8).clamp(0, 1).toDouble();

    _coins = readInt('coins', EconomyConfig.startingCoins);
    _lives = readInt('lives', maxLives);
    _nextLifeAtMs = (m['nextLifeAt'] as num?)?.toInt();
    _unlockedLevel = max(1, readInt('unlocked', 1));
    _stars = {
      for (final e in (m['stars'] as Map<String, dynamic>? ?? {}).entries)
        int.parse(e.key): (e.value as num).toInt(),
    };
    _shuffles = readInt('shuffles', EconomyConfig.startingShuffles);
    _extraBottles = readInt('extraBottles', EconomyConfig.startingExtraBottles);
    _undos = readInt('undos', EconomyConfig.startingUndos);
    _lastDailyClaim = m['dailyClaim'] as String?;
    _dailyStreak = readInt('dailyStreak', 0);
    _lastGiftAtMs = (m['giftAt'] as num?)?.toInt();
    _lastGiftId = m['giftId'] as String?;
    _runs = {};
    final runs = m['runs'];
    if (runs is Map) {
      for (final e in runs.entries) {
        final level = int.tryParse('${e.key}');
        final run = LevelRun.fromJson(e.value);
        if (level == null || run == null || level < 1 || level > kLevels.length) continue;
        if (!run.isValidFor(kLevels[level - 1])) continue;
        _runs[level] = run;
      }
    }
    _processed = [
      for (final id in (m['processed'] as List? ?? const [])) '$id',
    ];
    soundOn = m['sound'] as bool? ?? true;
    musicOn = m['music'] as bool? ?? true;
    sfxVolume = readVol('sfxVolume');
    musicVolume = readVol('musicVolume');
    hapticsOn = m['haptics'] as bool? ?? true;
    reduceMotion = m['reduceMotion'] as bool? ?? false;
  }

  /// Writes the whole save as one document (one key, one write).
  void _save() {
    final json = jsonEncode(_toJson());
    _unsaved = true;
    _store.write(SaveSchema.key, json).then(
      (ok) {
        // A newer write may have started meanwhile; only clear if this one won.
        if (ok && _lastWritten == json) _unsaved = false;
      },
      onError: (Object _) {},
    );
    _lastWritten = json;
  }

  String? _lastWritten;

  /// Retries persisting the current state (e.g. after a failed write).
  Future<bool> flush() async {
    final json = jsonEncode(_toJson());
    _lastWritten = json;
    try {
      final ok = await _store.write(SaveSchema.key, json);
      if (ok) _unsaved = false;
      return ok;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> _toJson() => {
        'schema': SaveSchema.current,
        'coins': _coins,
        'lives': _lives,
        'nextLifeAt': _nextLifeAtMs,
        'unlocked': _unlockedLevel,
        'stars': {for (final e in _stars.entries) '${e.key}': e.value},
        'shuffles': _shuffles,
        'extraBottles': _extraBottles,
        'undos': _undos,
        'dailyClaim': _lastDailyClaim,
        'dailyStreak': _dailyStreak,
        'giftAt': _lastGiftAtMs,
        'giftId': _lastGiftId,
        'runs': {for (final e in _runs.entries) '${e.key}': e.value.toJson()},
        'sound': soundOn,
        'music': musicOn,
        'sfxVolume': sfxVolume,
        'musicVolume': musicVolume,
        'haptics': hapticsOn,
        'reduceMotion': reduceMotion,
        'processed': _processed,
      };

  /// Save without notifying (inside a transaction: deferred).
  void _persist() {
    if (_txDepth > 0) {
      _txDirty = true;
    } else {
      _save();
    }
  }

  /// Save and notify listeners (inside a transaction: deferred to its end).
  void _commit() {
    if (_txDepth > 0) {
      _txDirty = true;
      return;
    }
    _save();
    notifyListeners();
  }
}
