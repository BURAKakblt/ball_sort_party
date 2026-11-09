import 'ball_type.dart';

/// A single ball transfer between two bottles.
class Move {
  const Move(this.from, this.to);

  final int from;
  final int to;

  @override
  bool operator ==(Object other) =>
      other is Move && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() => 'Move($from -> $to)';
}

/// Immutable snapshot of the board. Each bottle lists balls bottom → top.
class GameState {
  GameState(List<List<BallType>> bottles, {this.capacity = 4})
    : bottles = List.unmodifiable(
        bottles.map((b) => List<BallType>.unmodifiable(b)),
      );

  /// Parses the compact format: one string per bottle, bottom → top.
  /// Example: `['BFS', 'SB', '']`.
  factory GameState.parse(List<String> layout, {int capacity = 4}) {
    return GameState([
      for (final bottle in layout)
        [for (final c in bottle.split('')) BallType.fromCode(c)],
    ], capacity: capacity);
  }

  final List<List<BallType>> bottles;
  final int capacity;

  int get bottleCount => bottles.length;

  BallType? topOf(int index) =>
      bottles[index].isEmpty ? null : bottles[index].last;

  bool isEmpty(int index) => bottles[index].isEmpty;

  bool isFull(int index) => bottles[index].length >= capacity;

  /// A bottle is complete when it is full and holds a single ball type.
  bool isComplete(int index) {
    final b = bottles[index];
    return b.length == capacity && b.every((t) => t == b.first);
  }

  /// Solved when every bottle is either empty or complete.
  bool get isSolved {
    for (var i = 0; i < bottles.length; i++) {
      if (bottles[i].isNotEmpty && !isComplete(i)) return false;
    }
    return true;
  }

  bool canMove(int from, int to) {
    if (from == to) return false;
    if (from < 0 || to < 0 || from >= bottleCount || to >= bottleCount) {
      return false;
    }
    if (isEmpty(from) || isComplete(from)) return false;
    if (isFull(to)) return false;
    final target = topOf(to);
    return target == null || target == topOf(from);
  }

  GameState apply(Move move) {
    assert(canMove(move.from, move.to), 'Illegal move $move');
    return _transfer(move.from, move.to);
  }

  /// Moves the top ball without validation (used for undo).
  GameState transferUnchecked(int from, int to) => _transfer(from, to);

  GameState _transfer(int from, int to) {
    final next = [for (final b in bottles) List<BallType>.of(b)];
    next[to].add(next[from].removeLast());
    return GameState(next, capacity: capacity);
  }

  GameState withExtraBottle() =>
      GameState([...bottles, const []], capacity: capacity);

  Iterable<Move> validMoves() sync* {
    for (var f = 0; f < bottleCount; f++) {
      for (var t = 0; t < bottleCount; t++) {
        if (canMove(f, t)) yield Move(f, t);
      }
    }
  }

  bool get hasValidMoves => validMoves().isNotEmpty;

  /// Order-independent key, used for solver de-duplication.
  String get canonicalKey {
    final parts = [for (final b in bottles) b.map((t) => t.code).join()]
      ..sort();
    return parts.join('|');
  }

  List<String> toLayout() => [
    for (final b in bottles) b.map((t) => t.code).join(),
  ];

  @override
  String toString() => 'GameState(${toLayout()})';
}
