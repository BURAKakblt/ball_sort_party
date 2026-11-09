import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/backgrounds.dart';
import '../../core/widgets/game_button.dart';
import '../../game/engine/ball_type.dart';
import '../../game/levels/level_data.dart';
import '../../game/render/ball_painter.dart';
import '../home/top_bar.dart';

/// First level that contains [type]; the ball is "collected" once reached.
int unlockLevelFor(BallType type) =>
    kLevels.firstWhere((l) => l.ballTypes.contains(type), orElse: () => kLevels.last).number;

class CollectionScreen extends StatelessWidget {
  const CollectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context);
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: TopResourceBar()),
          const SliverToBoxAdapter(
            child: ScreenTitle('Koleksiyon', icon: Icons.sports_basketball_rounded),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.85,
              ),
              delegate: SliverChildListDelegate([
                for (final type in BallType.values)
                  _BallCard(
                    type: type,
                    unlockLevel: unlockLevelFor(type),
                    unlocked: p.isUnlocked(unlockLevelFor(type)),
                  ),
              ]),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: GlassPanel(
                child: Row(
                  children: [
                    Icon(Icons.palette_rounded, color: AppColors.turquoise, size: 34),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text('Özel top desenleri ve şişe temaları', style: AppText.label),
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

class _BallCard extends StatelessWidget {
  const _BallCard({required this.type, required this.unlockLevel, required this.unlocked});

  final BallType type;
  final int unlockLevel;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                final ball = BallView(type, size: c.biggest.shortestSide * 0.82);
                return Center(
                  child: unlocked
                      ? ball
                      : Stack(
                          alignment: Alignment.center,
                          children: [
                            Opacity(
                              opacity: 0.35,
                              child: ColorFiltered(
                                colorFilter: const ColorFilter.mode(Color(0xFF2A2366), BlendMode.srcATop),
                                child: ball,
                              ),
                            ),
                            const Icon(Icons.lock_rounded, color: Colors.white, size: 34),
                          ],
                        ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Text(type.displayName, style: AppText.label.copyWith(fontSize: 15)),
          Text(
            unlocked ? 'Toplandı' : 'Bölüm $unlockLevel\'de açılır',
            style: AppText.body.copyWith(
              fontSize: 12,
              color: unlocked ? AppColors.turquoise : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
