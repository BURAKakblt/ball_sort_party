import 'package:ball_sort_party/game/engine/ball_type.dart';
import 'package:ball_sort_party/game/flame/components/ball_component.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final type in BallType.values) {
    test('$type: landing event fires at the moment of impact, once', () {
      final ball = BallComponent(type: type, diameter: 40, position: Vector2(0, 200));
      final slot = Vector2(100, 200);
      var lands = 0, settles = 0;
      double? yAtLand;
      var minYBeforeLand = double.infinity;
      ball.flyTo(
        liftPos: Vector2(0, 100),
        above: Vector2(100, 100),
        slot: slot,
        onLand: () {
          lands++;
          yAtLand = ball.position.y;
        },
        onSettled: () => settles++,
      );
      for (var i = 0; i < 200; i++) {
        ball.update(1 / 120);
        if (lands == 0) minYBeforeLand = ball.position.y < minYBeforeLand ? ball.position.y : minYBeforeLand;
      }
      expect(lands, 1);
      expect(settles, 1);
      expect(yAtLand, closeTo(slot.y, 0.001), reason: 'sound plays when the ball touches the slot');
      expect(minYBeforeLand, lessThan(slot.y - 50), reason: 'ball was in the air before');
      expect(ball.position, slot, reason: 'ends exactly in its slot after rebounds');
    });
  }

  test('interrupting a flight settles once and plays no landing sound', () {
    final ball = BallComponent(type: BallType.tennis, diameter: 40, position: Vector2.zero());
    var lands = 0, settles = 0;
    ball.flyTo(
      liftPos: Vector2(0, -50),
      above: Vector2(100, -50),
      slot: Vector2(100, 0),
      onLand: () => lands++,
      onSettled: () => settles++,
    );
    ball.update(0.1);
    ball.lift(Vector2(50, -80)); // player grabs it mid-air
    for (var i = 0; i < 100; i++) {
      ball.update(1 / 60);
    }
    expect(lands, 0);
    expect(settles, 1);
  });
}
