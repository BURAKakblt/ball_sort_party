import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/backgrounds.dart';
import '../../core/widgets/game_button.dart';
import '../../core/widgets/game_dialog.dart';
import '../../core/widgets/resource_chips.dart';
import '../../data/player_progress.dart';
import '../../game/engine/game_engine.dart';
import '../../game/flame/ball_sort_game.dart';
import '../../game/levels/level.dart';
import '../settings/settings_screen.dart';
import 'level_complete_overlay.dart';
import 'out_of_lives_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.level});

  final Level level;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

enum _Exit { resume, restart, settings, home }

class _GameScreenState extends State<GameScreen> {
  late final GameEngine _engine = GameEngine(widget.level.createState());
  late final BallSortGame _game = BallSortGame(
    engine: _engine,
    hapticsEnabled: () => AppScope.read(context).hapticsOn,
    listener: BoardListener(
      onChanged: () => setState(() {}),
      onInvalid: _onInvalid,
      onSolved: _onSolved,
      onStuck: () => setState(() => _stuck = true),
    ),
  );
  final _random = Random();

  bool _stuck = false;
  bool _won = false;
  int _invalidCount = 0;
  ({int stars, int coins, int moves})? _result;

  PlayerProgress get _progress => AppScope.read(context);

  /// An unfinished level with moves played costs a life when abandoned.
  bool get _wouldCostLife => !_won && _engine.moveCount > 0;

  void _onInvalid(InvalidReason reason) {
    _invalidCount++;
    // Teach the rule a couple of times, then stay quiet.
    if (_invalidCount <= 2 && reason == InvalidReason.mismatch) {
      showToast(context, 'Top yalnızca boş şişeye veya aynı türün üstüne konabilir');
    } else if (_invalidCount <= 2 && reason == InvalidReason.targetFull) {
      showToast(context, 'Bu şişe dolu!');
    }
  }

  void _onSolved() {
    final stars = widget.level.starsFor(_engine.moveCount);
    final coins = _progress.completeLevel(widget.level.number, stars, widget.level.coinReward);
    setState(() {
      _won = true;
      _stuck = false;
      _result = (stars: stars, coins: coins, moves: _engine.moveCount);
    });
  }

  // ------------------------------------------------------------------ power-ups

  void _undo() {
    if (_game.undo()) setState(() => _stuck = false);
  }

  Future<bool> _offerPurchase({
    required String title,
    required String item,
    required int price,
    required bool Function() buy,
  }) async {
    final canAfford = _progress.coins >= price;
    final ok = await showGameDialog<bool>(
      context,
      title: title,
      header: const CoinIcon(size: 56),
      message: canAfford
          ? '3 adet $item satın al?\nFiyat: $price altın'
          : 'Yeterli altının yok ($price altın gerekli).\nBölümleri tamamlayarak ve günlük ödülle altın kazanabilirsin.',
      actions: [
        if (canAfford) DialogAction('$price ALTINA AL', true, palette: ButtonPalette.gold),
        const DialogAction('VAZGEÇ', false, palette: ButtonPalette.navy),
      ],
    );
    if (ok != true) return false;
    return buy();
  }

  Future<void> _shuffle() async {
    if (_progress.shuffles <= 0) {
      final bought = await _offerPurchase(
        title: 'KARIŞTIR',
        item: 'karıştırma',
        price: Prices.shuffle3,
        buy: _progress.buyShuffles,
      );
      if (!bought || !mounted) return;
    }
    if (_game.shuffle(_random)) {
      _progress.useShuffle();
      setState(() => _stuck = false);
    } else {
      showToast(context, 'Şu an karıştırılabilecek bir dizilim bulunamadı');
    }
  }

