// ignore_for_file: avoid_print
// Generates levels [from..to] for the 50-level curve and appends them as JSON
// lines to [out]. Already generated levels in [out] are kept and used to
// avoid duplicates, so the work can be done in small groups:
//
//   dart run tool/level_gen.dart 1 10 /tmp/levels.jsonl
//
// A level is accepted only if:
// - the casual-player win rate (simulation estimate, NOT real player data)
//   and the optimal move count fall inside the level's target window, and
// - the solver PROVES it solvable (search finished without hitting its
//   state limit; BFS optimum found).
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:ball_sort_party/game/engine/ball_type.dart';
import 'package:ball_sort_party/game/engine/game_state.dart';
import 'package:ball_sort_party/game/engine/solver.dart';
import 'package:ball_sort_party/game/levels/difficulty.dart';

/// Difficulty target for one level.
class Target {
  const Target(this.configs, this.winMin, this.winMax, this.parMin, this.parMax);

  /// Allowed (ball types, empty bottles) combinations.
  final List<(int, int)> configs;
  final double winMin, winMax;
  final int parMin, parMax;
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

Target targetFor(int n) {
  switch (n) {
    case 2:
      return const Target([(2, 2)], 98, 100, 3, 6);
    case 3:
      return const Target([(3, 2)], 98, 100, 5, 8);
    case 4:
      return const Target([(3, 2)], 97, 100, 7, 9);
    case 5:
      return const Target([(3, 2)], 95, 100, 8, 10);
    case 6:
      return const Target([(4, 2)], 93, 100, 9, 12); // tennis arrives
    case 7:
      return const Target([(4, 2)], 88, 97, 11, 13);
    case 8:
      return const Target([(4, 2)], 83, 93, 12, 14);
    case 9:
      return const Target([(5, 2)], 78, 90, 14, 17); // volleyball arrives
    case 10:
      return const Target([(5, 2), (3, 1)], 66, 78, 12, 18);
  }
  if (n <= 20) {
    final c = _lerp(68, 48, (n - 11) / 9);
    return Target(const [(5, 2), (3, 1)], c - 5, c + 5, 12, 21);
  }
  if (n <= 35) {
    // Harder means more planning, not only fewer spare bottles: the
    // minimum solution length grows too.
    final c = _lerp(45, 22, (n - 21) / 14);
    final parMin = _lerp(17, 19, (n - 21) / 14).round();
    return Target(const [(3, 1), (5, 2), (4, 1)], c - 4, c + 4, parMin, 26);
  }
  final c = _lerp(20, 4, (n - 36) / 14);
  final parMin = _lerp(19, 22, (n - 36) / 14).round();
  return Target(const [(4, 1), (5, 1)], max(1.5, c - 3), c + 3, parMin, 32);
}

/// Same puzzle regardless of bottle order and of which sport is which.
String relabelKey(List<String> layout) {
  final codes = layout.join().split('').toSet().toList()..sort();
  String? best;
  void perm(List<String> rest, List<String> chosen) {
    if (rest.isEmpty) {
      final map = {for (var i = 0; i < codes.length; i++) codes[i]: chosen[i]};
      final key = ([for (final b in layout) b.split('').map((c) => map[c]).join()]..sort()).join('|');
      if (best == null || key.compareTo(best!) < 0) best = key;
      return;
    }
    for (var i = 0; i < rest.length; i++) {
      perm([...rest]..removeAt(i), [...chosen, rest[i]]);
    }
  }

  perm(List.generate(codes.length, (i) => '$i'), []);
  return best!;
}

/// Number of differing ball positions between two layouts of the same shape,
/// minimised over relabelings of the sports (bottles compared in sorted order).
/// Null when shapes differ (different types / bottle count → not similar).
int? distance(List<String> a, List<String> b) {
  final ca = (a.join().split('').toSet().toList()..sort());
  final cb = (b.join().split('').toSet().toList()..sort());
  if (ca.length != cb.length || a.length != b.length) return null;
  final sa = ([...a]..sort()).join();
  var best = 1 << 30;
  void perm(List<String> rest, List<String> chosen) {
    if (rest.isEmpty) {
      final map = {for (var i = 0; i < cb.length; i++) cb[i]: chosen[i]};
      final sb = ([for (final x in b) x.split('').map((c) => map[c]).join()]..sort()).join();
      var d = 0;
      for (var i = 0; i < sa.length && i < sb.length; i++) {
        if (sa[i] != sb[i]) d++;
      }
      if (d < best) best = d;
      return;
    }
    for (var i = 0; i < rest.length; i++) {
      perm([...rest]..removeAt(i), [...chosen, rest[i]]);
    }
  }

  perm(ca, []);
  return best;
}

/// Too close to an existing level: < 25 % of balls differ, or 2+ identical
/// (non-empty) bottles shared.
bool tooSimilar(List<String> layout, Iterable<List<String>> others) {
  final balls = layout.join().length;
  final bottles = layout.where((b) => b.isNotEmpty).toSet();
  for (final o in others) {
    if (bottles.intersection(o.toSet()).length >= 2) return true;
    // The relabeling is applied to one side only, so check both directions.
    final d1 = distance(layout, o), d2 = distance(o, layout);
    if (d1 != null && min(d1, d2!) < (balls / 4).ceil()) return true;
  }
  return false;
}

void main(List<String> args) {
  final from = int.parse(args[0]);
  final to = int.parse(args[1]);
  final out = File(args[2]);
  final existing = <int, Map<String, dynamic>>{};
  if (out.existsSync()) {
    for (final line in out.readAsLinesSync().where((l) => l.trim().isNotEmpty)) {
      final m = jsonDecode(line) as Map<String, dynamic>;
      existing[m['n'] as int] = m;
    }
  }
  final used = {for (final m in existing.values) relabelKey(List<String>.from(m['layout'] as List))};
  final layouts = [for (final m in existing.values) List<String>.from(m['layout'] as List)];
  const solver = Solver(maxStates: 3000000);

  for (var n = from; n <= to; n++) {
    if (existing.containsKey(n)) continue;
    if (n == 1) {
      const tutorial = ['BBBF', 'FFFB', ''];
      final s = GameState.parse(tutorial);
      _emit(out, n, tutorial, solver.minimumMoves(s)!, casualWins(s, playouts: 1000), used);
      layouts.add(tutorial);
      continue;
    }
    final t = targetFor(n);
    var widen = 0.0;
    var accepted = false;
    for (var attempt = 0; !accepted; attempt++) {
      if (attempt > 0 && attempt % 15000 == 0) {
        widen += 2;
        print('  L$n: widening win window by ±$widen');
      }
      final (types, empties) = t.configs[(attempt + n) % t.configs.length];
      final rnd = Random(n * 1000003 + attempt);
      final balls = [for (final b in BallType.values.take(types)) ...List.filled(4, b)]..shuffle(rnd);
      final bottles = [
        for (var b = 0; b < types; b++) balls.sublist(b * 4, b * 4 + 4),
        for (var e = 0; e < empties; e++) <BallType>[],
      ];
      // No ready-made bottle and no 3 identical balls on the bottom.
      if (bottles.any((b) => b.length == 4 && b.sublist(0, 3).toSet().length == 1)) continue;
      final state = GameState(bottles);
      final layout = state.toLayout();
      final key = relabelKey(layout);
      if (used.contains(key)) continue;
      final lo = t.winMin - widen, hi = t.winMax + widen;
      final quick = casualWins(state, playouts: 120, seed: attempt);
      if (quick < lo - 8 || quick > hi + 8) continue;
      if (tooSimilar(layout, layouts)) continue;
      final win = casualWins(state, playouts: 1000);
      if (win < lo || win > hi) continue;
      if (solver.analyze(state) != Solvability.solvable) continue; // proven only
      final par = solver.minimumMoves(state);
      if (par == null || par < t.parMin || par > t.parMax) continue;
      _emit(out, n, layout, par, win, used);
      layouts.add(layout);
      accepted = true;
    }
  }
}

void _emit(File out, int n, List<String> layout, int par, double win, Set<String> used) {
  used.add(relabelKey(layout));
  final types = layout.join().split('').toSet().length;
  final empties = layout.where((b) => b.isEmpty).length;
  out.writeAsStringSync(
    '${jsonEncode({'n': n, 'layout': layout, 'par': par, 'win': win, 'types': types, 'empties': empties})}\n',
    mode: FileMode.append,
  );
  print('L$n par=$par casual=${win.toStringAsFixed(1)}% types=$types empties=$empties $layout');
}
