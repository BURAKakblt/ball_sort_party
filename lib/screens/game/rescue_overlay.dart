import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/game_button.dart';
import '../../core/widgets/game_dialog.dart';
import '../../core/widgets/resource_chips.dart';
import '../../data/economy_config.dart';
import '../../game/engine/failure_monitor.dart';

/// "HAMLE KALMADI!" rescue screen. Opening it never costs a life; only the
/// "Tekrar Dene" action does.
class RescueOverlay extends StatefulWidget {
  const RescueOverlay({
    super.key,
    required this.status,
    required this.canUndo,
    required this.canAddBottle,
    required this.adReady,
    required this.onUndo,
    required this.onCoinRescue,
    required this.onAdRescue,
    required this.onRetry,
    required this.onOutOfLives,
    required this.onHome,
    this.reduceMotion = false,
  });

  final BoardStatus status;

  /// A move to undo exists AND the player has an undo left.
  final bool canUndo;

  /// The level's extra-bottle slot is still free.
  final bool canAddBottle;
  final bool adReady;
  final VoidCallback onUndo;
  final VoidCallback onCoinRescue;
  final VoidCallback onAdRescue;
  final VoidCallback onRetry;
  final VoidCallback onOutOfLives;
  final VoidCallback onHome;
  final bool reduceMotion;

  @override
  State<RescueOverlay> createState() => _RescueOverlayState();
}

class _RescueOverlayState extends State<RescueOverlay> with TickerProviderStateMixin {
  late final AnimationController _open = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.reduceMotion ? 150 : 420),
  )..forward();
  late final AnimationController _heart = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  /// Prevents double taps from applying an action twice.
  bool _acted = false;

  @override
  void initState() {
    super.initState();
    if (!widget.reduceMotion) _heart.repeat();
  }

  @override
  void dispose() {
    _open.dispose();
    _heart.dispose();
    super.dispose();
  }

  void _once(VoidCallback action) {
    if (_acted) return;
    _acted = true;
    action();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context);
    final deadlock = widget.status == BoardStatus.deadlock;
    final canAffordRescue = p.canAfford(EconomyConfig.rescueWithCoinsPrice);
    final coinLabel = !widget.canAddBottle
        ? 'EKSTRA ŞİŞE KULLANILDI'
        : '${EconomyConfig.rescueWithCoinsPrice} ALTINLA KURTAR';

    return Stack(
      children: [
        Positioned.fill(
          child: FadeTransition(
            opacity: CurvedAnimation(parent: _open, curve: const Interval(0, 0.5)),
            child: const ColoredBox(color: Color(0xC0070420)),
          ),
        ),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: ScaleTransition(
                scale: CurvedAnimation(parent: _open, curve: Curves.easeOutBack),
                child: GameCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _heart,
                        builder: (context, child) {
                          final t = _heart.value;
                          // Small sad "beat" with a tilt.
                          final beat = 1 + 0.08 * math.max(0, math.sin(t * math.pi * 4)) * (t < 0.5 ? 1 : 0);
                          return Transform.rotate(
                            angle: math.sin(t * math.pi * 2) * 0.08,
                            child: Transform.scale(scale: beat, child: child),
                          );
                        },
                        child: const HeartIcon(size: 86, broken: true),
                      ),
                      Text(
                        deadlock ? 'HAMLE KALMADI!' : 'ÇÖZÜM KALMADI!',
                        textAlign: TextAlign.center,
                        style: AppText.title.copyWith(fontSize: 28),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        deadlock
                            ? 'Yapılabilecek geçerli bir aktarım yok.'
                            : 'Hamle var ama bu dizilimden bölüm artık çözülemiyor.',
                        textAlign: TextAlign.center,
                        style: AppText.body.copyWith(fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      const FittedBox(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [LivesChip(), SizedBox(width: 8), CoinsChip()],
                        ),
                      ),
                      const SizedBox(height: 16),
                      GameButton(
                        label: 'GERİ AL',
                        icon: Icons.undo_rounded,
                        height: 50,
                        badge: widget.canUndo ? null : (p.undos == 0 ? 'HAK YOK' : null),
                        onPressed: widget.canUndo ? () => _once(widget.onUndo) : null,
                      ),
                      const SizedBox(height: 10),
                      GameButton(
                        label: coinLabel,
                        icon: Icons.add_box_rounded,
                        height: 50,
                        palette: ButtonPalette.gold,
                        onPressed: widget.canAddBottle && canAffordRescue
                            ? () => widget.onCoinRescue() // confirmation dialog first
                            : null,
                      ),
                      if (widget.canAddBottle && !canAffordRescue)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('Yeterli altının yok', style: AppText.body.copyWith(fontSize: 12)),
                        ),
                      const SizedBox(height: 10),
                      GameButton(
                        label: 'REKLAMLA KURTAR',
                        icon: Icons.ondemand_video_rounded,
                        height: 50,
                        palette: ButtonPalette.purple,
                        badge: widget.adReady ? null : 'YAKINDA',
                        onPressed: widget.adReady && widget.canAddBottle
                            ? () => _once(widget.onAdRescue)
                            : null,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: p.hasLives
                                ? GameButton(
                                    label: 'TEKRAR DENE',
                                    icon: Icons.refresh_rounded,
                                    height: 50,
                                    fontSize: 15,
                                    palette: ButtonPalette.pink,
                                    onPressed: () => _once(widget.onRetry),
                                  )
                                : GameButton(
                                    label: 'CAN YOK',
                                    icon: Icons.favorite_border_rounded,
                                    height: 50,
                                    fontSize: 15,
                                    palette: ButtonPalette.pink,
                                    onPressed: widget.onOutOfLives,
                                  ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GameButton(
                              label: 'ANA MENÜ',
                              icon: Icons.home_rounded,
                              height: 50,
                              fontSize: 15,
                              palette: ButtonPalette.navy,
                              onPressed: () => _once(widget.onHome),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        p.hasLives ? 'Tekrar Dene 1 can kullanır.' : 'Canın yok: bekle veya can al.',
                        style: AppText.body.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