  Future<void> _extraBottle() async {
    if (!_engine.canAddBottle) {
      showToast(context, 'Bu bölümde ekstra şişe zaten kullanıldı');
      return;
    }
    if (_progress.extraBottles <= 0) {
      final bought = await _offerPurchase(
        title: 'EKSTRA ŞİŞE',
        item: 'ekstra şişe',
        price: Prices.extraBottle3,
        buy: _progress.buyExtraBottles,
      );
      if (!bought || !mounted) return;
    }
    if (_game.addExtraBottle()) {
      _progress.useExtraBottle();
      setState(() => _stuck = false);
    }
  }

  // ------------------------------------------------------------------ flow

  /// Asks for confirmation when leaving costs a life. Returns true to proceed.
  Future<bool> _confirmLifeLoss(String action) async {
    if (!_wouldCostLife) return true;
    final ok = await showGameDialog<bool>(
      context,
      title: 'EMİN MİSİN?',
      header: const HeartIcon(size: 56, broken: true),
      message: '$action 1 can kaybedersin.',
      actions: const [
        DialogAction('EVET', true, palette: ButtonPalette.pink),
        DialogAction('VAZGEÇ', false, palette: ButtonPalette.navy),
      ],
    );
    if (ok == true) _progress.loseLife();
    return ok == true;
  }

  Future<void> _restart() async {
    if (!await _confirmLifeLoss('Yeniden başlarsan') || !mounted) return;
    if (!_progress.hasLives) {
      Navigator.of(context).pushReplacement(GameRoute(const OutOfLivesScreen()));
      return;
    }
    _game.restart();
    setState(() {
      _stuck = false;
      _won = false;
      _result = null;
    });
  }

  Future<void> _leave() async {
    if (!await _confirmLifeLoss('Bölümden çıkarsan') || !mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _openSettings() async {
    _game.pauseEngine();
    await Navigator.of(context).push(GameRoute(const SettingsScreen()));
    _game.resumeEngine();
  }

  Future<void> _pause() async {
    _game.pauseEngine();
    final choice = await showGameDialog<_Exit>(
      context,
      title: 'DURAKLATILDI',
      header: const Icon(Icons.pause_circle_filled_rounded, size: 64, color: AppColors.turquoise),
      message: _wouldCostLife ? 'Yeniden başlamak veya çıkmak 1 cana mal olur.' : null,
      actions: const [
        DialogAction('DEVAM ET', _Exit.resume, icon: Icons.play_arrow_rounded),
        DialogAction('YENİDEN BAŞLAT', _Exit.restart, palette: ButtonPalette.purple, icon: Icons.refresh_rounded),
        DialogAction('AYARLAR', _Exit.settings, palette: ButtonPalette.navy, icon: Icons.settings_rounded),
        DialogAction('ANA MENÜ', _Exit.home, palette: ButtonPalette.pink, icon: Icons.home_rounded),
      ],
    );
    _game.resumeEngine();
    if (!mounted) return;
    switch (choice) {
      case _Exit.restart:
        await _restart();
      case _Exit.settings:
        await _openSettings();
      case _Exit.home:
        await _leave();
      case _Exit.resume || null:
        break;
    }
  }

  // ------------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context);
    return PopScope(
      canPop: !_wouldCostLife,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        body: GradientBackground(
          child: Stack(
            children: [
              SafeArea(
                child: Column(
                  children: [
                    _Hud(
                      level: widget.level.number,
                      moves: _engine.moveCount,
                      par: widget.level.par,
                      onPause: _pause,
                      onSettings: _openSettings,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: GameWidget(game: _game),
                      ),
                    ),
                    _PowerUpBar(
                      canUndo: _engine.canUndo && !_won,
                      shuffles: p.shuffles,
                      extraBottles: p.extraBottles,
                      canAddBottle: _engine.canAddBottle,
                      enabled: !_won,
                      onUndo: _undo,
                      onShuffle: _shuffle,
                      onExtraBottle: _extraBottle,
                      onRestart: _restart,
                    ),
                  ],
                ),
              ),
              if (_stuck && !_won)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.paddingOf(context).bottom + 110,
                  child: _StuckBanner(onClose: () => setState(() => _stuck = false)),
                ),
              if (_result != null)
                Positioned.fill(
                  child: LevelCompleteOverlay(
                    level: widget.level,
                    stars: _result!.stars,
                    coins: _result!.coins,
                    moves: _result!.moves,
                    onReplay: () {
                      _game.restart();
                      setState(() {
                        _won = false;
                        _result = null;
                      });
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hud extends StatelessWidget {
  const _Hud({
    required this.level,
    required this.moves,
    required this.par,
    required this.onPause,
    required this.onSettings,
  });

  final int level;
  final int moves;
  final int par;
  final VoidCallback onPause;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      child: Row(
        children: [
          RoundIconButton(
            icon: Icons.pause_rounded,
            size: 48,
            palette: ButtonPalette.navy,
            tooltip: 'Duraklat',
            onPressed: onPause,
          ),
          Expanded(
            child: Column(
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.violet, Color(0xFF5B34D6)]),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
                      boxShadow: [BoxShadow(color: AppColors.violet.withValues(alpha: 0.5), blurRadius: 14)],
                    ),
                    child: Text('BÖLÜM $level', style: AppText.heading.copyWith(fontSize: 20)),
                  ),
                ),
                const SizedBox(height: 4),
                Text('Hamle: $moves   •   Hedef: $par', style: AppText.body.copyWith(fontSize: 13)),
              ],
            ),
          ),
          RoundIconButton(
            icon: Icons.settings_rounded,
            size: 48,
            palette: ButtonPalette.navy,
            tooltip: 'Ayarlar',
            onPressed: onSettings,
          ),
        ],
      ),
    );
  }
}

