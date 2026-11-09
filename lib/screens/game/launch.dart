import 'package:flutter/material.dart';

import '../../app.dart';
import '../../game/levels/level_data.dart';
import 'game_screen.dart';
import 'out_of_lives_screen.dart';

/// Opens [levelNumber], or the out-of-lives screen when no lives are left.
/// A saved attempt (PLAYING or FAILED) can always be reopened: a FAILED one
/// shows the rescue screen, where restarting still needs a life.
void startLevel(BuildContext context, int levelNumber, {bool replace = false}) {
  final progress = AppScope.read(context);
  final nav = Navigator.of(context);
  final Widget page = progress.hasLives || progress.runFor(levelNumber) != null
      ? GameScreen(level: kLevels[levelNumber - 1])
      : const OutOfLivesScreen();
  replace ? nav.pushReplacement(GameRoute(page)) : nav.push(GameRoute(page));
}
