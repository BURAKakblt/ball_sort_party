import 'package:ball_sort_party/app.dart';
import 'package:ball_sort_party/data/economy_config.dart';
import 'package:ball_sort_party/data/player_progress.dart';
import 'package:ball_sort_party/game/engine/failure_monitor.dart';
import 'package:ball_sort_party/game/flame/ball_sort_game.dart';
import 'package:ball_sort_party/game/levels/level.dart';
import 'package:ball_sort_party/game/levels/level_data.dart';
import 'package:ball_sort_party/screens/game/game_screen.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Capacity-2 board where moving F (bottle 0) into the empty bottle 2 leaves
/// no valid move: ['B', 'S', 'F'].
const _trapLevel = Level(number: 1, par: 2, capacity: 2, layout: ['BF', 'S', '']);

class _Harness {
  _Harness(this.tester, this.progress);

  final WidgetTester tester;
  final PlayerProgress progress;

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
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    await settle();
  }

  Future<void> fallIntoTrap() async {
    await tapBottle(0);
    await tapBottle(2);
    await settle();
  }
}

Future<_Harness> _open(WidgetTester tester, {int? coins, Level level = _trapLevel}) async {
  SharedPreferences.setMockInitialValues({});
  final p = await PlayerProgress.load();
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
  return _Harness(tester, p);
}

void main() {
  testWidgets('invalid move costs nothing and changes nothing', (tester) async {
    final h = await _open(tester);
    await h.tapBottle(1); // pick S
    await h.tapBottle(0); // full bottle -> invalid
    await h.settle();
    expect(h.game.engine.state.toLayout(), ['BF', 'S', '']);
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

  testWidgets('undo from the rescue restores the board', (tester) async {
    final h = await _open(tester);
    await h.fallIntoTrap();
    await h.tapText('GERİ AL');
    expect(find.text('HAMLE KALMADI!'), findsNothing);
    expect(h.game.engine.state.toLayout(), ['BF', 'S', '']);
    expect(h.progress.undos, EconomyConfig.startingUndos - 1);
    expect(h.progress.lives, PlayerProgress.maxLives);
  });

  testWidgets('200 coins buys an extra bottle and continues the level', (tester) async {
    final h = await _open(tester);
    await h.fallIntoTrap();
    await h.tapText('200 ALTINLA KURTAR');
    await h.tapText('200 ALTINA AL'); // confirmation
    expect(h.progress.coins, EconomyConfig.startingCoins - 200);
    expect(h.game.engine.state.bottleCount, 4);
    expect(find.text('HAMLE KALMADI!'), findsNothing);
    expect(h.progress.lives, PlayerProgress.maxLives);
  });

  testWidgets('coin rescue is blocked without enough coins', (tester) async {
    final h = await _open(tester, coins: 199);
    await h.fallIntoTrap();
    expect(find.text('Yeterli altının yok'), findsOneWidget);
    await h.tapText('200 ALTINLA KURTAR');
    expect(find.text('200 ALTINA AL'), findsNothing);
    expect(h.progress.coins, 199);
    expect(h.game.engine.state.bottleCount, 3);
  });

  testWidgets('retry after failure costs exactly one life', (tester) async {
    final h = await _open(tester);
    await h.fallIntoTrap();
    await h.tapText('TEKRAR DENE');
    expect(h.progress.lives, PlayerProgress.maxLives - 1);
    expect(h.game.engine.state.toLayout(), ['BF', 'S', '']);
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
  });
}
