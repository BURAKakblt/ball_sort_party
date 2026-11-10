import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/game_button.dart';
import '../../core/widgets/resource_chips.dart';
import '../game/out_of_lives_screen.dart';
import '../settings/settings_screen.dart';

/// Lives, coins and settings, shown at the top of menu screens.
class TopResourceBar extends StatelessWidget {
  const TopResourceBar({super.key, this.onOpenShop});

  final VoidCallback? onOpenShop;

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Row(
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  LivesChip(
                    onPlus: p.lives < kMaxLives
                        ? () => Navigator.of(context).push(GameRoute(const OutOfLivesScreen()))
                        : null,
                  ),
                  const SizedBox(width: 8),
                  CoinsChip(onPlus: onOpenShop),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          RoundIconButton(
            icon: Icons.settings_rounded,
            size: AppSizes.headerButton,
            palette: ButtonPalette.navy,
            tooltip: 'Ayarlar',
            onPressed: () => Navigator.of(context).push(GameRoute(const SettingsScreen())),
          ),
        ],
      ),
    );
  }
}

/// Title row for tab screens.
class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.text, {super.key, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: AppColors.turquoise, size: 28),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                shadows: [Shadow(color: Color(0x66000000), offset: Offset(0, 2), blurRadius: 3)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
