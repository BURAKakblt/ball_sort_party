import '../engine/failure_monitor.dart';
import '../engine/game_engine.dart';
import '../engine/game_state.dart';
import '../levels/level.dart';

/// Lifecycle of one attempt at a level.
enum LevelStatus { playing, failed, completed }

/// Persisted snapshot of an unfinished attempt (PLAYING or FAILED).
/// COMPLETED attempts are not stored.
class LevelRun {
  const LevelRun({
    required this.status,
    required this.layout,
    required this.history,
    required this.moveCount,
    required this.extraBottlesAdded,
    this.failReason,
  });

  factory LevelRun.fromEngine(GameEngine engine, LevelStatus status, {BoardStatus? failReason}) {
    return LevelRun(
      status: status,
      layout: engine.state.toLayout(),
      history: engine.history,
      moveCount: engine.moveCount,
      extraBottlesAdded: engine.extraBottlesAdded,
      failReason: status == LevelStatus.failed ? failReason : null,
    );
  }

  final LevelStatus status;
  final List<String> layout;
  final List<Move> history;
  final int moveCount;
  final int extraBottlesAdded;

  /// Why the attempt failed (deadlock / unsolvable), when FAILED.
  final BoardStatus? failReason;

  bool get isFailed => status == LevelStatus.failed;

  LevelRun copyWith({LevelStatus? status, BoardStatus? failReason}) => LevelRun(
    status: status ?? this.status,
    layout: layout,
    history: history,
    moveCount: moveCount,
    extraBottlesAdded: extraBottlesAdded,
    failReason: failReason ?? this.failReason,
  );

  /// Rebuilds the engine for [level].
  GameEngine toEngine(Level level) => GameEngine.restore(
    level.createState(),
    current: GameState.parse(layout, capacity: level.capacity),
    history: history,
    moveCount: moveCount,
    extraBottlesAdded: extraBottlesAdded,
  );

  /// Guards against corrupted or outdated saves: same balls as the level,
  /// a sane bottle count and capacity, valid history indices.
  bool isValidFor(Level level) {
    try {
      final start = level.createState();
      final state = GameState.parse(layout, capacity: level.capacity);
      if (extraBottlesAdded < 0 || extraBottlesAdded > 1) return false;
      if (state.bottleCount != start.bottleCount + extraBottlesAdded) return false;
      if (state.bottles.any((b) => b.length > level.capacity)) return false;
      String balls(GameState s) => (s.bottles.expand((b) => b).map((t) => t.code).toList()..sort()).join();
      if (balls(state) != balls(start)) return false;
      if (history.any((m) => m.from >= state.bottleCount || m.to >= state.bottleCount)) return false;
      if (moveCount < 0 || state.isSolved) return false;
      return true;
    } catch (_) {
      return false;
    }
  }

  Map<String, Object?> toJson() => {
    'status': status.name,
    'reason': failReason?.name,
    'layout': layout,
    'history': [for (final m in history) [m.from, m.to]],
    'moves': moveCount,
    'extra': extraBottlesAdded,
  };

  static LevelRun? fromJson(Object? json) {
    if (json is! Map) return null;
    try {
      final status = LevelStatus.values.byName(json['status'] as String);
      if (status == LevelStatus.completed) return null;
      final reason = json['reason'] as String?;
      return LevelRun(
        status: status,
        failReason: reason == null ? null : BoardStatus.values.byName(reason),
        layout: [for (final b in json['layout'] as List) b as String],
        history: [
          for (final m in json['history'] as List)
            Move((m as List)[0] as int, m[1] as int),
        ],
        moveCount: (json['moves'] as num).toInt(),
        extraBottlesAdded: (json['extra'] as num).toInt(),
      );
    } catch (_) {
      return null;
    }
  }
}
