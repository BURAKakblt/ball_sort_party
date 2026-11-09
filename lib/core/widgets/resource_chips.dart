import 'dart:async';

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../data/player_progress.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

/// Gold coin drawn with gradients.
class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 26});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.35, -0.4),
          colors: [Color(0xFFFFF3B0), AppColors.gold, AppColors.goldDark],
          stops: [0, 0.55, 1],
        ),
        border: Border.all(color: const Color(0xFFB06200), width: size * 0.06),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 3, offset: const Offset(0, 2)),
        ],
      ),
      child: Center(
        child: Icon(Icons.star_rounded, size: size * 0.62, color: const Color(0xFFD27A00)),
      ),
    );
  }
}

/// Glossy heart.
class HeartIcon extends StatelessWidget {
  const HeartIcon({super.key, this.size = 28, this.broken = false});

  final double size;
  final bool broken;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (r) => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF9DB8), AppColors.pink, Color(0xFFC21E55)],
      ).createShader(r),
      child: Icon(
        broken ? Icons.heart_broken_rounded : Icons.favorite_rounded,
        size: size,
        color: Colors.white,
        shadows: const [Shadow(color: Color(0x66000000), blurRadius: 3, offset: Offset(0, 2))],
      ),
    );
  }
}

/// Pill showing an icon, a value and an optional subtitle / plus button.
class ResourcePill extends StatelessWidget {
  const ResourcePill({
    super.key,
    required this.icon,
    required this.value,
    this.subtitle,
    this.onPlus,
  });

  final Widget icon;
  final String value;
  final String? subtitle;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPlus,
      child: Container(
        height: 40,
        padding: const EdgeInsets.only(left: 4, right: 4),
        decoration: BoxDecoration(
          color: const Color(0x66100B3A),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.panelBorder, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 6),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: AppText.label.copyWith(fontSize: 16, height: 1.05)),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: AppText.label.copyWith(
                      fontSize: 10,
                      color: AppColors.textMuted,
                      height: 1.05,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 6),
            if (onPlus != null)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF7CF7A0), Color(0xFF1FB45A)],
                  ),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
              )
            else
              const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

/// Lives indicator with a live regeneration countdown.
class LivesChip extends StatefulWidget {
  const LivesChip({super.key, this.onPlus});

  final VoidCallback? onPlus;

  @override
  State<LivesChip> createState() => _LivesChipState();
}

class _LivesChipState extends State<LivesChip> {
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

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context);
    final next = p.timeToNextLife;
    return ResourcePill(
      icon: const HeartIcon(),
      value: '${p.lives}',
      subtitle: next == null ? 'DOLU' : formatDuration(next),
      onPlus: widget.onPlus,
    );
  }
}

class CoinsChip extends StatelessWidget {
  const CoinsChip({super.key, this.onPlus});

  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context);
    return ResourcePill(icon: const CoinIcon(), value: '${p.coins}', onPlus: onPlus);
  }
}

/// Exposes [PlayerProgress.maxLives] for labels.
const kMaxLives = PlayerProgress.maxLives;
