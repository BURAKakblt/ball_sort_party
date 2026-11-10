import '../game/session/level_run.dart';

/// Best result for one level, as synced to the cloud.
class CloudLevelRecord {
  const CloudLevelRecord({required this.stars, required this.sig, this.completedAtMs});

  /// 1..3
  final int stars;

  /// Layout signature the stars were earned on (`legacy` for old records).
  final String sig;

  /// Last completion time (device clock). Used to drop attempts that were
  /// finished elsewhere.
  final int? completedAtMs;

  Map<String, Object?> toJson() => {
    'stars': stars,
    'sig': sig,
    if (completedAtMs != null) 'at': completedAtMs,
  };

  static CloudLevelRecord? fromJson(Object? json) {
    if (json is! Map) return null;
    final stars = json['stars'], sig = json['sig'], at = json['at'];
    if (stars is! num || sig is! String) return null;
    final s = stars.toInt();
    if (s < 1 || s > 3) return null;
    return CloudLevelRecord(stars: s, sig: sig, completedAtMs: at is num ? at.toInt() : null);
  }

  @override
  bool operator ==(Object other) =>
      other is CloudLevelRecord &&
      other.stars == stars &&
      other.sig == sig &&
      other.completedAtMs == completedAtMs;

  @override
  int get hashCode => Object.hash(stars, sig, completedAtMs);
}

/// Player-owned progress that may be synced between devices.
///
/// Deliberately contains NO economy values (coins, lives, items, purchases):
/// those are server-authoritative and live in a separate, client-read-only
/// document (see docs/cloud/README.md).
class CloudProgress {
  const CloudProgress({
    required this.unlockedLevel,
    required this.levels,
    required this.runs,
    this.updatedAtMs = 0,
    this.deviceId,
  });

  static const schema = 1;

  static const empty = CloudProgress(unlockedLevel: 1, levels: {}, runs: {});

  final int unlockedLevel;
  final Map<int, CloudLevelRecord> levels;

  /// Unfinished attempts (PLAYING / FAILED) per level.
  final Map<int, LevelRun> runs;
  final int updatedAtMs;
  final String? deviceId;

  Map<String, Object?> toJson() => {
    'schema': schema,
    'unlockedLevel': unlockedLevel,
    'levels': {for (final e in levels.entries) '${e.key}': e.value.toJson()},
    'runs': {for (final e in runs.entries) '${e.key}': e.value.toJson()},
    'updatedAtMs': updatedAtMs,
    if (deviceId != null) 'deviceId': deviceId,
  };

  /// Lenient parser: anything malformed is skipped instead of throwing.
  static CloudProgress fromJson(Object? json, {required int levelCount}) {
    if (json is! Map) return empty;
    int? asLevel(Object? k) {
      final n = int.tryParse('$k');
      return n != null && n >= 1 && n <= levelCount ? n : null;
    }

    final levels = <int, CloudLevelRecord>{};
    final rawLevels = json['levels'];
    if (rawLevels is Map) {
      for (final e in rawLevels.entries) {
        final n = asLevel(e.key);
        final r = CloudLevelRecord.fromJson(e.value);
        if (n != null && r != null) levels[n] = r;
      }
    }
    final runs = <int, LevelRun>{};
    final rawRuns = json['runs'];
    if (rawRuns is Map) {
      for (final e in rawRuns.entries) {
        final n = asLevel(e.key);
        final r = LevelRun.fromJson(e.value);
        if (n != null && r != null) runs[n] = r;
      }
    }
    final unlocked = json['unlockedLevel'];
    final at = json['updatedAtMs'];
    final device = json['deviceId'];
    return CloudProgress(
      unlockedLevel: unlocked is num ? unlocked.toInt().clamp(1, levelCount + 1) : 1,
      levels: levels,
      runs: runs,
      updatedAtMs: at is num ? at.toInt() : 0,
      deviceId: device is String ? device : null,
    );
  }
}
