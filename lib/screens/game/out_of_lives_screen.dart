import 'dart:async';

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/backgrounds.dart';
import '../../core/widgets/game_button.dart';
import '../../core/widgets/game_dialog.dart';
import '../../core/widgets/resource_chips.dart';
import '../../audio/audio_service.dart';
import '../../data/economy_config.dart';
import '../../data/player_progress.dart';
import '../../services/rewarded_ad_service.dart';

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

  void _buy(bool Function() purchase, String done) {
    final audio = AppScope.audioOf(context);
    if (purchase()) {
      audio.play(Sfx.life);
      showToast(context, done);
      Navigator.of(context).pop();
    } else {
      audio.play(Sfx.invalid);
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
                            size: AppSizes.headerButton,
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
                      Text('Beklersen canların ücretsiz yenilenir.', style: AppText.body.copyWith(fontSize: 13)),
                      const SizedBox(height: 12),
                      GameButton(
                        label: '+1 CAN  •  ${EconomyConfig.oneLifePrice}',
                        icon: Icons.favorite_rounded,
                        palette: ButtonPalette.gold,
                        onPressed: p.canBuyLife ? () => _buy(p.buyOneLife, '+1 can!') : null,
                      ),
                      const SizedBox(height: 14),
                      GameButton(
                        label: p.canBuyLife
                            ? 'DOLDUR (${PlayerProgress.maxLives - p.lives})  •  ${p.refillPrice}'
                            : 'CANLAR DOLU',
                        icon: Icons.favorite_rounded,
                        palette: ButtonPalette.gold,
                        onPressed: p.canBuyLife ? () => _buy(p.buyLifeRefill, 'Canların doldu!') : null,
                      ),
                      const SizedBox(height: 14),
                      // Rewarded ads are not integrated: the button stays disabled
                      // until a RewardedAdService reports an ad as ready.
                      _AdLifeButton(onRewarded: () => _buy(() {
                        p.addLives(1);
                        return true;
                      }, '+1 can!')),
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

class _AdLifeButton extends StatelessWidget {
  const _AdLifeButton({required this.onRewarded});

  final VoidCallback onRewarded;

  @override
  Widget build(BuildContext context) {
    final ads = AppScope.adsOf(context);
    final ready = ads.isReady(AdPlacement.extraLife);
    return GameButton(
      label: 'REKLAM İZLE  +1 CAN',
      icon: Icons.ondemand_video_rounded,
      palette: ButtonPalette.purple,
      badge: ready ? null : 'YAKINDA',
      onPressed: ready
          ? () async {
              // Reward only after the ad SDK confirms completion.
              if (await ads.show(AdPlacement.extraLife) == AdResult.completed) onRewarded();
            }
          : null,
    );
  }
}
