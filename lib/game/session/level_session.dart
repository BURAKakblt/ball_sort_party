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
      // Saves from before failIds existed get a stable one derived from the board.
      _failId = run.failId ?? (run.isFailed ? 'legacy-${run.moveCount}-${run.layout.join('.')}' : null);
    } else {
      engine = GameEngine(level.createState());
    }
  }

  final Level level;
  final PlayerProgress progress;
  late final GameEngine engine;

  LevelStatus _status = LevelStatus.playing;
  BoardStatus? _failReason;
  String? _failId;
  int _coinsAwarded = 0;

  /// Idempotency key for paid rescues of the current failure.
  String? get rescueRequestId => isFailed ? 'rescue:${level.number}:$_failId' : null;

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
    progress.saveRun(
      level.number,
      LevelRun.fromEngine(engine, _status, failReason: _failReason, failId: _failId),
    );
  }

  /// PLAYING → FAILED (deadlock or proven unsolvable).
  void fail(BoardStatus reason) {
    if (_status != LevelStatus.playing) return;
    _status = LevelStatus.failed;
    _failReason = reason;
    _failId = '${DateTime.now().microsecondsSinceEpoch}-${engine.moveCount}';
    save();
  }

  /// Paid rescue (e.g. 200 coins → extra bottle) applied atomically: the
  /// coins, the changed board and FAILED → PLAYING are saved in ONE write,
  /// and a repeated request for the same failure is never charged twice.
  ///
  /// [apply] changes the board and returns false if it can't (then nothing
  /// is charged). Only call when the result is known to be playable, or
  /// pass [recoverAfter] = false to keep FAILED until the board is analyzed.
  PurchaseResult paidRescue(int cost, bool Function() apply, {bool recoverAfter = false}) {
    final id = rescueRequestId;
    if (id == null) return PurchaseResult.notApplicable;
    return progress.transaction(() {
      final result = progress.purchase(cost, () {
        if (!apply()) return false;
        save(); // board change, still FAILED, same write as the coins
        return true;
      }, requestId: id);
      if (result == PurchaseResult.success && recoverAfter) recover();
      return result;
    });
  }

  /// FAILED → PLAYING after a successful rescue that changed the board.
  void recover() {
    if (!isFailed) return;
    _status = LevelStatus.playing;
    _failReason = null;
    _failId = null;
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
    _failId = null;
  }

  /// PLAYING → COMPLETED. Rewards are granted once per attempt.
  /// Returns the coins awarded; repeated calls grant nothing more.
  int complete(int stars) {
    if (isCompleted) return _coinsAwarded;
    _status = LevelStatus.completed;
    _failReason = null;
    _failId = null;
    _coinsAwarded = progress.completeLevel(level.number, stars);
    return _coinsAwarded;
  }

  /// Replay after a win starts a new free attempt.
  void replay() {
    _reset();
  }
}
