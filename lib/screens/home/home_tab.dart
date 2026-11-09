import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/backgrounds.dart';
import '../../core/widgets/game_button.dart';
import '../../core/widgets/game_dialog.dart';
import '../../core/widgets/resource_chips.dart';
import '../../data/player_progress.dart';
import '../../game/engine/ball_type.dart';
import '../../game/render/ball_painter.dart';
import '../game/launch.dart';
import 'top_bar.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key, this.onOpenShop});

  final VoidCallback? onOpenShop;

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context);
    final allDone = p.unlockedLevel > p.levelCount;
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          TopResourceBar(onOpenShop: onOpenShop),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) => SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: c.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        const Spacer(),
                        _Logo(compact: c.maxHeight < 520),
                        const Spacer(),
                        _LevelBadge(
                          level: p.currentLevel,
                          stars: p.totalStars,
                          maxStars: p.levelCount * 3,
                        ),
                        const SizedBox(height: 16),
                        _PulsingPlayButton(
                          label: allDone ? 'TEKRAR OYNA' : 'OYNA',
                          onPressed: () => startLevel(context, p.currentLevel),
                        ),
                        const SizedBox(height: 20),
                        const _DailyRewardCard(),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Logo extends StatefulWidget {
  const _Logo({required this.compact});

  final bool compact;

  @override
  State<_Logo> createState() => _LogoState();
}

class _LogoState extends State<_Logo> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ballSize = widget.compact ? 52.0 : 72.0;
    const balls = [BallType.basketball, BallType.football, BallType.baseball];
    return Column(
      children: [
        SizedBox(
          height: ballSize * 1.5,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < balls.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Transform.translate(
                      offset: Offset(
                        0,
                        -math.sin((_c.value + i / 3) * math.pi * 2).abs() * ballSize * 0.32,
                      ),
                      child: BallView(balls[i], size: i == 1 ? ballSize * 1.15 : ballSize),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: ShaderMask(
            shaderCallback: (r) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Color(0xFFB8F7FF), AppColors.turquoise],
            ).createShader(r),
            child: Text(
              'BALL SORT',
              style: TextStyle(
                fontSize: widget.compact ? 42 : 52,
                height: 1,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: Colors.white,
                shadows: const [
                  Shadow(color: Color(0xFF4722A8), offset: Offset(0, 4)),
                  Shadow(color: Color(0x88000000), offset: Offset(0, 8), blurRadius: 10),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Transform.rotate(
          angle: -0.04,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.pink, AppColors.violet]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [BoxShadow(color: AppColors.pink.withValues(alpha: 0.5), blurRadius: 14)],
            ),
            child: const Text(
              'PARTY',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 6,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level, required this.stars, required this.maxStars});

  final int level;
  final int stars;
  final int maxStars;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('BÖLÜM $level', style: AppText.heading),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0x55100B3A),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star_rounded, color: AppColors.gold, size: 20),
              const SizedBox(width: 2),
              Text('$stars/$maxStars', style: AppText.label),
            ],
          ),
        ),
      ],
    );
  }
}

class _PulsingPlayButton extends StatefulWidget {
  const _PulsingPlayButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  State<_PulsingPlayButton> createState() => _PulsingPlayButtonState();
}

class _PulsingPlayButtonState extends State<_PulsingPlayButton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 1.0, end: 1.04).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: GameButton(
          label: widget.label,
          icon: Icons.play_arrow_rounded,
          height: 76,
          fontSize: 30,
          onPressed: widget.onPressed,
        ),
      ),
    );
  }
}

class _DailyRewardCard extends StatefulWidget {
  const _DailyRewardCard();

  @override
  State<_DailyRewardCard> createState() => _DailyRewardCardState();
}

class _DailyRewardCardState extends State<_DailyRewardCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _claim() async {
    final p = AppScope.read(context);
    final amount = p.claimDaily();
    if (amount == 0) return;
    await showGameDialog<void>(
      context,
      title: 'GÜNLÜK ÖDÜL!',
      header: const CoinIcon(size: 72),
      message: '+$amount altın hesabına eklendi.\nYarın tekrar gel, seri ödülün büyüsün!',
      actions: const [DialogAction('HARİKA', null, palette: ButtonPalette.gold)],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context);
    final can = p.canClaimDaily;
    final index = p.dailyIndex;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: GlassPanel(
        highlight: can ? AppColors.gold : null,
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      center: Alignment(-0.3, -0.4),
                      colors: [Color(0xFFFFE9A0), AppColors.gold, AppColors.goldDark],
                    ),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('GÜNLÜK ÖDÜL', style: AppText.label),
                      const SizedBox(height: 2),
                      Text(
                        can
                            ? 'Gün ${index + 1}: ${p.dailyAmount} altın'
                            : 'Yeni ödül: ${formatDuration(p.timeUntilNextDaily)}',
                        style: AppText.body.copyWith(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 92,
                  child: GameButton(
                    label: can ? 'AL' : 'ALINDI',
                    height: 46,
                    fontSize: can ? 18 : 13,
                    palette: ButtonPalette.gold,
                    onPressed: can ? _claim : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (var d = 0; d < PlayerProgress.dailyRewards.length; d++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _DayDot(
                        day: d + 1,
                        claimed: can ? d < index : d <= index,
                        today: d == index,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({required this.day, required this.claimed, required this.today});

  final int day;
  final bool claimed;
  final bool today;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        color: claimed ? AppColors.turquoiseDark : const Color(0x33FFFFFF),
        border: Border.all(
          color: today ? AppColors.gold : Colors.transparent,
          width: 2,
        ),
      ),
      child: claimed
          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
          : Text('$day', style: AppText.label.copyWith(fontSize: 11)),
    );
  }
}
