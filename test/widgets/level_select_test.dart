import 'package:ball_sort_party/app.dart';
import 'package:ball_sort_party/data/player_progress.dart';
import 'package:ball_sort_party/game/levels/level_data.dart';
import 'package:ball_sort_party/screens/game/game_screen.dart';
import 'package:ball_sort_party/screens/levels/levels_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<PlayerProgress> _progress({int cleared = 0}) async {
  SharedPreferences.setMockInitialValues({});
  final p = await PlayerProgress.load();
  for (var n = 1; n <= cleared; n++) {
    p.completeLevel(n, (n % 3) + 1);
  }
  return p;
}

Future<void> _pump(WidgetTester tester, PlayerProgress p, Size size) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(AppScope(progress: p, child: const MaterialApp(home: Scaffold(body: LevelsScreen()))));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The list opens scrolled to the current level; go back to the top.
Future<void> _toTop(WidgetTester tester) async {
  await tester.drag(find.byType(Scrollable).first, const Offset(0, 5000));
  await _frames(tester);
}

Finder _tile(int n) => find.bySemanticsLabel(RegExp('^Bölüm $n(,|\$)'));

void main() {
  testWidgets('locked levels cannot be opened; unlocked ones start the game', (tester) async {
    final p = await _progress(cleared: 2);
    await _pump(tester, p, const Size(430, 932));
    await _toTop(tester);
    expect(find.text('DEVAM: BÖLÜM 3'), findsOneWidget);
    await tester.ensureVisible(_tile(4));
    await tester.tap(_tile(4));
    await _frames(tester);
    expect(find.byType(GameScreen), findsNothing);
    expect(find.textContaining('Önce Bölüm 3'), findsOneWidget);

    await tester.ensureVisible(_tile(2));
    await tester.tap(_tile(2)); // replay a completed level
    await _frames(tester);
    expect(find.byType(GameScreen), findsOneWidget);
  });

  testWidgets('opens scrolled to the current level and marks it', (tester) async {
    final p = await _progress(cleared: 29);
    await _pump(tester, p, const Size(390, 844));
    final current = find.bySemanticsLabel(RegExp('^Bölüm 30, mevcut bölüm'));
    expect(current, findsOneWidget);
    final rect = tester.getRect(current);
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(844), reason: 'current level is on screen without scrolling');
    expect(find.text('DEVAM: BÖLÜM 30'), findsNothing, reason: 'progress card scrolled away');
  });

  testWidgets('stars and band summaries are shown', (tester) async {
    final p = await _progress(cleared: 5);
    await _pump(tester, p, const Size(430, 932));
    await _toTop(tester);
    expect(find.bySemanticsLabel(RegExp('^Bölüm 1, .*yıldız')), findsOneWidget);
    expect(find.text('5 / ${kLevels.length} bölüm'), findsOneWidget);
    expect(find.textContaining('BAŞLANGIÇ', findRichText: true), findsOneWidget);
    // Band summary: 5 tutorial levels cleared with (n % 3) + 1 stars.
    final tutorialStars = [for (var n = 1; n <= 5; n++) (n % 3) + 1].reduce((a, b) => a + b);
    expect(find.text(' $tutorialStars/15'), findsOneWidget);
  });

  testWidgets('all 50 levels fit a 320x568 screen without overflow', (tester) async {
    final p = await _progress(cleared: 12);
    await _pump(tester, p, const Size(320, 568));
    await _toTop(tester);
    for (final n in [1, 20, 35, 50]) {
      await tester.scrollUntilVisible(_tile(n), 300, scrollable: find.byType(Scrollable).first);
      await tester.pump(const Duration(milliseconds: 500));
      expect(_tile(n), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
}
