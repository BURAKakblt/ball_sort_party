import 'package:flutter/material.dart';

import 'audio/audio_service.dart';
import 'cloud/sync_service.dart';
import 'core/theme/app_theme.dart';
import 'data/player_progress.dart';
import 'screens/home/main_shell.dart';
import 'services/rewarded_ad_service.dart';

/// Makes [PlayerProgress] available to the widget tree and rebuilds
/// dependents when it changes.
class AppScope extends InheritedNotifier<PlayerProgress> {
  AppScope({
    super.key,
    required PlayerProgress progress,
    AudioService? audio,
    this.ads = const UnavailableRewardedAdService(),
    this.sync,
    required super.child,
  }) : audio = audio ?? AudioService.disabled(),
       super(notifier: progress);

  final AudioService audio;
  final RewardedAdService ads;

  /// Cloud save (null in tests / when not created).
  final SyncService? sync;

  static PlayerProgress of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Access without subscribing to rebuilds (for callbacks).
  static PlayerProgress read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AudioService audioOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()?.audio ?? _silent;

  static SyncService? syncOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()?.sync;

  static RewardedAdService adsOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()?.ads ??
      const UnavailableRewardedAdService();

  static final _silent = AudioService.disabled();
}

class BallSortPartyApp extends StatelessWidget {
  const BallSortPartyApp({super.key, required this.progress, this.audio, this.sync});

  final PlayerProgress progress;
  final AudioService? audio;
  final SyncService? sync;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      progress: progress,
      audio: audio,
      sync: sync,
      child: MaterialApp(
        title: 'Ball Sort Party',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const MainShell(),
      ),
    );
  }
}

/// Fade + slight scale page transition used across the game.
class GameRoute<T> extends PageRouteBuilder<T> {
  GameRoute(Widget page)
    : super(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (_, _, _) => page,
        transitionsBuilder: (_, animation, _, child) {
          final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween(begin: 0.96, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      );
}