class _PowerUpBar extends StatelessWidget {
  const _PowerUpBar({
    required this.canUndo,
    required this.shuffles,
    required this.extraBottles,
    required this.canAddBottle,
    required this.enabled,
    required this.onUndo,
    required this.onShuffle,
    required this.onExtraBottle,
    required this.onRestart,
  });

  final bool canUndo;
  final int shuffles;
  final int extraBottles;
  final bool canAddBottle;
  final bool enabled;
  final VoidCallback onUndo;
  final VoidCallback onShuffle;
  final VoidCallback onExtraBottle;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0x44100B3A),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.panelBorder, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Flexible(
            child: RoundIconButton(
              icon: Icons.undo_rounded,
              caption: 'Geri Al',
              palette: ButtonPalette.turquoise,
              onPressed: canUndo ? onUndo : null,
            ),
          ),
          Flexible(
            child: RoundIconButton(
              icon: Icons.shuffle_rounded,
              caption: 'Karıştır',
              count: shuffles > 0 ? '$shuffles' : '+',
              palette: ButtonPalette.purple,
              onPressed: enabled ? onShuffle : null,
            ),
          ),
          Flexible(
            child: RoundIconButton(
              icon: Icons.add_box_rounded,
              caption: 'Ekstra Şişe',
              count: !canAddBottle ? null : (extraBottles > 0 ? '$extraBottles' : '+'),
              palette: ButtonPalette.gold,
              onPressed: enabled && canAddBottle ? onExtraBottle : null,
            ),
          ),
          Flexible(
            child: RoundIconButton(
              icon: Icons.refresh_rounded,
              caption: 'Baştan',
              palette: ButtonPalette.pink,
              onPressed: enabled ? onRestart : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _StuckBanner extends StatelessWidget {
  const _StuckBanner({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Transform.translate(
        offset: Offset(0, (1 - t) * 40),
        child: Opacity(opacity: t.clamp(0, 1), child: child),
      ),
      child: GlassPanel(
        highlight: AppColors.pink,
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            const Icon(Icons.block_rounded, color: AppColors.pink, size: 30),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Hamle kalmadı! Geri al, ekstra şişe ekle veya karıştır.',
                style: AppText.label,
              ),
            ),
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
