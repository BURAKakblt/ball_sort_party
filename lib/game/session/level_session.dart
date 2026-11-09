import '../../data/player_progress.dart';
import '../engine/failure_monitor.dart';
import '../engine/game_engine.dart';
import '../levels/level.dart';
import 'level_run.dart';

/// Result of asking to restart the level.
enum RestartResult {
  /// Free restart during normal play.
  restartedFree,

  /// FAILED level restarted; exactly one life was spent.
  restartedPaidLife,

  /// FAILED level and no lives: nothing changed.
  noLives,
}

/// State machine for one level attempt: PLAYING → FAILED → (rescue) PLAYING,
/// PLAYING → COMPLETED. Every transition is persisted via [PlayerProgress],
/// so FAILED survives leaving the level, switching levels and app restarts.
///
/// Rules:
/// - Starting / resuming a level is free; closing the app never costs a life.
/// - Manual restart is free while PLAYING.
/// - Restarting while FAILED costs exactly one life (if any).
/// - A successful rescue (undo, coins, ad) or a win clears FAILED.
class LevelSession {
  LevelSession(this.level, this.progress) {
    final run = progress.runFor(level.number);
    if (run != null && run.isValidFor(level)) {
      engine = run.toEngine(level);
      _status = run.status;
      _failReason = run.failReason;
    } else {
      engine = GameEngine(level.createState());
    }
  }

  final Level level;
  final PlayerProgress progress;
  late final GameEngine engine;

  LevelStatus _status = LevelStatus.playing;
  BoardStatus? _failReason;
  int _coinsAwarded = 0;

  LevelStatus get status => _status;
  bool get isFailed => _status == LevelStatus.failed;
  bool get isCompleted => _status == LevelStatus.completed;
  BoardStatus? get failReason => _failReason;

  /// Whether this attempt was restored with progress (moves played).
  bool get hasProgress => engine.moveCount > 0;

  /// Persists the current board (after moves, undo, power-ups).
  void save() {
    if (isCompleted) return;
    if (engine.moveCount == 0 && engine.extraBottlesAdded == 0 && !isFailed) {
      progress.discardRun(level.number); // nothing worth resuming
      return;
    }
    progress.saveRun(level.number, LevelRun.fromEngine(engine, _status, failReason: _failReason));
  }

  /// PLAYING → FAILED (deadlock or proven unsolvable).
  void fail(BoardStatus reason) {
    if (_status != LevelStatus.playing) return;
    _status = LevelStatus.failed;
    _failReason = reason;
    save();
  }

  /// FAILED → PLAYING after a successful rescue that changed the board.
  void recover() {
    if (!isFailed) return;
    _status = LevelStatus.playing;
    _failReason = null;
    progress.recoverLevel(level.number, LevelRun.fromEngine(engine, _status));
  }

  /// Restart request from the UI. Resets the engine on success.
  RestartResult restart() {
    if (isFailed) {
      if (!progress.payRetry(level.number)) return RestartResult.noLives;
      _reset();
      return RestartResult.restartedPaidLife;
    }
    progress.discardRun(level.number);
    _reset();
    return RestartResult.restartedFree;
  }

  void _reset() {
    engine.reset();
    _status = LevelStatus.playing;
    _failReason = null;
  }

  /// PLAYING → COMPLETED. Rewards are granted once per attempt.
  /// Returns the coins awarded; repeated calls grant nothing more.
  int complete(int stars) {
    if (isCompleted) return _coinsAwarded;
    _status = LevelStatus.completed;
    _failReason = null;
    _coinsAwarded = progress.completeLevel(level.number, stars);
    return _coinsAwarded;
  }

  /// Replay after a win starts a new free attempt.
  void replay() {
    _reset();
  }
}
