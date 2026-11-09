import 'dart:async';

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/backgrounds.dart';
import '../../core/widgets/game_button.dart';
import '../../core/widgets/game_dialog.dart';
import '../../core/widgets/resource_chips.dart';
import '../../data/player_progress.dart';

/// Shown when the player has no lives (or taps "+" on the lives chip).
class OutOfLivesScreen extends StatefulWidget {
  const OutOfLivesScreen({super.key});

  @override
  State<OutOfLivesScreen> createState() => _OutOfLivesScreenState();
}

class _OutOfLivesScreenState extends State<OutOfLivesScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      AppScope.read(context).tick();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _refill() {
    final p = AppScope.read(context);
    if (p.buyLifeRefill()) {
      showToast(context, 'Canların doldu!');
      Navigator.of(context).pop();
    } else {
      showToast(context, 'Yeterli altının yok');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context);
    final next = p.timeToNextLife;
    final empty = p.lives == 0;
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: RoundIconButton(
                            icon: Icons.close_rounded,
                            size: 46,
                            palette: ButtonPalette.navy,
                            tooltip: 'Kapat',
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ),
                      const Spacer(),
                      HeartIcon(size: 140, broken: empty),
                      const SizedBox(height: 8),
                      Text(
                        empty ? 'CANIN BİTTİ!' : 'CANLAR',
                        style: AppText.title,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        empty
                            ? 'Biraz dinlen, canların zamanla yenilenir.'
                            : '${p.lives}/${PlayerProgress.maxLives} can',
                        textAlign: TextAlign.center,
                        style: AppText.body,
                      ),
                      const SizedBox(height: 22),
                      GlassPanel(
                        child: Column(
                          children: [
                            const Text('SONRAKİ CAN', style: AppText.label),
                            const SizedBox(height: 6),
                            Text(
                              next == null ? 'DOLU' : formatDuration(next),
                              style: AppText.title.copyWith(color: AppColors.turquoise),
                            ),
                            Text(
                              'Her ${PlayerProgress.lifeRegen.inMinutes} dakikada 1 can',
                              style: AppText.body.copyWith(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(height: 20),
                      GameButton(
                        label: 'DOLDUR  •  ${Prices.refillLives}',
                        icon: Icons.favorite_rounded,
                        palette: ButtonPalette.gold,
                        onPressed: p.lives < PlayerProgress.maxLives ? _refill : null,
                      ),
                      const SizedBox(height: 14),
                      // Placeholder: rewarded ads are not integrated yet.
                      const GameButton(
                        label: 'REKLAM İZLE  +1 CAN',
                        icon: Icons.ondemand_video_rounded,
                        palette: ButtonPalette.purple,
                        badge: 'YAKINDA',
                      ),
                      const SizedBox(height: 14),
                      GameButton(
                        label: 'ANA MENÜ',
                        icon: Icons.home_rounded,
                        palette: ButtonPalette.navy,
                        onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
