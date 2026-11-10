import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// How the app talks to Firebase. Chosen at build time:
///   flutter run --dart-define=CLOUD=emulator   (local Emulator Suite)
///   flutter run --dart-define=CLOUD=off        (force offline-only)
///   default (CLOUD=auto)                       (real project if configured)
enum CloudMode { auto, emulator, off }

class CloudConfig {
  const CloudConfig({required this.mode, required this.emulatorHost, required this.releaseBuild});

  factory CloudConfig.fromEnvironment() {
    const raw = String.fromEnvironment('CLOUD', defaultValue: 'auto');
    const host = String.fromEnvironment('CLOUD_EMULATOR_HOST');
    final mode = CloudMode.values.firstWhere((m) => m.name == raw, orElse: () => CloudMode.auto);
    return CloudConfig(
      mode: mode,
      // The Android emulator reaches the host machine via 10.0.2.2.
      emulatorHost: host.isNotEmpty
          ? host
          : (defaultTargetPlatform == TargetPlatform.android ? '10.0.2.2' : 'localhost'),
      releaseBuild: kReleaseMode,
    );
  }

  final CloudMode mode;
  final String emulatorHost;
  final bool releaseBuild;

  /// Local-only project for the Emulator Suite. The `demo-` prefix tells
  /// Firebase tools it is not a real project: these are NOT credentials and
  /// can't reach any Google server.
  static const demoProjectId = 'demo-ball-sort-party';
  static const demoOptions = FirebaseOptions(
    apiKey: 'demo-api-key',
    appId: '1:000000000000:android:0000000000000000',
    messagingSenderId: '000000000000',
    projectId: demoProjectId,
  );

  /// Local Emulator Suite ports (must match firebase.json).
  static const authPort = 9099;
  static const firestorePort = 8080;
  static const functionsPort = 5001;

  /// App Check providers, kept strictly separate:
  /// - debug builds and the emulator → debug providers (register the debug
  ///   token printed in the device log under App Check → Manage debug tokens);
  /// - release builds → Play Integrity (Android) and App Attest with
  ///   DeviceCheck fallback (iOS).
  AppCheckPlan get appCheck => (releaseBuild && mode != CloudMode.emulator)
      ? const AppCheckPlan(
          android: AndroidPlayIntegrityProvider(),
          apple: AppleAppAttestWithDeviceCheckFallbackProvider(),
          isDebug: false,
        )
      : const AppCheckPlan(android: AndroidDebugProvider(), apple: AppleDebugProvider(), isDebug: true);
}

class AppCheckPlan {
  const AppCheckPlan({required this.android, required this.apple, required this.isDebug});

  final AndroidAppCheckProvider android;
  final AppleAppCheckProvider apple;
  final bool isDebug;
}
