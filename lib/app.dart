import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'data/player_progress.dart';
import 'screens/home/main_shell.dart';

/// Makes [PlayerProgress] available to the widget tree and rebuilds
/// dependents when it changes.
class AppScope extends InheritedNotifier<PlayerProgress> {
  const AppScope({super.key, required PlayerProgress progress, required super.child})
    : super(notifier: progress);

  static PlayerProgress of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Access without subscribing to rebuilds (for callbacks).
  static PlayerProgress read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

class BallSortPartyApp extends StatelessWidget {
  const BallSortPartyApp({super.key, required this.progress});

  final PlayerProgress progress;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      progress: progress,
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
