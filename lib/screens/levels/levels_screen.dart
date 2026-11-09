import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/backgrounds.dart';
import '../../core/widgets/game_button.dart';
import '../../core/widgets/game_dialog.dart';
import '../../core/widgets/resource_chips.dart';
import '../../game/levels/level_data.dart';
import '../game/launch.dart';
import '../home/top_bar.dart';

class LevelsScreen extends StatelessWidget {
  const LevelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context);
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: TopResourceBar()),
          const SliverToBoxAdapter(
            child: ScreenTitle('Seviyeler', icon: Icons.grid_view_rounded),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 120,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.88,
              ),
              delegate: SliverChildBuilderDelegate(childCount: kLevels.length, (
                context,
                i,
              ) {
                final n = kLevels[i].number;
                return _LevelTile(
                  number: n,
                  stars: p.starsFor(n),
                  unlocked: p.isUnlocked(n),
                  current: n == p.unlockedLevel,
                  failed: p.isLevelFailed(n),
                  onTap: () => p.isUnlocked(n)
                      ? startLevel(context, n)
                      : showToast(context, 'Önce Bölüm ${n - 1}\'i tamamla'),
                );
              }),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: GlassPanel(
                child: Row(
                  children: [
                    Icon(
                      Icons.rocket_launch_rounded,
                      color: AppColors.turquoise,
                      size: 34,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Yeni bölümler ve dünyalar hazırlanıyor.',
                        style: AppText.label,
                      ),
                    ),
                    SoonBadge(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.number,
    required this.stars,
    required this.unlocked,
    required this.current,
    required this.onTap,
    this.failed = false,
  });

  final int number;
  final int stars;
  final bool unlocked;
  final bool current;
  final bool failed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = !unlocked
        ? ButtonPalette.disabled
        : current
        ? ButtonPalette.turquoise
        : ButtonPalette.purple;
    return Semantics(
      button: true,
      label:
          'Bölüm $number${unlocked ? '' : ', kilitli'}${failed ? ', başarısız' : ''}',
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: _tileBody(palette)),
            if (failed)
              const Positioned(
                right: -4,
                top: -6,
                child: Tooltip(
                  message: 'Başarısız — yeniden başlatmak 1 can',
                  child: HeartIcon(size: 26, broken: true),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tileBody(ButtonPalette palette) {
    return Column(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: palette.depth,
              boxShadow: [
                if (current)
                  BoxShadow(
                    color: AppColors.turquoise.withValues(alpha: 0.5),
                    blurRadius: 16,
                  ),
              ],
            ),
            padding: const EdgeInsets.only(bottom: 5),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [palette.top, palette.bottom],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: unlocked
                  ? FittedBox(
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(
                          '$number',
                          style: AppText.title.copyWith(fontSize: 34),
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.lock_rounded,
                      size: 30,
                      color: Color(0xFFC9C6E4),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 3; i++)
              Icon(
                Icons.star_rounded,
                size: 20,
                color: i < stars ? AppColors.gold : const Color(0x40FFFFFF),
              ),
          ],
        ),
      ],
    );
  }
}
