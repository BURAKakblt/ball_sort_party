import 'dart:convert';

import 'package:ball_sort_party/cloud/cloud_backend.dart';
import 'package:ball_sort_party/cloud/cloud_bootstrap.dart';
import 'package:ball_sort_party/cloud/cloud_config.dart';
import 'package:ball_sort_party/cloud/cloud_models.dart';
import 'package:ball_sort_party/cloud/sync_outbox.dart';
import 'package:ball_sort_party/cloud/sync_service.dart';
import 'package:ball_sort_party/data/economy_config.dart';
import 'package:ball_sort_party/data/player_progress.dart';
import 'package:ball_sort_party/firebase_options.dart';
import 'package:ball_sort_party/game/engine/failure_monitor.dart';
import 'package:ball_sort_party/game/levels/level_data.dart';
import 'package:ball_sort_party/game/session/level_session.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/persistence_test.dart' show MemoryStore;

/// Firestore stand-in: one JSON document per uid, transactional merge,
/// switchable outages.
class FakeCloud implements CloudRepository {
  final Map<String, String> docs = {};
  Exception? failWith;
  int writes = 0;

  Map<String, dynamic>? doc(String uid) =>
      docs[uid] == null ? null : jsonDecode(docs[uid]!) as Map<String, dynamic>;

  @override
  Future<CloudProgress> mergeAndSave(
    String uid,
    CloudProgress local,
    CloudProgress Function(CloudProgress local, CloudProgress remote) merge,
  ) async {
    final f = failWith;
    if (f != null) throw f;
    final remote = docs[uid] == null
        ? CloudProgress.empty
        : CloudProgress.fromJson(jsonDecode(docs[uid]!), levelCount: kLevels.length);
    final merged = merge(local, remote);
    docs[uid] = jsonEncode(merged.toJson());
    writes++;
    return merged;
  }
}

class FakeAuth implements AuthService {
  FakeAuth(this.uid);
  final String uid;
  CloudUser? _user;
  bool offline = false;

  @override
  CloudUser? get currentUser => _user;

  @override
  Future<CloudUser> signInAnonymously() async {
    if (offline) throw const TransientCloudError('auth/network-request-failed');
    return _user = CloudUser(uid: uid, isAnonymous: true);
  }

  @override
  Future<LinkOutcome> link(AccountProvider provider) async => LinkOutcome.notAvailable;
}

/// One "device": its own local store, progress and sync service.
class Device {
  Device(this.clock) {
    store = MemoryStore();
    progress = PlayerProgress.withStore(store, clock: clock);
    sync = SyncService(progress: progress, outbox: SyncOutbox(store), clock: clock, autoSync: false);
  }

  final DateTime Function() clock;
  late final MemoryStore store;
  late final PlayerProgress progress;
  late final SyncService sync;

  void clear(int level, int stars) => progress.completeLevel(level, stars);
}

