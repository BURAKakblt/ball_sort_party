import 'dart:math';

import '../game/session/level_run.dart';
import 'cloud_models.dart';

/// Merges two copies of [CloudProgress] (e.g. this device and the cloud).
///
/// The merge is commutative, idempotent and MONOTONIC: a player's progress
/// can never go backwards because another device synced older data.
///
/// Rules:
/// - unlocked level: maximum.
/// - level records: a record earned on the CURRENT layout beats a legacy
///   one; between two current (or two legacy) records the higher star
///   count wins; completion time = latest of the winners.
/// - saved attempts: higher revision wins; on equal revision a FAILED
///   attempt beats a PLAYING one (a failure is never silently undone);
///   an attempt saved before the level's latest completion is dropped.
/// - economy (coins, lives, items) is NOT part of this data at all.
class ProgressMerge {
  const ProgressMerge(this.currentSigs);

  /// Level number → signature of its current layout.
  final Map<int, String> currentSigs;

  CloudProgress merge(CloudProgress a, CloudProgress b) {
    final levels = <int, CloudLevelRecord>{};
    for (final n in {...a.levels.keys, ...b.levels.keys}) {
      levels[n] = mergeRecord(n, a.levels[n], b.levels[n])!;
    }
    final runs = <int, LevelRun>{};
    for (final n in {...a.runs.keys, ...b.runs.keys}) {
      final run = mergeRun(a.runs[n], b.runs[n]);
      if (run == null) continue;
      final done = levels[n]?.completedAtMs;
      final saved = run.updatedAtMs;
      if (done != null && saved != null && saved <= done) continue; // finished elsewhere
      runs[n] = run;
    }
    var unlocked = max(a.unlockedLevel, b.unlockedLevel);
    // A cleared level always unlocks the next one.
    for (final n in levels.keys) {
      unlocked = max(unlocked, n + 1);
    }
    return CloudProgress(
      unlockedLevel: unlocked,
      levels: levels,
      runs: runs,
      updatedAtMs: max(a.updatedAtMs, b.updatedAtMs),
      deviceId: a.deviceId ?? b.deviceId,
    );
  }

  CloudLevelRecord? mergeRecord(int level, CloudLevelRecord? a, CloudLevelRecord? b) {
    if (a == null) return b;
    if (b == null) return a;
    final current = currentSigs[level];
    final aCurrent = a.sig == current, bCurrent = b.sig == current;
    if (aCurrent != bCurrent) return aCurrent ? a : b;
    int? latest(int? x, int? y) => x == null ? y : (y == null ? x : max(x, y));
    if (a.stars != b.stars) {
      final best = a.stars > b.stars ? a : b;
      return CloudLevelRecord(
        stars: best.stars,
        sig: best.sig,
        completedAtMs: latest(a.completedAtMs, b.completedAtMs),
      );
    }
    // Same stars: deterministic choice so merge(a,b) == merge(b,a).
    final sig = a.sig.compareTo(b.sig) <= 0 ? a.sig : b.sig;
    return CloudLevelRecord(stars: a.stars, sig: sig, completedAtMs: latest(a.completedAtMs, b.completedAtMs));
  }

  static LevelRun? mergeRun(LevelRun? a, LevelRun? b) {
    if (a == null) return b;
    if (b == null) return a;
    if (a.rev != b.rev) return a.rev > b.rev ? a : b;
    if (a.isFailed != b.isFailed) return a.isFailed ? a : b;
    // Same revision and status: deterministic tie-break.
    final ka = (a.updatedAtMs ?? 0), kb = (b.updatedAtMs ?? 0);
    if (ka != kb) return ka > kb ? a : b;
    return a.layout.join('|').compareTo(b.layout.join('|')) <= 0 ? a : b;
  }
}
