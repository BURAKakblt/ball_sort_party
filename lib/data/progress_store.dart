import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Key-value persistence for the player's save.
///
/// The whole save is ONE JSON document under ONE key, so every write replaces
/// it as a unit: a write either fully lands or the previous document stays.
/// Multi-step operations are grouped with `PlayerProgress.transaction` so they
/// are written together.
abstract interface class ProgressStore {
  String? read(String key);

  /// Returns false if the platform reported a failed write.
  Future<bool> write(String key, String value);
  Future<void> remove(String key);
}

class SharedPreferencesStore implements ProgressStore {
  SharedPreferencesStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  String? read(String key) => _prefs.getString(key);

  @override
  Future<bool> write(String key, String value) => _prefs.setString(key, value);

  @override
  Future<void> remove(String key) => _prefs.remove(key);
}

/// Save-format versions and upgrades.
///
/// - Schema 1 (key `player_progress_v1`, no `schema` field): every release up
///   to fafe9d6. Fields were only ever added, so missing ones get defaults.
/// - Schema 2 (key `player_progress`): adds `schema` and `processed`
///   (idempotency ids of completed purchases).
/// - Schema 3: adds `starSigs` (layout signature each star record was earned
///   on). Older star records have none → they are kept as "legacy" (the
///   level stays cleared, coins are never paid again, a replay refreshes them).
abstract final class SaveSchema {
  static const current = 3;
  static const key = 'player_progress';
  static const legacyKey = 'player_progress_v1';

  /// Reads the newest save, upgrading a legacy one. Returns null when there
  /// is no usable save. The legacy key is never modified (kept as backup).
  static Map<String, dynamic>? load(ProgressStore store) {
    final current = _decode(store.read(key));
    if (current != null) return migrate(current);
    final legacy = _decode(store.read(legacyKey));
    return legacy == null ? null : migrate(legacy);
  }

  static Map<String, dynamic>? _decode(String? raw) {
    if (raw == null) return null;
    try {
      final v = jsonDecode(raw);
      return v is Map<String, dynamic> ? v : null;
    } on FormatException {
      return null;
    }
  }

  /// Upgrades [data] step by step to [current].
  static Map<String, dynamic> migrate(Map<String, dynamic> data) {
    final m = Map<String, dynamic>.of(data);
    var version = (m['schema'] as num?)?.toInt() ?? 1;
    if (version < 2) {
      m['processed'] = <String>[];
      version = 2;
    }
    if (version < 3) {
      m['starSigs'] = <String, String>{}; // all existing stars become legacy
      version = 3;
    }
    m['schema'] = version;
    return m;
  }
}
