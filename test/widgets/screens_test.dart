import 'package:ball_sort_party/app.dart';
import 'package:ball_sort_party/data/player_progress.dart';
import 'package:ball_sort_party/game/levels/level_data.dart';
import 'package:ball_sort_party/game/engine/failure_monitor.dart';
import 'package:ball_sort_party/screens/game/game_screen.dart';
import 'package:ball_sort_party/screens/game/level_complete_overlay.dart';
import 'package:ball_sort_party/screens/game/rescue_overlay.dart';
import 'package:ball_sort_party/screens/game/out_of_lives_screen.dart';
import 'package:ball_sort_party/screens/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Screen sizes: iPhone SE (1st gen) and a large phone.
const _sizes = [Size(320, 568), Size(430, 932)];

Future<PlayerProgress> _progress() async {
  SharedPreferences.setMockInitialValues({});
  return PlayerProgress.load();
}

Future<void> _pump(WidgetTester tester, Size size, Widget home, PlayerProgress p) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    AppScope(progress: p, child: MaterialApp(home: home)),
  );
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  for (final size in _sizes) {
    final tag = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('main shell and all tabs render without overflow @$tag', (tester) async {
      final p = await _progress();
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(BallSortPartyApp(progress: p));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('OYNA'), findsOneWidget);

      for (final tab in ['Mağaza', 'Seviyeler', 'Koleksiyon', 'Ana Sayfa']) {
        await tester.tap(find.text(tab).last);
        await tester.pump(const Duration(milliseconds: 400));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('game screen renders @$tag', (tester) async {
      final p = await _progress();
      await _pump(tester, size, GameScreen(level: kLevels.last), p);
      expect(find.text('BÖLÜM ${kLevels.last.number}'), findsOneWidget);
      expect(find.text('Geri Al'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('settings and out-of-lives render @$tag', (tester) async {
      final p = await _progress();
      for (var i = 0; i < PlayerProgress.maxLives; i++) {
        p.loseLife();
      }
      await _pump(tester, size, const OutOfLivesScreen(), p);
      expect(find.text('CANIN BİTTİ!'), findsOneWidget);
      await _pump(tester, size, const SettingsScreen(), p);
      expect(find.text('Ayarlar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('daily reward can be claimed from the home tab', (tester) async {
    final p = await _progress();
    tester.view.physicalSize = const Size(430, 932) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(BallSortPartyApp(progress: p));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('AL'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('GÜNLÜK ÖDÜL!'), findsOneWidget);
    expect(p.coins, PlayerProgress.startingCoins + 50);
  });

  testWidgets('settings switches change and persist audio preferences', (tester) async {
    final p = await _progress();
    await _pump(tester, const Size(430, 932), const SettingsScreen(), p);
    expect(find.text('Arka Plan Müziği'), findsOneWidget);
    expect(find.byType(Slider), findsNWidgets(2));
    await tester.tap(find.byType(Switch).at(0)); // music
    await tester.tap(find.byType(Switch).at(1)); // effects
    await tester.pump();
    expect(p.musicOn, isFalse);
    expect(p.soundOn, isFalse);
    final reloaded = await PlayerProgress.load();
    expect(reloaded.musicOn, isFalse);
    expect(reloaded.soundOn, isFalse);
  });

  testWidgets('tutorial, rescue and win overlays fit a 320x568 screen', (tester) async {
    final p = await _progress();
    await _pump(tester, const Size(320, 568), GameScreen(level: kLevels.first), p);
    expect(find.textContaining('futbol topu'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _pump(
      tester,
      const Size(320, 568),
      Scaffold(
        body: RescueOverlay(
          status: BoardStatus.unsolvable,
          canUndo: true,
          canAddBottle: true,
          adReady: false,
          onUndo: () {},
          onCoinRescue: () {},
          onAdRescue: () {},
          onRetry: () {},
          onOutOfLives: () {},
          onHome: () {},
        ),
      ),
      p,
    );
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('ÇÖZÜM KALMADI!'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _pump(
      tester,
      const Size(320, 568),
      Scaffold(
        body: LevelCompleteOverlay(level: kLevels.last, stars: 3, coins: 50, moves: 15, onReplay: () {}),
      ),
      p,
    );
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('TEBRİKLER!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
