import 'dart:convert';
import 'dart:math';

import '../data/progress_store.dart';

/// Offline outbox: remembers that local progress changed and has not been
/// confirmed by the cloud yet, plus retry bookkeeping. Persisted, so changes
/// made offline (or before the app was killed) are uploaded on the next
/// successful sync. Progress itself lives in PlayerProgress; the sync
/// uploads a full snapshot merged with the cloud, so no individual moves
/// can get lost or applied twice.
class SyncOutbox {
  SyncOutbox(this._store) {
    _load();
  }

  static const key = 'cloud_sync_v1';

  final ProgressStore _store;
  bool _dirty = false;
  int _failures = 0;
  int? _lastSyncedAtMs;
  int? _nextAttemptAtMs;
  String? _lastError;

  bool get isDirty => _dirty;
  int get consecutiveFailures => _failures;
  int? get lastSyncedAtMs => _lastSyncedAtMs;
  int? get nextAttemptAtMs => _nextAttemptAtMs;
  String? get lastError => _lastError;

  /// Retry delay after [failures] consecutive failures: 5 s, 10 s, 20 s …
  /// capped at 5 minutes.
  static Duration backoff(int failures) {
    if (failures <= 0) return Duration.zero;
    final seconds = min(300, 5 * pow(2, failures - 1).toInt());
    return Duration(seconds: seconds);
  }

  void markDirty() {
    if (_dirty) return;
    _dirty = true;
    _save();
  }

  void recordSuccess(int nowMs) {
    _dirty = false;
    _failures = 0;
    _lastSyncedAtMs = nowMs;
    _nextAttemptAtMs = null;
    _lastError = null;
    _save();
  }

  /// Keeps the data dirty and schedules the next attempt.
  void recordFailure(int nowMs, String error) {
    _failures++;
    _lastError = error;
    _nextAttemptAtMs = nowMs + backoff(_failures).inMilliseconds;
    _save();
  }

  bool canAttempt(int nowMs) => _nextAttemptAtMs == null || nowMs >= _nextAttemptAtMs!;

  void _load() {
    try {
      final m = jsonDecode(_store.read(key) ?? '{}');
      if (m is! Map) return;
      _dirty = m['dirty'] == true;
      _failures = m['failures'] is num ? (m['failures'] as num).toInt() : 0;
      _lastSyncedAtMs = m['lastSyncedAt'] is num ? (m['lastSyncedAt'] as num).toInt() : null;
      _nextAttemptAtMs = m['nextAttemptAt'] is num ? (m['nextAttemptAt'] as num).toInt() : null;
      _lastError = m['lastError'] is String ? m['lastError'] as String : null;
    } on FormatException {
      // Damaged outbox: treat local data as unsynced (safe default).
      _dirty = true;
    }
  }

  void _save() {
    _store.write(
      key,
      jsonEncode({
        'dirty': _dirty,
        'failures': _failures,
        'lastSyncedAt': _lastSyncedAtMs,
        'nextAttemptAt': _nextAttemptAtMs,
        'lastError': _lastError,
      }),
    );
  }
}
