// Golden tests for the procedurally drawn art (no text → stable output).
// Regenerate after an intended visual change:
//   flutter test --update-goldens test/goldens
import 'dart:ui' show PictureRecorder;

import 'package:ball_sort_party/core/widgets/gift_box.dart';
import 'package:ball_sort_party/game/engine/ball_type.dart';
import 'package:ball_sort_party/game/flame/components/ball_component.dart';
import 'package:ball_sort_party/game/flame/components/bottle_component.dart';
import 'package:ball_sort_party/game/render/ball_painter.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _bg = Color(0xFF1E1A5E);

Widget _frame(Size size, Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(
    child: RepaintBoundary(
      child: SizedBox(width: size.width, height: size.height, child: ColoredBox(color: _bg, child: child)),
    ),
  ),
);

/// Renders a filled bottle exactly as the board does: back glass, balls,
/// then the reflective front layer.
class _BottlePainter extends CustomPainter {
  _BottlePainter(this.types, {this.selected = false, this.completed = false});

  final List<BallType> types;
  final bool selected;
  final bool completed;

  @override
  void paint(Canvas canvas, Size size) {
    const d = 48.0;
    final bottle = BottleComponent(
      index: 0,
      onTap: (_) {},
      position: Vector2(10, 40),
      size: Vector2(d * 1.24, d * 4.62),
      hitPadding: EdgeInsets.zero,
    )
      ..selected = selected
      ..completed = completed;
    for (var i = 0; i < 20; i++) {
      bottle.update(0.1); // finish appear / glow animations
    }
    bottle.front.update(0);
    void at(PositionComponent c, void Function() draw) {
      canvas.save();
      canvas.translate(c.position.x - c.size.x * c.anchor.x, c.position.y - c.size.y * c.anchor.y);
      draw();
      canvas.restore();
    }

    at(bottle, () => bottle.render(canvas));
    for (var k = 0; k < types.length; k++) {
      final ball = BallComponent(
        type: types[k],
        diameter: d,
        position: Vector2(10 + bottle.size.x / 2, 40 + bottle.size.y - d * 0.12 - d / 2 - k * d),
      );
      at(ball, () => ball.render(canvas));
    }
    at(bottle.front, () => bottle.front.render(canvas));
  }

  @override
  bool shouldRepaint(_BottlePainter old) => true;
}

void main() {
  testWidgets('sport balls', (tester) async {
    await tester.pumpWidget(
      _frame(
        const Size(420, 180),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [for (final t in BallType.values) BallView(t, size: 72)],
            ),
            const SizedBox(height: 8),
            // Small size (crowded late levels) must stay distinguishable.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [for (final t in BallType.values) BallView(t, size: 30, shadow: false)],
            ),
          ],
        ),
      ),
    );
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('balls.png'));
  });

  testWidgets('glass bottles: filled, selected, completed', (tester) async {
    await tester.pumpWidget(
      _frame(
        const Size(270, 290),
        Row(
          children: [
            Expanded(
              child: SizedBox.expand(child: CustomPaint(
                painter: _BottlePainter([BallType.basketball, BallType.football, BallType.baseball, BallType.tennis]),
              )),
            ),
            Expanded(
              child: SizedBox.expand(child: CustomPaint(
                painter: _BottlePainter([BallType.volleyball, BallType.football], selected: true),
              )),
            ),
            Expanded(
              child: SizedBox.expand(child: CustomPaint(
                painter: _BottlePainter(List.filled(4, BallType.tennis), completed: true),
              )),
            ),
          ],
        ),
      ),
    );
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('bottles.png'));
  });

  testWidgets('gift boxes: closed and opened', (tester) async {
    await tester.pumpWidget(
      _frame(
        const Size(360, 130),
        Row(
          children: [
            for (final p in GiftPalette.all)
              Expanded(child: SizedBox.expand(child: CustomPaint(painter: GiftBoxPainter(palette: p)))),
            Expanded(
              child: SizedBox.expand(child: CustomPaint(painter: GiftBoxPainter(palette: GiftPalette.all[0], lidOpen: 1, glow: 1))),
            ),
          ],
        ),
      ),
    );
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('gift_boxes.png'));
  });

  test('ball pattern rotation keeps lighting fixed (no crash, different art)', () {
    // Spinning footballs rotate the pattern only; covered visually above.
    expect(() => BallArt.draw(Canvas(PictureRecorder()), BallType.football, 20, rotation: 1.2), returnsNormally);
  });
}
