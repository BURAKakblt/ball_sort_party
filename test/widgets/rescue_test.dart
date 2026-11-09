import 'package:ball_sort_party/app.dart';
import 'package:ball_sort_party/data/economy_config.dart';
import 'package:ball_sort_party/data/player_progress.dart';
import 'package:ball_sort_party/game/engine/failure_monitor.dart';
import 'package:ball_sort_party/game/flame/ball_sort_game.dart';
import 'package:ball_sort_party/game/levels/level.dart';
import 'package:ball_sort_party/game/levels/level_data.dart';
import 'package:ball_sort_party/game/session/level_run.dart';
import 'package:ball_sort_party/screens/game/game_screen.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Solvable capacity-2 board where moving F (bottle 0) into the empty bottle
/// 3 leaves no valid move: ['B', 'BS', 'FS', 'F'].
const _trapLevel = Level(number: 1, par: 4, capacity: 2, layout: ['BF', 'BS', 'FS', '']);
const _start = ['BF', 'BS', 'FS', ''];

class _Harness {
  _Harness(this.tester, this.progress, this.nav);

  final WidgetTester tester;
  final PlayerProgress progress;
  final GlobalKey<NavigatorState> nav;

  BallSortGame get game =>
      tester.widget<GameWidget<BallSortGame>>(find.byType(GameWidget<BallSortGame>)).game!;

  Future<void> tapBottle(int i) async {
    final origin = tester.getTopLeft(find.byType(GameWidget<BallSortGame>));
    await tester.tapAt(origin + game.bottleRect(i).center);
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Let ball animations and overlay transitions finish.
  Future<void> settle() async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> tapText(String text) async {
    // Exact label first; labels with a counter (e.g. "GERİ AL  (5)") fall back
    // to a prefix match.
    final exact = find.text(text);
    final finder = exact.evaluate().isNotEmpty
        ? exact.last
        : find.byWidgetPredicate((w) => w is Text && (w.data ?? '').startsWith(text)).first;
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await settle();
  }

  Future<void> fallIntoTrap() async {
    await tapBottle(0);
    await tapBottle(3);
    await settle();
  }

  /// Leaves the level (to the menu) and opens it again.
  Future<void> reopenLevel(GlobalKey<NavigatorState> nav, {Level level = _trapLevel}) async {
    nav.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(level: level, analyzer: BoardAnalyzer(check: BoardAnalyzer.syncCheck)),
      ),
    );
    await settle();
  }
}

