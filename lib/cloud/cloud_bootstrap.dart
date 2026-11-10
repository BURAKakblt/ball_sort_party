import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import '../game/levels/level_data.dart';
import 'cloud_config.dart';
import 'firebase_backend.dart';
import 'sync_service.dart';

/// Reads the Firebase options; null while the project isn't connected
/// (lib/firebase_options.dart is still the placeholder).
typedef OptionsReader = FirebaseOptions Function();

/// Starts the cloud layer in the background. NEVER throws and never blocks
/// the game: any problem leaves [sync] in "not configured" and the game
/// keeps working offline.
Future<void> startCloud(
  SyncService sync,
  CloudConfig config, {
  OptionsReader readOptions = _defaultOptions,
}) async {
  if (config.mode == CloudMode.off) {
    sync.markNotConfigured('Bulut kayıt bu derlemede kapalı');
    return;
  }
  final FirebaseOptions options;
  if (config.mode == CloudMode.emulator) {
    options = CloudConfig.demoOptions; // local emulators only, no real project
  } else {
    try {
      options = readOptions();
    } on UnsupportedError {
      sync.markNotConfigured('Firebase projesi bağlı değil — ilerleme yalnızca bu cihazda');
      return;
    }
  }
  sync.markConnecting();
  try {
    await Firebase.initializeApp(options: options);
    if (config.mode != CloudMode.emulator) {
      // Emulators don't enforce App Check; real projects always get it.
      final plan = config.appCheck;
      await FirebaseAppCheck.instance.activate(providerAndroid: plan.android, providerApple: plan.apple);
    } else {
      await FirebaseAuth.instance.useAuthEmulator(config.emulatorHost, CloudConfig.authPort);
      FirebaseFirestore.instance.useFirestoreEmulator(config.emulatorHost, CloudConfig.firestorePort);
      FirebaseFunctions.instance.useFunctionsEmulator(config.emulatorHost, CloudConfig.functionsPort);
    }
    await sync.attach(
      auth: FirebaseAuthService(FirebaseAuth.instance),
      repo: FirestoreCloudRepository(FirebaseFirestore.instance, levelCount: kLevels.length),
    );
  } catch (e) {
    debugPrint('Cloud start failed: $e');
    sync.markNotConfigured('Firebase başlatılamadı — ilerleme yalnızca bu cihazda');
  }
}

FirebaseOptions _defaultOptions() => DefaultFirebaseOptions.currentPlatform;
