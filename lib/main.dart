import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'audio/audio_service.dart';
import 'audio/audioplayers_backend.dart';
import 'cloud/cloud_bootstrap.dart';
import 'cloud/cloud_config.dart';
import 'cloud/sync_outbox.dart';
import 'cloud/sync_service.dart';
import 'data/player_progress.dart';
import 'data/progress_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );
  final progress = await PlayerProgress.load();
  final audio = AudioService(AudioplayersBackend(), progress);
  // Audio failures are logged and never block startup.
  await audio.init();
  final sync = SyncService(
    progress: progress,
    outbox: SyncOutbox(SharedPreferencesStore(await SharedPreferences.getInstance())),
  );
  runApp(BallSortPartyApp(progress: progress, audio: audio, sync: sync));
  // Offline-first: the game is already running; the cloud connects in the
  // background (or reports "not configured") and never blocks play.
  unawaited(startCloud(sync, CloudConfig.fromEnvironment()));
}
