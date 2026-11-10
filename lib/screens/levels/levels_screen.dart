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
import '../../game/levels/level_data.dart';
import '../game/launch.dart';
import '../home/top_bar.dart';

/// Level select: 50 levels grouped by difficulty band, scrolls to the
/// player's current level on open.
class LevelsScreen extends StatefulWidget {
  const LevelsScreen({super.key});

  @override
  State<LevelsScreen> createState() => _LevelsScreenState();
}

class _LevelsScreenState extends State<LevelsScreen> {
  final _currentKey = GlobalKey();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent(animate: false));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// The grid is lazy: a far-away current tile isn't built yet, so page
  /// down until it exists, then align it.
  Future<void> _scrollToCurrent({bool animate = true}) async {
    if (!mounted || !_scroll.hasClients) return;
    for (var i = 0; i < 40 && _currentKey.currentContext == null; i++) {
      final pos = _scroll.position;
      if (pos.pixels >= pos.maxScrollExtent) break;
      _scroll.jumpTo((pos.pixels + pos.viewportDimension).clamp(0, pos.maxScrollExtent));
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
    final ctx = _currentKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    await Scrollable.ensureVisible(
      ctx,
      alignment: 0.35,
      duration: animate ? const Duration(milliseconds: 450) : Duration.zero,
      curve: Curves.easeOutCubic,
    );
  }

  void _open(PlayerProgress p, int n) {
    if (p.isUnlocked(n)) {
      startLevel(context, n);
    } else {
      showToast(context, 'Önce Bölüm ${n - 1}\'i tamamla');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context);
    final current = p.currentLevel;
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        controller: _scroll,
        slivers: [
          const SliverToBoxAdapter(child: TopResourceBar()),
          const SliverToBoxAdapter(child: ScreenTitle('Seviyeler', icon: Icons.grid_view_rounded)),
          SliverToBoxAdapter(
            child: _ProgressCard(
              current: current,
              cleared: [for (var n = 1; n <= kLevels.length; n++) if (p.isCleared(n)) n].length,
              stars: p.totalStars,
              allDone: p.unlockedLevel > kLevels.length,
              onContinue: () => startLevel(context, current),
              onLocate: _scrollToCurrent,
            ),
          ),
          for (final band in LevelBand.values) ...[
            SliverToBoxAdapter(child: _BandHeader(band: band, progress: p)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 92,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.82,
                ),
                delegate: SliverChildBuilderDelegate(
                  childCount: band.last - band.first + 1,
                  (context, i) {
                    final n = band.first + i;
                    final isCurrent = n == current && p.unlockedLevel <= kLevels.length;
                    return _Appear(
                      index: i,
                      enabled: !p.reduceMotion,
                      child: _LevelTile(
                        key: isCurrent ? _currentKey : null,
                        number: n,
                        stars: p.starsFor(n),
                        legacyStars: p.isCleared(n) && !p.starsAreCurrent(n),
                        unlocked: p.isUnlocked(n),
                        current: isCurrent,
                        failed: p.isLevelFailed(n),
                        animate: !p.reduceMotion,
                        onTap: () => _open(p, n),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: GlassPanel(
                child: Row(
                  children: [
                    Icon(Icons.rocket_launch_rounded, color: AppColors.turquoise, size: 34),
                    SizedBox(width: 12),
                    Expanded(child: Text('Yeni bölümler ve dünyalar hazırlanıyor.', style: AppText.label)),
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

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.current,
    required this.cleared,
    required this.stars,
    required this.allDone,
    required this.onContinue,
    required this.onLocate,
  });

  final int current;
  final int cleared;
  final int stars;
  final bool allDone;
  final VoidCallback onContinue;
  final VoidCallback onLocate;

  @override
  Widget build(BuildContext context) {
    final total = kLevels.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      child: GlassPanel(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$cleared / $total bölüm', style: AppText.label.copyWith(fontSize: 15)),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: cleared / total,
                          minHeight: 10,
                          backgroundColor: Colors.white12,
                          valueColor: const AlwaysStoppedAnimation(AppColors.turquoise),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.star_rounded, color: AppColors.gold, size: 26),
                Text('$stars/${total * 3}', style: AppText.label),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GameButton(
                    label: allDone ? 'TEKRAR OYNA' : 'DEVAM: BÖLÜM $current',
                    icon: Icons.play_arrow_rounded,
                    height: 50,
                    fontSize: 17,
                    onPressed: onContinue,
                  ),
                ),
                const SizedBox(width: 10),
                RoundIconButton(
                  icon: Icons.my_location_rounded,
                  size: 50,
                  palette: ButtonPalette.navy,
                  tooltip: 'Mevcut bölüme git',
                  onPressed: onLocate,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BandHeader extends StatelessWidget {
  const _BandHeader({required this.band, required this.progress});

  final LevelBand band;
  final PlayerProgress progress;

  @override
  Widget build(BuildContext context) {
    final levels = [for (var n = band.first; n <= band.last; n++) n];
    final stars = levels.fold(0, (a, n) => a + progress.starsFor(n));
    final locked = !progress.isUnlocked(band.first);
    const accents = {
      LevelBand.tutorial: AppColors.turquoise,
      LevelBand.easy: Color(0xFF7CF7A0),
      LevelBand.medium: AppColors.gold,
      LevelBand.mediumHard: Color(0xFFFF9A5C),
      LevelBand.hard: AppColors.pink,
    };
    final accent = accents[band]!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
      child: Row(
        children: [
          Container(width: 6, height: 26, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 10),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: band.label.toUpperCase(), style: AppText.label.copyWith(fontSize: 16, color: accent, letterSpacing: 1)),
                    TextSpan(text: '   ${band.first}–${band.last}', style: AppText.body.copyWith(fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
          if (locked)
            const Icon(Icons.lock_rounded, color: AppColors.textDim, size: 18)
          else ...[
            const Icon(Icons.star_rounded, color: AppColors.gold, size: 18),
            Text(' $stars/${levels.length * 3}', style: AppText.label.copyWith(fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

/// Staggered fade + scale-in for grid tiles.
class _Appear extends StatelessWidget {
  const _Appear({required this.index, required this.enabled, required this.child});

  final int index;
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + math.min(index, 10) * 45),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
      ),
      child: child,
    );
  }
}

class _LevelTile extends StatefulWidget {
  const _LevelTile({
    super.key,
    required this.number,
    required this.stars,
    required this.unlocked,
    required this.current,
    required this.onTap,
    this.failed = false,
    this.legacyStars = false,
    this.animate = true,
  });

  final int number;
  final int stars;
  final bool unlocked;
  final bool current;
  final bool failed;

  /// Stars earned on an older version of this level.
  final bool legacyStars;
  final bool animate;
  final VoidCallback onTap;

  @override
  State<_LevelTile> createState() => _LevelTileState();
}

class _LevelTileState extends State<_LevelTile> with SingleTickerProviderStateMixin {
  AnimationController? _pulse;

  @override
  void initState() {
    super.initState();
    _syncPulse();
  }

  @override
  void didUpdateWidget(_LevelTile old) {
    super.didUpdateWidget(old);
    _syncPulse();
  }

  /// Only the current tile pulses.
  void _syncPulse() {
    if (widget.current && widget.animate) {
      _pulse ??= AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    } else {
      _pulse?.dispose();
      _pulse = null;
    }
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final palette = !w.unlocked
        ? ButtonPalette.disabled
        : w.current
        ? ButtonPalette.turquoise
        : ButtonPalette.purple;
    final label = [
      'Bölüm ${w.number}',
      if (!w.unlocked) 'kilitli',
      if (w.current) 'mevcut bölüm',
      if (w.stars > 0) '${w.stars} yıldız',
      if (w.failed) 'başarısız',
    ].join(', ');
    Widget tile = Column(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: palette.depth,
            ),
            padding: const EdgeInsets.only(bottom: 5),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [palette.top, palette.bottom],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: w.current ? 0.9 : 0.4), width: w.current ? 2.5 : 1.5),
              ),
              alignment: Alignment.center,
              child: w.unlocked
                  ? FittedBox(
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text('${w.number}', style: AppText.title.copyWith(fontSize: 30)),
                      ),
                    )
                  : const Icon(Icons.lock_rounded, size: 26, color: Color(0xFFC9C6E4)),
            ),
          ),
        ),
        const SizedBox(height: 3),
        SizedBox(
          height: 18,
          child: FittedBox(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++)
                  Icon(
                    Icons.star_rounded,
                    size: 18,
                    color: i < w.stars
                        ? (w.legacyStars ? AppColors.gold.withValues(alpha: 0.5) : AppColors.gold)
                        : const Color(0x40FFFFFF),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
    final pulse = _pulse;
    if (pulse != null) {
      tile = AnimatedBuilder(
        animation: pulse,
        builder: (context, child) => DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.turquoise.withValues(alpha: 0.25 + 0.35 * pulse.value),
                blurRadius: 10 + 10 * pulse.value,
              ),
            ],
          ),
          child: child,
        ),
        child: tile,
      );
    }
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: w.onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: tile),
            if (w.failed)
              const Positioned(
                right: -4,
                top: -6,
                child: Tooltip(message: 'Başarısız — yeniden başlatmak 1 can', child: HeartIcon(size: 24, broken: true)),
              )
            else if (w.legacyStars)
              const Positioned(
                right: -4,
                top: -6,
                child: Tooltip(
                  message: 'Bölüm güncellendi — yıldızları yenilemek için tekrar oyna',
                  child: Icon(Icons.autorenew_rounded, size: 20, color: AppColors.gold),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
