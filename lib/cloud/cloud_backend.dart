import 'cloud_models.dart';

/// Signed-in player identity (anonymous until an account is linked).
class CloudUser {
  const CloudUser({required this.uid, required this.isAnonymous, this.providers = const []});

  final String uid;
  final bool isAnonymous;

  /// Linked sign-in providers, e.g. `apple.com`, `google.com`.
  final List<String> providers;
}

enum AccountProvider { apple, google }

enum LinkOutcome {
  linked,

  /// The sign-in plugin for this provider isn't integrated yet.
  notAvailable,
  cancelled,

  /// That Apple/Google account already belongs to another player.
  alreadyInUse,
  failed,
}

/// Player identity. Implementations: Firebase Auth, fakes in tests.
abstract interface class AuthService {
  CloudUser? get currentUser;

  /// Creates (or restores) the anonymous player id for this install.
  /// NOTE: an anonymous id lives on this device only. Without a linked
  /// Apple/Google account, progress can NOT be restored on a new device
  /// or after reinstalling.
  Future<CloudUser> signInAnonymously();

  /// Upgrades the anonymous player to a permanent account (same uid, so
  /// the cloud save is kept).
  Future<LinkOutcome> link(AccountProvider provider);
}

/// Error from the backend that is worth retrying later (offline, timeout,
/// service unavailable).
class TransientCloudError implements Exception {
  const TransientCloudError(this.message);
  final String message;
  @override
  String toString() => 'TransientCloudError: $message';
}

/// Error that retrying won't fix (permission denied, invalid data, …).
class PermanentCloudError implements Exception {
  const PermanentCloudError(this.message);
  final String message;
  @override
  String toString() => 'PermanentCloudError: $message';
}

/// Storage for the player's synced progress.
abstract interface class CloudRepository {
  /// Atomically reads the cloud copy, merges it with [local] using [merge]
  /// and writes the result back (a transaction, so two devices syncing at
  /// once can't lose each other's progress). Returns the merged progress.
  ///
  /// Throws [TransientCloudError] / [PermanentCloudError].
  Future<CloudProgress> mergeAndSave(
    String uid,
    CloudProgress local,
    CloudProgress Function(CloudProgress local, CloudProgress remote) merge,
  );
}

/// Server-authoritative economy (Cloud Functions). The client may only
/// REQUEST changes; the server validates and applies them.
///
/// Phase 1: contract only — the functions are not written/deployed yet, so
/// the app keeps its local economy (see docs/cloud/README.md).
abstract interface class EconomyApi {
  /// Asks the server to grant the first-clear reward for [level].
  /// [requestId] makes retries idempotent.
  Future<Map<String, Object?>> claimLevelReward({required int level, required int stars, required String requestId});

  /// Asks the server to perform a coin purchase of [itemId].
  Future<Map<String, Object?>> purchaseWithCoins({required String itemId, required String requestId});
}