Future<_Harness> _open(
  WidgetTester tester, {
  int? coins,
  Level level = _trapLevel,
  PlayerProgress? progress,
}) async {
  if (progress == null) SharedPreferences.setMockInitialValues({});
  final p = progress ?? await PlayerProgress.load();
  if (coins != null) p.spend(p.coins - coins, () => true);
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final nav = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    AppScope(
      progress: p,
      child: MaterialApp(navigatorKey: nav, home: const Scaffold(body: Text('MENU'))),
    ),
  );
  nav.currentState!.push(
    MaterialPageRoute<void>(
      builder: (_) => GameScreen(
        level: level,
        analyzer: BoardAnalyzer(check: BoardAnalyzer.syncCheck),
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return _Harness(tester, p, nav);
}

void main() {
  testWidgets('invalid move costs nothing and changes nothing', (tester) async {
    final h = await _open(tester);
    await h.tapBottle(1); // pick S
    await h.tapBottle(0); // full bottle -> invalid
    await h.settle();
    expect(h.game.engine.state.toLayout(), _start);
    expect(h.game.engine.moveCount, 0);
    expect(h.progress.lives, PlayerProgress.maxLives);
    expect(h.progress.coins, EconomyConfig.startingCoins);
    expect(find.text('HAMLE KALMADI!'), findsNothing);
  });

  testWidgets('dead end opens the rescue screen once, without losing a life', (tester) async {
    final h = await _open(tester);
    await h.fallIntoTrap();
    expect(find.text('HAMLE KALMADI!'), findsOneWidget);
    expect(h.progress.lives, PlayerProgress.maxLives);
    await h.settle();
    expect(find.text('HAMLE KALMADI!'), findsOneWidget);
  });

  testWidgets('undo from the rescue restores the board: FAILED → PLAYING', (tester) async {
    final h = await _open(tester);
    await h.fallIntoTrap();
    expect(h.progress.isLevelFailed(1), isTrue);
    await h.tapText('GERİ AL');
    expect(find.text('HAMLE KALMADI!'), findsNothing);
    expect(find.text('ÇÖZÜM KALMADI!'), findsNothing);
    expect(h.progress.isLevelFailed(1), isFalse);
    expect(h.game.engine.state.toLayout(), _start);
    expect(h.progress.undos, EconomyConfig.startingUndos - 1);
    expect(h.progress.lives, PlayerProgress.maxLives);
  });

  testWidgets('200 coins buys an extra bottle and continues the level', (tester) async {
    final h = await _open(tester);
    await h.fallIntoTrap();
    await h.tapText('200 ALTINLA KURTAR');
    await h.tapText('200 ALTINA AL'); // confirmation
    expect(h.progress.coins, EconomyConfig.startingCoins - 200);
    expect(h.game.engine.state.bottleCount, 5);
    expect(find.text('HAMLE KALMADI!'), findsNothing);
    expect(h.progress.isLevelFailed(1), isFalse);
    expect(h.progress.lives, PlayerProgress.maxLives);
  });

  testWidgets('coin rescue is blocked without enough coins', (tester) async {
    final h = await _open(tester, coins: 199);
    await h.fallIntoTrap();
    expect(find.text('Yeterli altının yok'), findsOneWidget);
    await h.tapText('200 ALTINLA KURTAR');
    expect(find.text('200 ALTINA AL'), findsNothing);
    expect(h.progress.coins, 199);
    expect(h.game.engine.state.bottleCount, 4);
  });

  testWidgets('retry after failure costs exactly one life', (tester) async {
    final h = await _open(tester);
    await h.fallIntoTrap();
    await h.tapText('TEKRAR DENE');
    expect(h.progress.lives, PlayerProgress.maxLives - 1);
    expect(h.game.engine.state.toLayout(), _start);
    expect(h.game.engine.moveCount, 0);
    expect(find.text('HAMLE KALMADI!'), findsNothing);
  });

  testWidgets('retry is not possible with zero lives', (tester) async {
    final h = await _open(tester);
    for (var i = 0; i < PlayerProgress.maxLives; i++) {
      h.progress.loseLife();
    }
    await h.fallIntoTrap();
    expect(find.text('TEKRAR DENE'), findsNothing);
    expect(find.text('CAN YOK'), findsOneWidget);
    expect(h.progress.lives, 0);
  });

  testWidgets('manual restart does not cost a life', (tester) async {
    final h = await _open(tester, level: kLevels.first);
    await h.tapBottle(0);
    await h.tapBottle(2);
    await h.settle();
    expect(h.game.engine.moveCount, 1);
    await h.tapText('Baştan');
    await h.tapText('BAŞTAN BAŞLA');
    expect(h.game.engine.moveCount, 0);
    expect(h.progress.lives, PlayerProgress.maxLives);
  });

  testWidgets('going back to the menu from the rescue does not cost a life', (tester) async {
    final h = await _open(tester);
    await h.fallIntoTrap();
    await h.tapText('ANA MENÜ');
    expect(find.text('MENU'), findsOneWidget);
    expect(h.progress.lives, PlayerProgress.maxLives);
    expect(h.progress.isLevelFailed(1), isTrue);
  });

  testWidgets('FAILED → menu → same level → still FAILED; retry costs 1 life', (tester) async {
    final h = await _open(tester);
    await h.fallIntoTrap();
    await h.tapText('ANA MENÜ');
    await h.reopenLevel(h.nav);
    expect(find.text('HAMLE KALMADI!'), findsOneWidget, reason: 'no free restart via the menu');
    expect(h.game.engine.moveCount, 1);
    await h.tapText('TEKRAR DENE');
    expect(h.progress.lives, PlayerProgress.maxLives - 1);
    expect(h.game.engine.state.toLayout(), _start);
  });

  testWidgets('FAILED survives an app restart and is shown again', (tester) async {
    final h = await _open(tester, level: kLevels.first);
    // Play into a saved attempt on the real level 1, mark it FAILED as the
    // failure check would, then simulate closing and reopening the app.
    final engine = h.game.engine;
    final m = engine.state.validMoves().first;
    await h.tapBottle(m.from);
    await h.tapBottle(m.to);
    await h.settle();
    final run = h.progress.runFor(1)!;
    h.progress.saveRun(1, LevelRun(
      status: LevelStatus.failed,
      failReason: BoardStatus.deadlock,
      layout: run.layout,
      history: run.history,
      moveCount: run.moveCount,
      extraBottlesAdded: run.extraBottlesAdded,
    ));
    final reloaded = await PlayerProgress.load(); // app closed and reopened
    await tester.pumpWidget(const SizedBox());
    final h2 = await _open(tester, level: kLevels.first, progress: reloaded);
    expect(find.text('HAMLE KALMADI!'), findsOneWidget);
    expect(h2.game.engine.state.toLayout(), run.layout);
    expect(reloaded.lives, PlayerProgress.maxLives);
  });

  testWidgets('winning a level → COMPLETED (rewarded once, attempt cleared)', (tester) async {
    final h = await _open(tester);
    // Optimal solution: S→empty, S→S, F→F, B→B.
    for (final (from, to) in [(1, 3), (2, 3), (0, 2), (0, 1)]) {
      await h.tapBottle(from);
      await h.tapBottle(to);
      await h.settle();
    }
    expect(h.game.engine.isSolved, isTrue);
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('TEBRİKLER!'), findsOneWidget);
    expect(h.progress.runFor(1), isNull);
    expect(h.progress.isLevelFailed(1), isFalse);
    await tester.pump(const Duration(seconds: 4));
  });
}
