import 'package:flutter/material.dart';

import '../../app.dart';
import '../../game/levels/level_data.dart';
import 'game_screen.dart';
import 'out_of_lives_screen.dart';

/// Opens [levelNumber], or the out-of-lives screen when no lives are left.
void startLevel(BuildContext context, int levelNumber, {bool replace = false}) {
  final progress = AppScope.read(context);
  final nav = Navigator.of(context);
  final Widget page = progress.hasLives
      ? GameScreen(level: kLevels[levelNumber - 1])
      : const OutOfLivesScreen();
  replace ? nav.pushReplacement(GameRoute(page)) : nav.push(GameRoute(page));
}
