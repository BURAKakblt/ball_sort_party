import 'package:ball_sort_party/app.dart';
import 'package:ball_sort_party/data/player_progress.dart';
import 'package:ball_sort_party/game/engine/solver.dart';
import 'package:ball_sort_party/game/flame/ball_sort_game.dart';
import 'package:ball_sort_party/game/levels/level_data.dart';
import 'package:ball_sort_party/screens/game/game_screen.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('playing level 1 by tapping bottles wins and saves progress', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final p = await PlayerProgress.load();
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      AppScope(progress: p, child: MaterialApp(home: GameScreen(level: kLevels.first))),
    );
    await tester.pump(const Duration(milliseconds: 600));

    final finder = find.byType(GameWidget<BallSortGame>);
    final game = tester.widget<GameWidget<BallSortGame>>(finder).game!;
    final origin = tester.getTopLeft(finder);
    Future<void> tapBottle(int i) async {
      await tester.tapAt(origin + game.bottleRect(i).center);
      await tester.pump(const Duration(milliseconds: 50));
    }

    final solution = const Solver().solve(kLevels.first.createState())!;
    for (final move in solution) {
      await tapBottle(move.from);
      await tapBottle(move.to);
      await tester.pump(const Duration(milliseconds: 700));
    }
    expect(game.engine.isSolved, isTrue);
    expect(find.text('Hamle: ${solution.length}   •   Hedef: ${kLevels.first.par}'), findsOneWidget);

    // Victory animation then overlay.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('TEBRİKLER!'), findsOneWidget);
    expect(p.unlockedLevel, 2);
    expect(p.starsFor(1), greaterThan(0));
    expect(p.lives, PlayerProgress.maxLives, reason: 'winning costs no life');

    // Let confetti finish so no animation is left running.
    await tester.pump(const Duration(seconds: 4));
  });
}
