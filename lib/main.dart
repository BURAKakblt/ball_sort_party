import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'audio/audio_service.dart';
import 'audio/audioplayers_backend.dart';
import 'data/player_progress.dart';

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
  runApp(BallSortPartyApp(progress: progress, audio: audio));
}