void main() {
  late DateTime now;
  DateTime clock() => now;
  late FakeCloud cloud;

  setUp(() {
    now = DateTime(2026, 11, 10, 12);
    cloud = FakeCloud();
  });

  group('without a Firebase project', () {
    test('placeholder options → "not configured", game data untouched', () async {
      final d = Device(clock);
      d.clear(1, 3);
      final coins = d.progress.coins;
      await startCloud(d.sync, const CloudConfig(mode: CloudMode.auto, emulatorHost: 'localhost', releaseBuild: false));
      expect(d.sync.status, SyncStatus.notConfigured);
      expect(d.sync.detail, contains('bağlı değil'));
      expect(await d.sync.syncNow(force: true), SyncResult.notConfigured);
      expect(d.progress.coins, coins);
      expect(d.progress.starsFor(1), 3);
      expect(() => DefaultFirebaseOptions.currentPlatform, throwsUnsupportedError);
    });

    test('CLOUD=off keeps everything offline', () async {
      final d = Device(clock);
      await startCloud(d.sync, const CloudConfig(mode: CloudMode.off, emulatorHost: 'x', releaseBuild: false));
      expect(d.sync.status, SyncStatus.notConfigured);
      expect(d.sync.isConfigured, isFalse);
    });

    test('local changes are still recorded as unsynced (nothing pretends to be saved online)', () {
      final d = Device(clock);
      d.clear(1, 2);
      expect(d.sync.hasPendingChanges, isTrue);
      expect(d.sync.lastSyncedAt, isNull);
    });
  });

  group('offline-first sync', () {
    test('first sync uploads local progress without any economy values', () async {
      final d = Device(clock);
      d.clear(1, 3);
      d.clear(2, 2);
      expect(await d.sync.attach(auth: FakeAuth('u1'), repo: cloud), SyncResult.synced);
      expect(d.sync.status, SyncStatus.idle);
      expect(d.sync.hasPendingChanges, isFalse);
      final doc = cloud.doc('u1')!;
      expect(doc['unlockedLevel'], 3);
      expect((doc['levels'] as Map).keys, containsAll(['1', '2']));
      for (final forbidden in ['coins', 'lives', 'shuffles', 'extraBottles', 'undos', 'processed', 'giftAt']) {
        expect(doc.containsKey(forbidden), isFalse, reason: '$forbidden is server-authoritative');
      }
    });

    test('offline: progress stays local, is retried with backoff, then uploaded', () async {
      final d = Device(clock);
      cloud.failWith = const TransientCloudError('firestore/unavailable');
      d.clear(1, 3);
      expect(await d.sync.attach(auth: FakeAuth('u1'), repo: cloud), SyncResult.offline);
      expect(d.sync.status, SyncStatus.offline);
      expect(d.sync.hasPendingChanges, isTrue);
      expect(d.progress.starsFor(1), 3, reason: 'nothing lost locally');
      expect(await d.sync.syncNow(), SyncResult.deferred, reason: 'backoff');
      now = now.add(SyncOutbox.backoff(1));
      cloud.failWith = null;
      expect(await d.sync.syncNow(), SyncResult.synced);
      expect(cloud.doc('u1')!['unlockedLevel'], 2);
      expect(d.sync.hasPendingChanges, isFalse);
    });

    test('sign-in failing offline is treated the same way', () async {
      final d = Device(clock);
      final auth = FakeAuth('u1')..offline = true;
      expect(await d.sync.attach(auth: auth, repo: cloud), SyncResult.offline);
      expect(cloud.writes, 0);
    });

    test('permanent errors are reported, data kept, retried later', () async {
      final d = Device(clock);
      d.clear(1, 1);
      cloud.failWith = const PermanentCloudError('firestore/permission-denied');
      expect(await d.sync.attach(auth: FakeAuth('u1'), repo: cloud), SyncResult.failed);
      expect(d.sync.status, SyncStatus.error);
      expect(d.progress.starsFor(1), 1);
      expect(d.sync.hasPendingChanges, isTrue);
    });

    test('unsynced state survives an app restart', () async {
      final d = Device(clock);
      cloud.failWith = const TransientCloudError('offline');
      d.clear(1, 3);
      await d.sync.attach(auth: FakeAuth('u1'), repo: cloud);
      final restarted = SyncOutbox(d.store);
      expect(restarted.isDirty, isTrue);
      expect(restarted.consecutiveFailures, 1);
    });

    test('backoff grows and is capped', () {
      expect(SyncOutbox.backoff(1), const Duration(seconds: 5));
      expect(SyncOutbox.backoff(3), const Duration(seconds: 20));
      expect(SyncOutbox.backoff(30), const Duration(minutes: 5));
    });
  });

  group('two devices, same account', () {
    test('progress is combined and never goes backwards on either device', () async {
      final a = Device(clock), b = Device(clock);
      for (var n = 1; n <= 5; n++) {
        a.clear(n, 1);
      }
      b.clear(1, 1);
      b.clear(2, 3); // better result on B
      await a.sync.attach(auth: FakeAuth('u'), repo: cloud);
      await b.sync.attach(auth: FakeAuth('u'), repo: cloud);
      await a.sync.syncNow(force: true);
      for (final d in [a, b]) {
        expect(d.progress.unlockedLevel, 6);
        expect(d.progress.starsFor(2), 3);
        expect(d.progress.starsFor(5), 1);
      }
    });

    test('a stale device can never lower cloud or local progress', () async {
      final a = Device(clock), b = Device(clock);
      for (var n = 1; n <= 8; n++) {
        a.clear(n, 3);
      }
      await a.sync.attach(auth: FakeAuth('u'), repo: cloud);
      await b.sync.attach(auth: FakeAuth('u'), repo: cloud); // B had nothing
      expect(b.progress.unlockedLevel, 9);
      expect(cloud.doc('u')!['unlockedLevel'], 9);
      await a.sync.syncNow(force: true);
      expect(a.progress.unlockedLevel, 9);
    });

    test('coins are NOT shared or re-paid: levels cleared elsewhere pay nothing', () async {
      final a = Device(clock), b = Device(clock);
      a.clear(1, 3);
      await a.sync.attach(auth: FakeAuth('u'), repo: cloud);
      final bCoins = b.progress.coins;
      await b.sync.attach(auth: FakeAuth('u'), repo: cloud);
      expect(b.progress.isCleared(1), isTrue);
      expect(b.progress.coins, bCoins, reason: 'cloud sync never grants coins');
      expect(b.progress.completeLevel(1, 3), 0, reason: 'first-clear reward already claimed');
      expect(a.progress.coins, EconomyConfig.startingCoins + EconomyConfig.levelReward(1, kLevels.length));
    });

    test('a FAILED attempt on one device is not erased by an older attempt on another', () async {
      final a = Device(clock), b = Device(clock);
      // B saved a PLAYING attempt once (rev 1).
      final sb = LevelSession(kLevels.first, b.progress);
      final mb = sb.engine.state.validMoves().first;
      sb.engine.move(mb.from, mb.to);
      sb.save();
      // A played further and FAILED (rev 2).
      final sa = LevelSession(kLevels.first, a.progress);
      final ma = sa.engine.state.validMoves().first;
      sa.engine.move(ma.from, ma.to);
      sa.save();
      sa.fail(BoardStatus.deadlock);
      await a.sync.attach(auth: FakeAuth('u'), repo: cloud);
      await b.sync.attach(auth: FakeAuth('u'), repo: cloud);
      expect(b.progress.isLevelFailed(1), isTrue, reason: 'no free restart by switching device');
      expect(LevelSession(kLevels.first, b.progress).isFailed, isTrue);
    });

    test('an attempt finished on another device is removed', () async {
      final a = Device(clock), b = Device(clock);
      final s = LevelSession(kLevels.first, a.progress);
      final m = s.engine.state.validMoves().first;
      s.engine.move(m.from, m.to);
      s.save();
      await a.sync.attach(auth: FakeAuth('u'), repo: cloud);
      now = now.add(const Duration(minutes: 5));
      b.clear(1, 3);
      await b.sync.attach(auth: FakeAuth('u'), repo: cloud);
      await a.sync.syncNow(force: true);
      expect(a.progress.runFor(1), isNull);
      expect(a.progress.starsFor(1), 3);
    });

    test('applying cloud data does not mark the device dirty again (no sync loop)', () async {
      final a = Device(clock), b = Device(clock);
      a.clear(1, 3);
      await a.sync.attach(auth: FakeAuth('u'), repo: cloud);
      await b.sync.attach(auth: FakeAuth('u'), repo: cloud);
      expect(b.sync.hasPendingChanges, isFalse);
    });

    test('malformed cloud documents are ignored, local progress kept', () async {
      final d = Device(clock);
      d.clear(1, 2);
      cloud.docs['u'] = jsonEncode({'unlockedLevel': -4, 'levels': 'oops', 'runs': {'1': 5}, 'coins': 999999});
      expect(await d.sync.attach(auth: FakeAuth('u'), repo: cloud), SyncResult.synced);
      expect(d.progress.starsFor(1), 2);
      expect(d.progress.unlockedLevel, 2);
      expect(d.progress.coins, lessThan(999999), reason: 'cloud economy fields are never read');
    });
  });

  group('App Check modes', () {
    test('debug builds and the emulator use debug providers', () {
      const debug = CloudConfig(mode: CloudMode.auto, emulatorHost: 'h', releaseBuild: false);
      expect(debug.appCheck.isDebug, isTrue);
      expect(debug.appCheck.android, isA<AndroidDebugProvider>());
      const emulatorRelease = CloudConfig(mode: CloudMode.emulator, emulatorHost: 'h', releaseBuild: true);
      expect(emulatorRelease.appCheck.isDebug, isTrue);
    });

    test('release builds use Play Integrity and App Attest', () {
      const prod = CloudConfig(mode: CloudMode.auto, emulatorHost: 'h', releaseBuild: true);
      expect(prod.appCheck.isDebug, isFalse);
      expect(prod.appCheck.android, isA<AndroidPlayIntegrityProvider>());
      expect(prod.appCheck.apple, isA<AppleAppAttestWithDeviceCheckFallbackProvider>());
    });
  });
}
