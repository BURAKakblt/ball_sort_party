import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/confetti.dart';
import '../../core/widgets/game_button.dart';
import '../../core/widgets/game_dialog.dart';
import '../../core/widgets/resource_chips.dart';
import '../../game/levels/level.dart';
import '../../game/levels/level_data.dart';
import 'launch.dart';

/// Victory screen: confetti, animated stars and coin reward.
class LevelCompleteOverlay extends StatefulWidget {
  const LevelCompleteOverlay({
    super.key,
    required this.level,
    required this.stars,
    required this.coins,
    required this.moves,
    required this.onReplay,
  });

  final Level level;
  final int stars;
  final int coins;
  final int moves;
  final VoidCallback onReplay;

  @override
  State<LevelCompleteOverlay> createState() => _LevelCompleteOverlayState();
}

class _LevelCompleteOverlayState extends State<LevelCompleteOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Animation<double> _interval(double a, double b, [Curve curve = Curves.easeOutBack]) =>
      CurvedAnimation(parent: _c, curve: Interval(a, b, curve: curve));

  @override
  Widget build(BuildContext context) {
    final hasNext = widget.level.number < kLevels.length;
    return Stack(
      children: [
        Positioned.fill(
          child: FadeTransition(
            opacity: _interval(0, 0.2, Curves.easeOut),
            child: const ColoredBox(color: Color(0xB3070420)),
          ),
        ),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: ScaleTransition(
                scale: _interval(0, 0.35),
                child: GameCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ShaderMask(
                        shaderCallback: (r) => const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFFFF3B0), AppColors.gold],
                        ).createShader(r),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('TEBRİKLER!', style: TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            shadows: [Shadow(color: Color(0xFF7A3E00), offset: Offset(0, 3))],
                          )),
                        ),
                      ),
                      Text('Bölüm ${widget.level.number} tamamlandı', style: AppText.body),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (var i = 0; i < 3; i++)
                            Padding(
                              padding: EdgeInsets.only(bottom: i == 1 ? 14 : 0, left: 4, right: 4),
                              child: ScaleTransition(
                                scale: _interval(0.3 + i * 0.13, 0.55 + i * 0.13),
                                child: Icon(
                                  Icons.star_rounded,
                                  size: i == 1 ? 74 : 58,
                                  color: i < widget.stars ? AppColors.gold : const Color(0x44FFFFFF),
                                  shadows: i < widget.stars
                                      ? const [Shadow(color: Color(0xAAFFA928), blurRadius: 16)]
                                      : null,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text('${widget.moves} hamle  •  hedef ${widget.level.par}', style: AppText.body),
                      const SizedBox(height: 12),
                      FadeTransition(
                        opacity: _interval(0.65, 0.85, Curves.easeOut),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0x55100B3A),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CoinIcon(size: 30),
                              const SizedBox(width: 8),
                              AnimatedBuilder(
                                animation: _interval(0.65, 1, Curves.easeOut),
                                builder: (context, _) {
                                  final t = Curves.easeOut.transform(
                                    ((_c.value - 0.65) / 0.35).clamp(0.0, 1.0),
                                  );
                                  return Text(
                                    '+${(widget.coins * t).round()}',
                                    style: AppText.heading.copyWith(color: AppColors.gold),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (hasNext)
                        GameButton(
                          label: 'SONRAKİ BÖLÜM',
                          icon: Icons.arrow_forward_rounded,
                          onPressed: () => startLevel(context, widget.level.number + 1, replace: true),
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.only(bottom: 4),
                          child: Text(
                            'Tüm bölümleri bitirdin! Yeni bölümler yakında.',
                            textAlign: TextAlign.center,
                            style: AppText.label,
                          ),
                        ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: GameButton(
                              label: 'TEKRAR',
                              icon: Icons.refresh_rounded,
                              height: 50,
                              palette: ButtonPalette.purple,
                              onPressed: widget.onReplay,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GameButton(
                              label: 'MENÜ',
                              icon: Icons.home_rounded,
                              height: 50,
                              palette: ButtonPalette.navy,
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const Positioned.fill(child: ConfettiBurst()),
      ],
    );
  }
}
