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

class _RescueOverlayState extends State<RescueOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _open = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.reduceMotion ? 150 : 420),
  )..forward();

  /// Heart breaks once (0 → 1), then idles.
  late final AnimationController _break = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  /// Prevents double taps from applying an action twice.
  bool _acted = false;

  @override
  void initState() {
    super.initState();
    if (widget.reduceMotion) {
      _break.value = 1;
    } else {
      _break.forward().whenComplete(() {
        if (mounted) _idle.repeat();
      });
    }
  }

  @override
  void dispose() {
    _open.dispose();
    _break.dispose();
    _idle.dispose();
    super.dispose();
  }

  /// Buttons slide in one after another.
  Widget _stagger(int i, Widget child) {
    if (widget.reduceMotion) return child;
    final anim = CurvedAnimation(
      parent: _open,
      curve: Interval(
        (0.25 + i * 0.1).clamp(0, 0.9),
        1,
        curve: Curves.easeOutCubic,
      ),
    );
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.4),
          end: Offset.zero,
        ).animate(anim),
        child: child,
      ),
    );
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
            opacity: CurvedAnimation(
              parent: _open,
              curve: const Interval(0, 0.5),
            ),
            child: const ColoredBox(color: Color(0xC0070420)),
          ),
        ),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: ScaleTransition(
                scale: CurvedAnimation(
                  parent: _open,
                  curve: Curves.easeOutBack,
                ),
                child: GameCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 120,
                        child: AnimatedBuilder(
                          animation: Listenable.merge([_break, _idle]),
                          builder: (context, _) => _BreakingHeart(
                            progress: _break.value,
                            idle: _idle.value,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.pink.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.pink, width: 1.5),
                        ),
                        child: const Text(
                          'BAŞARISIZ',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        deadlock ? 'HAMLE KALMADI!' : 'ÇÖZÜM KALMADI!',
                        textAlign: TextAlign.center,
                        style: AppText.title.copyWith(fontSize: 28),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        deadlock ? 'Yapılabilecek geçerli bir aktarım yok.' : 'Hamle var ama bu dizilimden bölüm artık çözülemiyor.',
                        textAlign: TextAlign.center,
                        style: AppText.body.copyWith(fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      const FittedBox(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            LivesChip(),
                            SizedBox(width: 8),
                            CoinsChip(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _stagger(
                        0,
                        GameButton(
                          label: p.undos > 0
                              ? 'GERİ AL  (${p.undos})'
                              : 'GERİ AL',
                          icon: Icons.undo_rounded,
                          height: 50,
                          badge: widget.canUndo
                              ? null
                              : (p.undos == 0 ? 'HAK YOK' : null),
                          onPressed: widget.canUndo
                              ? () => _once(widget.onUndo)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _stagger(
                        1,
                        GameButton(
                          label: coinLabel,
                          icon: Icons.add_box_rounded,
                          height: 50,
                          palette: ButtonPalette.gold,
                          onPressed: widget.canAddBottle && canAffordRescue
                              ? () => widget
                                    .onCoinRescue() // confirmation dialog first
                              : null,
                        ),
                      ),
                      if (widget.canAddBottle && !canAffordRescue)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Yeterli altının yok',
                            style: AppText.body.copyWith(fontSize: 12),
                          ),
                        ),
                      const SizedBox(height: 10),
                      _stagger(
                        2,
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
                      ),
                      const SizedBox(height: 10),
                      _stagger(
                        3,
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
                      ),
                      const SizedBox(height: 8),
                      Text(
                        p.hasLives
                            ? 'Bölüm başarısız olarak kaydedildi. Kurtarabilir ya da 1 can ile tekrar deneyebilirsin.'
                            : 'Canın yok: kurtarabilir, bekleyebilir veya can alabilirsin.',
                        textAlign: TextAlign.center,
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

/// Heart that cracks into two halves and sheds shards, with a pulsing halo.
class _BreakingHeart extends StatelessWidget {
  const _BreakingHeart({required this.progress, required this.idle});

  /// 0 → 1: whole → pulse → split apart.
  final double progress;

  /// Looping 0 → 1 after the break (gentle sad sway).
  final double idle;

  static const _size = 92.0;

  @override
  Widget build(BuildContext context) {
    final split = Curves.easeOutBack.transform(
      ((progress - 0.35) / 0.65).clamp(0.0, 1.0),
    );
    final beat = progress < 0.35
        ? 1 + 0.12 * math.sin(progress / 0.35 * math.pi)
        : 1.0;
    final sway = math.sin(idle * math.pi * 2);
    Widget half(bool left) => ClipRect(
      clipper: _HalfClipper(left: left),
      child: const HeartIcon(size: _size),
    );
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulsing halo.
        Container(
          width: 130 + 10 * sway,
          height: 130 + 10 * sway,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppColors.pink.withValues(alpha: 0.45),
                AppColors.pink.withValues(alpha: 0),
              ],
            ),
          ),
        ),
        CustomPaint(size: const Size(140, 120), painter: _ShardPainter(split)),
        Transform.rotate(
          angle: sway * 0.04,
          child: Transform.scale(
            scale: beat,
            child: SizedBox(
              width: _size,
              height: _size,
              child: Stack(
                children: [
                  Transform.translate(
                    offset: Offset(-8 * split, 4 * split),
                    child: Transform.rotate(
                      angle: -0.22 * split,
                      child: half(true),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(8 * split, 6 * split),
                    child: Transform.rotate(
                      angle: 0.25 * split,
                      child: half(false),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Left/right half with a jagged crack line down the middle.
class _HalfClipper extends CustomClipper<Rect> {
  const _HalfClipper({required this.left});

  final bool left;

  @override
  Rect getClip(Size size) => left
      ? Rect.fromLTWH(0, 0, size.width / 2, size.height)
      : Rect.fromLTWH(size.width / 2, 0, size.width / 2, size.height);

  @override
  bool shouldReclip(_HalfClipper old) => old.left != left;
}

/// Small shards falling from the crack.
class _ShardPainter extends CustomPainter {
  _ShardPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    final c = Offset(size.width / 2, size.height * 0.45);
    for (var i = 0; i < 7; i++) {
      final dir = (i - 3) * 0.32;
      final p = c + Offset(dir * 40 * t, 10 + 46 * t * t + (i % 3) * 6 * t);
      final r = 3.0 + (i % 3);
      final paint = Paint()
        ..color = const Color(0xFFFF8AAA)
            .withValues(alpha: (1 - t * 0.8).clamp(0, 1));
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(t * (i + 1));
      canvas.drawPath(
        Path()
          ..moveTo(0, -r)
          ..lineTo(r, r)
          ..lineTo(-r, r * 0.6)
          ..close(),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ShardPainter old) => old.t != t;
}
