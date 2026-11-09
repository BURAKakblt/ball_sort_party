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
    this.failId,
    this.levelSig,
  });

  /// Signature of a level's starting layout. Saved with every attempt so an
  /// attempt never resumes on a level whose layout changed in an update.
  static String signatureOf(List<String> layout) => layout.join('|');

  factory LevelRun.fromEngine(
    GameEngine engine,
    LevelStatus status, {
    BoardStatus? failReason,
    String? failId,
  }) {
    final failed = status == LevelStatus.failed;
    return LevelRun(
      status: status,
      layout: engine.state.toLayout(),
      history: engine.history,
      moveCount: engine.moveCount,
      extraBottlesAdded: engine.extraBottlesAdded,
      failReason: failed ? failReason : null,
      failId: failed ? failId : null,
      levelSig: signatureOf(engine.initialState.toLayout()),
    );
  }

  final LevelStatus status;
  final List<String> layout;
  final List<Move> history;
  final int moveCount;
  final int extraBottlesAdded;

  /// Why the attempt failed (deadlock / unsolvable), when FAILED.
  final BoardStatus? failReason;

  /// Unique id of this failure; rescue purchases use it for idempotency.
  final String? failId;

  /// [signatureOf] the level layout this attempt started from (null in saves
  /// written before this field existed).
  final String? levelSig;

  bool get isFailed => status == LevelStatus.failed;

  LevelRun copyWith({LevelStatus? status, BoardStatus? failReason}) => LevelRun(
    status: status ?? this.status,
    layout: layout,
    history: history,
    moveCount: moveCount,
    extraBottlesAdded: extraBottlesAdded,
    failReason: failReason ?? this.failReason,
    failId: failId,
    levelSig: levelSig,
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
      if (levelSig != null) return levelSig == signatureOf(level.layout);
      // Older save without a signature: accept only if undoing its history
      // leads back exactly to this level's start (proves same layout).
      var back = state;
      for (final m in history.reversed) {
        if (back.isEmpty(m.to)) return false;
        back = back.transferUnchecked(m.to, m.from);
      }
      final expected = [...level.layout, for (var i = 0; i < extraBottlesAdded; i++) ''];
      return back.toLayout().join('|') == expected.join('|');
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
    if (failId != null) 'failId': failId,
    if (levelSig != null) 'sig': levelSig,
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
        failId: json['failId'] as String?,
        levelSig: json['sig'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}
