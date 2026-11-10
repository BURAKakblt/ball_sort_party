import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'cloud_backend.dart';
import 'cloud_models.dart';

/// Firebase error codes that are worth retrying (network / load).
const _transientCodes = {
  'unavailable',
  'deadline-exceeded',
  'aborted',
  'resource-exhausted',
  'internal',
  'cancelled',
  'network-request-failed',
  'too-many-requests',
};

Exception _classify(FirebaseException e) => _transientCodes.contains(e.code)
    ? TransientCloudError('${e.plugin}/${e.code}')
    : PermanentCloudError('${e.plugin}/${e.code}');

/// Provides Apple/Google credentials for account linking. Phase 1 has no
/// sign-in plugin integrated, so linking reports [LinkOutcome.notAvailable].
abstract interface class AccountCredentialSource {
  bool supports(AccountProvider provider);

  /// Null when the player cancelled.
  Future<AuthCredential?> obtain(AccountProvider provider);
}

class NoAccountCredentials implements AccountCredentialSource {
  const NoAccountCredentials();
  @override
  bool supports(AccountProvider provider) => false;
  @override
  Future<AuthCredential?> obtain(AccountProvider provider) async => null;
}

class FirebaseAuthService implements AuthService {
  FirebaseAuthService(this._auth, {this.credentials = const NoAccountCredentials()});

  final FirebaseAuth _auth;
  final AccountCredentialSource credentials;

  static CloudUser _map(User u) => CloudUser(
    uid: u.uid,
    isAnonymous: u.isAnonymous,
    providers: [for (final p in u.providerData) p.providerId],
  );

  @override
  CloudUser? get currentUser {
    final u = _auth.currentUser;
    return u == null ? null : _map(u);
  }

  @override
  Future<CloudUser> signInAnonymously() async {
    try {
      final existing = _auth.currentUser;
      if (existing != null) return _map(existing);
      final cred = await _auth.signInAnonymously();
      return _map(cred.user!);
    } on FirebaseException catch (e) {
      throw _classify(e);
    }
  }

  @override
  Future<LinkOutcome> link(AccountProvider provider) async {
    if (!credentials.supports(provider)) return LinkOutcome.notAvailable;
    final user = _auth.currentUser;
    if (user == null) return LinkOutcome.failed;
    final credential = await credentials.obtain(provider);
    if (credential == null) return LinkOutcome.cancelled;
    try {
      await user.linkWithCredential(credential);
      return LinkOutcome.linked;
    } on FirebaseAuthException catch (e) {
      return e.code == 'credential-already-in-use' || e.code == 'email-already-in-use'
          ? LinkOutcome.alreadyInUse
          : LinkOutcome.failed;
    }
  }
}

/// Progress lives in ONE document per player so a sync is one transaction:
///   users/{uid}/progress/main
class FirestoreCloudRepository implements CloudRepository {
  FirestoreCloudRepository(this._db, {required this.levelCount});

  final FirebaseFirestore _db;
  final int levelCount;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('users').doc(uid).collection('progress').doc('main');

  @override
  Future<CloudProgress> mergeAndSave(
    String uid,
    CloudProgress local,
    CloudProgress Function(CloudProgress local, CloudProgress remote) merge,
  ) async {
    try {
      return await _db.runTransaction((tx) async {
        final snap = await tx.get(_doc(uid));
        final remote = snap.exists
            ? CloudProgress.fromJson(snap.data(), levelCount: levelCount)
            : CloudProgress.empty;
        final merged = merge(local, remote);
        tx.set(_doc(uid), {...merged.toJson(), 'serverUpdatedAt': FieldValue.serverTimestamp()});
        return merged;
      });
    } on FirebaseException catch (e) {
      throw _classify(e);
    }
  }
}

/// Callable Cloud Functions for the server-authoritative economy.
/// The functions are NOT deployed in phase 1.
class FunctionsEconomyApi implements EconomyApi {
  FunctionsEconomyApi(this._functions);

  final FirebaseFunctions _functions;

  Future<Map<String, Object?>> _call(String name, Map<String, Object?> data) async {
    try {
      final result = await _functions.httpsCallable(name).call<Map<String, Object?>>(data);
      return result.data;
    } on FirebaseFunctionsException catch (e) {
      throw _classify(e);
    }
  }

  @override
  Future<Map<String, Object?>> claimLevelReward({required int level, required int stars, required String requestId}) =>
      _call('claimLevelReward', {'level': level, 'stars': stars, 'requestId': requestId});

  @override
  Future<Map<String, Object?>> purchaseWithCoins({required String itemId, required String requestId}) =>
      _call('purchaseWithCoins', {'itemId': itemId, 'requestId': requestId});
}
