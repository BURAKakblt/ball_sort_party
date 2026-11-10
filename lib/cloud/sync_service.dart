import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/player_progress.dart';
import 'cloud_backend.dart';
import 'progress_merge.dart';
import 'sync_outbox.dart';

enum SyncStatus {
  /// No Firebase project connected: the game is offline-only. Never shown
  /// as "synced".
  notConfigured,

  /// Firebase is starting / signing in.
  connecting,

  /// Up to date with the cloud (as of [SyncService.lastSyncedAt]).
  idle,
  syncing,

  /// Last attempt failed for a temporary reason; changes are kept locally
  /// and retried later.
  offline,

  /// Last attempt failed for a reason retrying won't fix.
  error,
}

enum SyncResult { synced, notConfigured, deferred, offline, failed }

/// Keeps PlayerProgress and the cloud copy in step.
///
/// Offline-first: the game always reads and writes local data; sync runs in
/// the background, never blocks play, and only ever moves progress forward
/// (see [ProgressMerge]). Economy values are never uploaded or downloaded.
class SyncService extends ChangeNotifier {
  SyncService({
    required this.progress,
    required this.outbox,
    DateTime Function()? clock,
    this.autoSync = true,
    this.debounce = const Duration(seconds: 3),
  }) : _now = clock ?? DateTime.now {
    progress.addListener(_onLocalChange);
  }

  final PlayerProgress progress;
  final SyncOutbox outbox;
  final DateTime Function() _now;

  /// Sync automatically after local changes (off in tests).
  final bool autoSync;
  final Duration debounce;

  AuthService? _auth;
  CloudRepository? _repo;
  SyncStatus _status = SyncStatus.notConfigured;
  String? _detail = 'Firebase projesi bağlı değil';
  bool _applying = false;
  bool _running = false;
  Timer? _timer;

  SyncStatus get status => _status;

  /// Human-readable reason for the current status (Turkish, for the UI).
  String? get detail => _detail;
  CloudUser? get user => _auth?.currentUser;
  bool get isConfigured => _repo != null;
  bool get hasPendingChanges => outbox.isDirty;
  DateTime? get lastSyncedAt =>
      outbox.lastSyncedAtMs == null ? null : DateTime.fromMillisecondsSinceEpoch(outbox.lastSyncedAtMs!);

  void _set(SyncStatus s, [String? detail]) {
    _status = s;
    _detail = detail;
    notifyListeners();
  }

  /// Firebase is unavailable (not configured, init failed, disabled).
  void markNotConfigured(String reason) {
    _auth = null;
    _repo = null;
    _set(SyncStatus.notConfigured, reason);
  }

  void markConnecting() => _set(SyncStatus.connecting, 'Bağlanıyor…');

  /// Connects a working backend and runs a first sync.
  Future<SyncResult> attach({required AuthService auth, required CloudRepository repo}) {
    _auth = auth;
    _repo = repo;
    return syncNow(force: true);
  }

  void _onLocalChange() {
    if (_applying) return; // our own cloud→local apply
    outbox.markDirty();
    if (!autoSync || _repo == null) return;
    _timer?.cancel();
    _timer = Timer(debounce, () => syncNow());
  }

  /// Uploads local progress merged with the cloud copy, then applies the
  /// merged result locally. Safe to call any time; never throws.
  Future<SyncResult> syncNow({bool force = false}) async {
    final repo = _repo, auth = _auth;
    if (repo == null || auth == null) return SyncResult.notConfigured;
    final now = _now().millisecondsSinceEpoch;
    if (!force && !outbox.canAttempt(now)) return SyncResult.deferred;
    if (_running) return SyncResult.deferred;
    _running = true;
    _set(SyncStatus.syncing, 'Eşitleniyor…');
    try {
      final user = auth.currentUser ?? await auth.signInAnonymously();
      final merge = ProgressMerge(PlayerProgress.currentLevelSigs);
      final merged = await repo.mergeAndSave(user.uid, progress.exportCloudProgress(), merge.merge);
      _applying = true;
      try {
        progress.applyCloudProgress(merged);
      } finally {
        _applying = false;
      }
      outbox.recordSuccess(_now().millisecondsSinceEpoch);
      _set(SyncStatus.idle, null);
      return SyncResult.synced;
    } on TransientCloudError catch (e) {
      outbox.recordFailure(_now().millisecondsSinceEpoch, e.message);
      _set(SyncStatus.offline, 'Çevrimdışı — ilerleme cihazda saklanıyor, sonra tekrar denenecek');
      _scheduleRetry();
      return SyncResult.offline;
    } catch (e) {
      outbox.recordFailure(_now().millisecondsSinceEpoch, '$e');
      _set(SyncStatus.error, 'Eşitleme hatası — ilerleme cihazda güvende');
      _scheduleRetry();
      return SyncResult.failed;
    } finally {
      _running = false;
    }
  }

  void _scheduleRetry() {
    if (!autoSync) return;
    _timer?.cancel();
    _timer = Timer(SyncOutbox.backoff(outbox.consecutiveFailures), () => syncNow());
  }

  @override
  void dispose() {
    _timer?.cancel();
    progress.removeListener(_onLocalChange);
    super.dispose();
  }
}
