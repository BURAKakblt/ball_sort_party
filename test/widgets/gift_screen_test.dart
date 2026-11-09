import 'dart:math';

import 'package:ball_sort_party/app.dart';
import 'package:ball_sort_party/data/player_progress.dart';
import 'package:ball_sort_party/screens/gifts/gift_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final size in const [Size(320, 568), Size(430, 932)]) {
    testWidgets('opening a box grants one reward and starts the 48h timer @${size.width.toInt()}',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final p = await PlayerProgress.load();
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        AppScope(progress: p, child: MaterialApp(home: GiftScreen(random: Random(7)))),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Bir kutu seç!'), findsOneWidget);

      final before = (p.coins, p.lives, p.shuffles, p.extraBottles);
      await tester.tap(find.bySemanticsLabel('Hediye kutusu 2'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('TOPLA'), findsOneWidget);
      expect(p.canOpenGift, isFalse);
      final after = (p.coins, p.lives, p.shuffles, p.extraBottles);
      expect(after, isNot(before));

      await tester.tap(find.text('TOPLA'));
      await tester.pump(const Duration(milliseconds: 300));
      // A second box cannot be opened.
      await tester.tap(find.bySemanticsLabel('Hediye kutusu 5'));
      await tester.pump(const Duration(milliseconds: 300));
      expect((p.coins, p.lives, p.shuffles, p.extraBottles), after);
      expect(find.text('SONRAKİ HEDİYE'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 4)); // let confetti finish
    });
  }
}
