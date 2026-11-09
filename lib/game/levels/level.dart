import '../engine/ball_type.dart';
import '../engine/game_state.dart';

/// Static definition of a puzzle.
class Level {
  const Level({
    required this.number,
    required this.layout,
    required this.par,
    this.capacity = 4,
  });

  final int number;

  /// One string per bottle, bottom → top, using [BallType.code].
  final List<String> layout;

  /// Minimum moves to solve (computed by `tool/level_tool.dart`).
  final int par;

  final int capacity;

  GameState createState() => GameState.parse(layout, capacity: capacity);

  Set<BallType> get ballTypes => {
    for (final b in layout)
      for (final c in b.split('')) BallType.fromCode(c),
  };

  /// 3 stars at par (+ small slack), 2 stars for a reasonable solve.
  int starsFor(int moves) {
    if (moves <= par + 2) return 3;
    if (moves <= (par * 1.5).ceil() + 3) return 2;
    return 1;
  }
}
