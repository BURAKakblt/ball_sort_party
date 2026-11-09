import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../audio/audio_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/backgrounds.dart';
import '../../core/widgets/confetti.dart';
import '../../core/widgets/game_button.dart';
import '../../core/widgets/game_dialog.dart';
import '../../core/widgets/gift_box.dart';
import '../../core/widgets/resource_chips.dart';
import '../../data/economy_config.dart';
import '../../data/gift_config.dart';

/// "Sürpriz Hediyeler": one free box every 48 hours.
class GiftScreen extends StatefulWidget {
  const GiftScreen({super.key, this.random});

  /// Injectable for tests; defaults to a cryptographically secure source.
  final math.Random? random;

  @override
  State<GiftScreen> createState() => _GiftScreenState();
}

class _GiftScreenState extends State<GiftScreen> with TickerProviderStateMixin {
  late final math.Random _random = widget.random ?? math.Random.secure();
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  late final AnimationController _open = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );
  Timer? _timer;

  int? _chosen;
  GiftReward? _reward;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    if (!AppScope.read(context).reduceMotion) _idle.repeat();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _idle.dispose();
    _open.dispose();
    super.dispose();
  }

  Future<void> _pick(int index) async {
    final p = AppScope.read(context);
    final audio = AppScope.audioOf(context);
    if (_chosen != null) return;
    if (!p.canOpenGift) {
      audio.play(Sfx.invalid);
      showToast(context, 'Sonraki hediye: ${formatDuration(p.timeUntilGift)}');
      return;
    }
    // Grant first (single save) so closing the app mid-animation loses nothing.
    final reward = p.openGift(_random);
    if (reward == null) return;
    setState(() {
      _chosen = index;
      _reward = reward;
    });
    HapticFeedback.mediumImpact();
    if (p.reduceMotion) {
      _open.value = 1;
    } else {
      Future.delayed(const Duration(milliseconds: 330), () {
        if (mounted) audio.play(Sfx.giftOpen);
      });
      await _open.forward();
    }
    if (!mounted) return;
    audio.play(reward.kind == GiftKind.lives ? Sfx.life : Sfx.coin);
    setState(() => _revealed = true);
  }

  void _showOdds() {
    showGameDialog<void>(
      context,
      title: 'ÖDÜL OLASILIKLARI',
      message: 'Her kutu aynı olasılıklara sahiptir. Ödül, kutu açıldığında rastgele belirlenir.',
      content: Column(
        children: [
          for (final g in GiftConfig.pool)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  _RewardIcon(g.kind, size: 26),
                  const SizedBox(width: 10),
                  Expanded(child: Text(g.label, style: AppText.label)),
                  Text(
                    '%${(GiftConfig.probability(g) * 100).toStringAsFixed(0)}',
                    style: AppText.label.copyWith(color: AppColors.turquoise),
                  ),
                ],
              ),
            ),
        ],
      ),
      actions: const [DialogAction('TAMAM', null, palette: ButtonPalette.navy)],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context);
    final can = p.canOpenGift && _chosen == null;
    final reward = _reward;
    return Scaffold(
      body: GradientBackground(
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      children: [
                        RoundIconButton(
                          icon: Icons.arrow_back_rounded,
                          size: 46,
                          palette: ButtonPalette.navy,
                          tooltip: 'Geri',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text('Sürpriz Hediyeler', style: AppText.title),
                          ),
                        ),
                        RoundIconButton(
                          icon: Icons.info_outline_rounded,
                          size: 46,
                          palette: ButtonPalette.navy,
                          tooltip: 'Olasılıklar',
                          onPressed: _showOdds,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _StatusBanner(
                    canOpen: can,
                    opened: _chosen != null,
                    remaining: p.timeUntilGift,
                    lastGift: p.lastGift?.label,
                  ),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: GridView.count(
                          crossAxisCount: 3,
                          padding: const EdgeInsets.all(16),
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 0.82,
                          shrinkWrap: true,
                          children: [
                            for (var i = 0; i < EconomyConfig.giftBoxCount; i++)
                              _GiftTile(
                                index: i,
                                idle: _idle,
                                open: _open,
                                chosen: _chosen == i,
                                dimmed: (_chosen != null && _chosen != i) || (!can && _chosen == null),
                                onTap: () => _pick(i),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                    child: Text(
                      'Her ${EconomyConfig.giftCooldown.inHours} saatte bir kutu ücretsiz açılır.',
                      textAlign: TextAlign.center,
                      style: AppText.body.copyWith(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            if (_revealed && reward != null)
              Positioned.fill(
                child: _RewardReveal(
                  reward: reward,
                  reduceMotion: p.reduceMotion,
                  onCollect: () => setState(() => _revealed = false),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.canOpen, required this.opened, required this.remaining, this.lastGift});

  final bool canOpen;
  final bool opened;
  final Duration remaining;
  final String? lastGift;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassPanel(
        highlight: canOpen ? AppColors.gold : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              canOpen ? Icons.touch_app_rounded : Icons.schedule_rounded,
              color: canOpen ? AppColors.gold : AppColors.turquoise,
              size: 30,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    canOpen ? 'Bir kutu seç!' : 'SONRAKİ HEDİYE',
                    style: AppText.label.copyWith(fontSize: 15),
                  ),
                  if (!canOpen)
                    Text(
                      formatDuration(remaining),
                      style: AppText.heading.copyWith(color: AppColors.turquoise),
                    ),
                  if (!canOpen && lastGift != null)
                    Text('Son ödül: $lastGift', style: AppText.body.copyWith(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GiftTile extends StatelessWidget {
  const _GiftTile({
    required this.index,
    required this.idle,
    required this.open,
    required this.chosen,
    required this.dimmed,
    required this.onTap,
  });

  final int index;
  final Animation<double> idle;
  final Animation<double> open;
  final bool chosen;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = GiftPalette.all[index % GiftPalette.all.length];
    return Semantics(
      button: true,
      label: 'Hediye kutusu ${index + 1}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedBuilder(
          animation: Listenable.merge([idle, open]),
          builder: (context, _) {
            final phase = (idle.value + index / 6) % 1;
            var dy = -math.sin(phase * math.pi * 2) * 3;
            var scale = 1.0;
            var tilt = 0.0;
            var lid = 0.0;
            var glow = 0.0;
            if (chosen) {
              final t = open.value;
              // 0-0.25: jump with squash; 0.25-0.6: lid pops; then glow.
              if (t < 0.25) {
                final k = t / 0.25;
                dy = -math.sin(k * math.pi) * 22;
                scale = 1 + math.sin(k * math.pi) * 0.08;
                tilt = math.sin(k * math.pi * 3) * 0.06;
              }
              lid = ((t - 0.25) / 0.35).clamp(0.0, 1.0);
              glow = ((t - 0.3) / 0.4).clamp(0.0, 1.0);
              scale *= 1 + glow * 0.08;
            }
            return Transform.translate(
              offset: Offset(0, dy),
              child: Transform.rotate(
                angle: tilt,
                child: Transform.scale(
                  scale: scale,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(
                        painter: GiftBoxPainter(palette: palette, lidOpen: lid, glow: glow, dimmed: dimmed),
                      ),
                      if (chosen && glow > 0) _Sparkles(progress: glow),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Twinkling stars rising from the opened box.
class _Sparkles extends StatelessWidget {
  const _Sparkles({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _SparklePainter(progress)),
    );
  }
}

class _SparklePainter extends CustomPainter {
  _SparklePainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.5);
    for (var i = 0; i < 12; i++) {
      final a = -math.pi / 2 + (i - 5.5) * 0.22;
      final d = size.width * 0.6 * Curves.easeOut.transform(t) * (0.6 + (i % 3) * 0.2);
      final p = origin + Offset(math.cos(a), math.sin(a)) * d;
      final r = 3.0 + (i % 3) * 2;
      final paint = Paint()
        ..color = (i.isEven ? const Color(0xFFFFE27A) : const Color(0xFF7CFFF1)).withValues(alpha: 1 - t * 0.7);
      final path = Path();
      for (var k = 0; k < 8; k++) {
        final ang = k * math.pi / 4;
        final rr = k.isEven ? r : r * 0.4;
        final pt = p + Offset(math.cos(ang), math.sin(ang)) * rr;
        k == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
      }
      canvas.drawPath(path..close(), paint);
    }
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.t != t;
}

class _RewardIcon extends StatelessWidget {
  const _RewardIcon(this.kind, {this.size = 80});

  final GiftKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    return switch (kind) {
      GiftKind.coins => CoinIcon(size: size),
      GiftKind.lives => HeartIcon(size: size),
      GiftKind.extraBottles => Icon(Icons.add_box_rounded, size: size, color: AppColors.gold),
      GiftKind.shuffles => Icon(Icons.shuffle_rounded, size: size, color: AppColors.violet),
    };
  }
}

/// Big animated reward announcement.
class _RewardReveal extends StatefulWidget {
  const _RewardReveal({required this.reward, required this.onCollect, required this.reduceMotion});

  final GiftReward reward;
  final VoidCallback onCollect;
  final bool reduceMotion;

  @override
  State<_RewardReveal> createState() => _RewardRevealState();
}

class _RewardRevealState extends State<_RewardReveal> with TickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );

  @override
  void initState() {
    super.initState();
    if (!widget.reduceMotion) _spin.repeat();
  }

  @override
  void dispose() {
    _in.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: FadeTransition(opacity: _in, child: const ColoredBox(color: Color(0xCC070420))),
        ),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('TEBRİKLER!', style: AppText.title),
                const SizedBox(height: 12),
                SizedBox(
                  width: 220,
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      RotationTransition(
                        turns: _spin,
                        child: CustomPaint(size: const Size(220, 220), painter: _RaysPainter()),
                      ),
                      ScaleTransition(
                        scale: CurvedAnimation(parent: _in, curve: Curves.elasticOut),
                        child: _RewardIcon(widget.reward.kind, size: 110),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                ScaleTransition(
                  scale: CurvedAnimation(parent: _in, curve: const Interval(0.3, 1, curve: Curves.easeOutBack)),
                  child: Text(
                    '+${widget.reward.label}',
                    style: AppText.title.copyWith(fontSize: 36, color: AppColors.gold),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 240,
                  child: GameButton(
                    label: 'TOPLA',
                    icon: Icons.check_rounded,
                    palette: ButtonPalette.gold,
                    onPressed: widget.onCollect,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned.fill(child: ConfettiBurst(count: widget.reduceMotion ? 25 : 90)),
      ],
    );
  }
}

/// Rotating light rays behind the reward icon.
class _RaysPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(colors: [
          const Color(0xAAFFE9A0),
          const Color(0x00FFE9A0),
        ]).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    final rays = Paint()..color = const Color(0x40FFF5C8);
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy)
          ..lineTo(c.dx + math.cos(a - 0.1) * r, c.dy + math.sin(a - 0.1) * r)
          ..lineTo(c.dx + math.cos(a + 0.1) * r, c.dy + math.sin(a + 0.1) * r)
          ..close(),
        rays,
      );
    }
  }

  @override
  bool shouldRepaint(_RaysPainter old) => false;
}
