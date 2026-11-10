import 'dart:math';

import 'package:ball_sort_party/cloud/cloud_models.dart';
import 'package:ball_sort_party/cloud/progress_merge.dart';
import 'package:ball_sort_party/game/engine/failure_monitor.dart';
import 'package:ball_sort_party/game/session/level_run.dart';
import 'package:flutter_test/flutter_test.dart';

const cur = 'CURRENT';
const merge = ProgressMerge({1: cur, 2: cur, 3: cur, 4: cur, 5: cur});

LevelRun run({required int rev, bool failed = false, int? at, String layout = 'BF'}) => LevelRun(
  status: failed ? LevelStatus.failed : LevelStatus.playing,
  failReason: failed ? BoardStatus.deadlock : null,
  layout: [layout, ''],
  history: const [],
  moveCount: rev,
  extraBottlesAdded: 0,
  rev: rev,
  updatedAtMs: at,
);

CloudProgress p({int unlocked = 1, Map<int, CloudLevelRecord> levels = const {}, Map<int, LevelRun> runs = const {}}) =>
    CloudProgress(unlockedLevel: unlocked, levels: levels, runs: runs);

/// Order-independent canonical form (map iteration order doesn't matter).
String key(CloudProgress x) {
  String canon(Object? v) {
    if (v is Map) {
      final keys = v.keys.map((k) => '$k').toList()..sort();
      return '{${keys.map((k) => '$k:${canon(v[k] ?? v[int.tryParse(k)])}').join(',')}}';
    }
    if (v is List) return '[${v.map(canon).join(',')}]';
    return '$v';
  }

  return canon(x.toJson());
}

void main() {
  test('unlocked level never goes backwards', () {
    expect(merge.merge(p(unlocked: 7), p(unlocked: 3)).unlockedLevel, 7);
    expect(merge.merge(p(unlocked: 3), p(unlocked: 7)).unlockedLevel, 7);
  });

  test('a cleared level always unlocks the next', () {
    final m = merge.merge(p(levels: {4: const CloudLevelRecord(stars: 2, sig: cur)}), p());
    expect(m.unlockedLevel, 5);
  });

  test('stars: best result wins, current layout beats legacy', () {
    final a = p(levels: {1: const CloudLevelRecord(stars: 1, sig: cur), 2: const CloudLevelRecord(stars: 3, sig: 'legacy')});
    final b = p(levels: {1: const CloudLevelRecord(stars: 3, sig: cur), 2: const CloudLevelRecord(stars: 1, sig: cur)});
    final m = merge.merge(a, b);
    expect(m.levels[1]!.stars, 3);
    expect(m.levels[2]!.sig, cur, reason: 'current-layout record replaces legacy');
    expect(m.levels[2]!.stars, 1);
  });

  test('saved attempts: higher revision wins; FAILED wins ties', () {
    expect(ProgressMerge.mergeRun(run(rev: 5), run(rev: 3, failed: true))!.rev, 5);
    final tie = ProgressMerge.mergeRun(run(rev: 4), run(rev: 4, failed: true))!;
    expect(tie.isFailed, isTrue, reason: 'a failure is never silently undone');
  });

  test('an attempt saved before the level was completed elsewhere is dropped', () {
    final a = p(runs: {3: run(rev: 2, at: 1000)});
    final b = p(levels: {3: const CloudLevelRecord(stars: 2, sig: cur, completedAtMs: 2000)});
    expect(merge.merge(a, b).runs, isEmpty);
    final newer = p(runs: {3: run(rev: 2, at: 3000)}); // replay started after the clear
    expect(merge.merge(newer, b).runs.keys, [3]);
  });

  test('merge is commutative, associative-safe and idempotent (random data)', () {
    final rnd = Random(4);
    CloudProgress random() => p(
      unlocked: 1 + rnd.nextInt(6),
      levels: {
        for (var n = 1; n <= 5; n++)
          if (rnd.nextBool())
            n: CloudLevelRecord(
              stars: 1 + rnd.nextInt(3),
              sig: rnd.nextBool() ? cur : 'legacy',
              completedAtMs: rnd.nextBool() ? rnd.nextInt(100) : null,
            ),
      },
      runs: {
        for (var n = 1; n <= 5; n++)
          if (rnd.nextInt(3) == 0) n: run(rev: rnd.nextInt(4), failed: rnd.nextBool(), at: 100 + rnd.nextInt(100)),
      },
    );
    for (var i = 0; i < 300; i++) {
      final a = random(), b = random(), c = random();
      expect(key(merge.merge(a, b)), key(merge.merge(b, a)));
      expect(key(merge.merge(a, a)), key(merge.merge(a, CloudProgress.empty).let((x) => merge.merge(x, a))));
      final ab = merge.merge(a, b);
      expect(key(merge.merge(ab, ab)), key(ab));
      expect(key(merge.merge(merge.merge(a, b), c)), key(merge.merge(a, merge.merge(b, c))));
      // Monotonic: nothing either side had is lost or downgraded.
      expect(ab.unlockedLevel, greaterThanOrEqualTo(max(a.unlockedLevel, b.unlockedLevel)));
      for (final n in {...a.levels.keys, ...b.levels.keys}) {
        expect(ab.levels.containsKey(n), isTrue);
      }
    }
  });

  test('cloud JSON round-trips and tolerates garbage', () {
    final x = p(unlocked: 4, levels: {2: const CloudLevelRecord(stars: 3, sig: cur, completedAtMs: 9)}, runs: {3: run(rev: 2)});
    final back = CloudProgress.fromJson(x.toJson(), levelCount: 5);
    expect(key(back), key(x));
    final junk = CloudProgress.fromJson({
      'unlockedLevel': 'many',
      'levels': {'1': {'stars': 9, 'sig': cur}, 'x': {}, '2': 'bad'},
      'runs': {'99': {}, '1': 'nope'},
    }, levelCount: 5);
    expect(junk.unlockedLevel, 1);
    expect(junk.levels, isEmpty);
    expect(junk.runs, isEmpty);
  });
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
