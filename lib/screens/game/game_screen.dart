import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../app.dart';
import '../../audio/audio_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/backgrounds.dart';
import '../../core/widgets/game_button.dart';
import '../../core/widgets/game_dialog.dart';
import '../../core/widgets/resource_chips.dart';
import '../../data/economy_config.dart';
import '../../data/player_progress.dart';
import '../../game/engine/failure_monitor.dart';
import '../../game/engine/game_engine.dart';
import '../../game/flame/ball_sort_game.dart';
import '../../game/levels/level.dart';
import '../../game/session/level_session.dart';
import '../../services/rewarded_ad_service.dart';
import '../settings/settings_screen.dart';
import 'level_complete_overlay.dart';
import 'out_of_lives_screen.dart';
import 'rescue_overlay.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.level, this.analyzer});

  final Level level;

  /// Failure detection; defaults to a background-isolate solver.
  final BoardAnalyzer? analyzer;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

enum _Exit { resume, restart, settings, home }

class _GameScreenState extends State<GameScreen> {
  late final LevelSession _session = LevelSession(widget.level, _progress);
  late final BoardAnalyzer _analyzer = widget.analyzer ?? BoardAnalyzer();
  late final FailureMonitor _monitor = FailureMonitor(_analyzer);
  late final BallSortGame _game = BallSortGame(
    engine: _engine,
    hapticsEnabled: () => _progress.hapticsOn,
    reduceMotion: () => _progress.reduceMotion,
    listener: BoardListener(
      onChanged: () {
        _session.save(); // resume later, and keep FAILED boards
        setState(() {});
      },
      onInvalid: _onInvalid,
      onSelected: () => _audio.play(Sfx.select),
      onBallLanded: _audio.playLand,
      onBottleCompleted: () => _audio.play(Sfx.bottleComplete),
      onWinStarted: _monitor.invalidate,
      onSolved: _onSolved,
      onSettled: _checkFailure,
    ),
  );
  final _random = Random.secure();
  late final AudioService _audio;

  bool _won = false;
  bool _retrying = false;
  bool _rescueBusy = false;
  BoardStatus? _rescue;

  /// Bumped whenever the rescue screen (re)opens so it starts fresh.
  int _rescueEpoch = 0;
  int _invalidCount = 0;
  ({int stars, int coins, int moves})? _result;

  PlayerProgress get _progress => AppScope.read(context);
  GameEngine get _engine => _session.engine;

  @override
  void initState() {
    super.initState();
    _audio = AppScope.audioOf(context)..setMood(MusicMood.game);
    if (_session.isFailed) {
      // Leaving / closing the app never clears FAILED: show the rescue again.
      _rescue = _session.failReason ?? BoardStatus.deadlock;
    } else if (_session.hasProgress) {
      // The player may have left before the last failure check finished.
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkFailure());
    }
  }

  @override
  void dispose() {
    _monitor.invalidate();
    _audio.setMood(MusicMood.menu);
    super.dispose();
  }

  void _onInvalid(InvalidReason reason) {
    // Invalid input never costs lives or coins and never changes the board.
    _audio.play(Sfx.invalid);
    _invalidCount++;
    if (_invalidCount <= 2 && reason == InvalidReason.mismatch) {
      showToast(context, 'Top yalnızca boş şişeye veya aynı türün üstüne konabilir');
    } else if (_invalidCount <= 2 && reason == InvalidReason.targetFull) {
      showToast(context, 'Bu şişe dolu!');
    }
  }

  void _onSolved() {
    final stars = widget.level.starsFor(_engine.moveCount);
    final coins = _session.complete(stars); // PLAYING → COMPLETED, once
    _audio.play(Sfx.win);
    if (coins > 0) Future.delayed(const Duration(milliseconds: 900), () => _audio.play(Sfx.coin));
    setState(() {
      _won = true;
      _rescue = null;
      _result = (stars: stars, coins: coins, moves: _engine.moveCount);
    });
  }

  /// Runs after a move fully settled (win already excluded).
  Future<void> _checkFailure() async {
    if (_session.isFailed || _session.isCompleted) return;
    final status = await _monitor.check(_engine.state, _engine.moveCount);
    if (!mounted || status == null || _won || _engine.isSolved || _session.isFailed) return;
    _session.fail(status); // PLAYING → FAILED (persisted)
    _audio.play(Sfx.lose);
    setState(() {
      _rescue = status;
      _rescueEpoch++;
    });
  }

  void _closeRescue() {
    _monitor.invalidate();
    setState(() => _rescue = null);
  }

  /// After undo / coins / ad changed a FAILED board: recover only if the
  /// board is playable again; otherwise stay FAILED and keep the rescue open.
  Future<void> _afterRescueAction() async {
    if (!_session.isFailed) return _closeRescue();
    _monitor.invalidate();
    final status = await _analyzer.evaluate(_engine.state);
    if (!mounted) return;
    if (status == BoardStatus.deadlock || status == BoardStatus.unsolvable) {
      // Still FAILED (the changed board was already saved as FAILED).
      showToast(context, 'Hâlâ çözüm yok — bir hamle daha geri alabilirsin');
      setState(() {
        _rescue = status;
        _rescueEpoch++;
      });
      return;
    }
    _session.recover(); // FAILED → PLAYING
    setState(() => _rescue = null);
  }

  // ------------------------------------------------------------------ power-ups

  Future<bool> _confirmPurchase({required String title, required String message, required int price}) async {
    if (!_progress.canAfford(price)) {
      _audio.play(Sfx.invalid);
      await showGameDialog<void>(
        context,
        title: title,
        header: const CoinIcon(size: 56),
        message: 'Yeterli altının yok ($price altın gerekli).\n'
            'Bölümleri tamamlayarak, günlük ödül ve sürpriz hediyelerle altın kazanabilirsin.',
        actions: const [DialogAction('TAMAM', null, palette: ButtonPalette.navy)],
      );
      return false;
    }
    final ok = await showGameDialog<bool>(
      context,
      title: title,
      header: const CoinIcon(size: 56),
      message: '$message\nFiyat: $price altın',
      actions: [
        DialogAction('$price ALTINA AL', true, palette: ButtonPalette.gold),
        const DialogAction('VAZGEÇ', false, palette: ButtonPalette.navy),
      ],
    );
    return ok == true && mounted;
  }

  Future<void> _undo() async {
    if (!_engine.canUndo) return;
    if (_progress.undos <= 0) {
      final ok = await _confirmPurchase(
        title: 'GERİ AL',
        message: '${EconomyConfig.undoPackSize} geri alma hakkı satın al?',
        price: EconomyConfig.undoPackPrice,
      );
      if (!ok || !_progress.buyUndoPack()) return;
      _audio.play(Sfx.purchase);
    }
    _applyUndo();
  }

  void _applyUndo() {
    if (_progress.undos <= 0 || !_engine.canUndo) return;
    if (_game.undo()) {
      _progress.useUndo();
      _afterRescueAction();
    }
  }

  Future<void> _shuffle() async {
    if (_progress.shuffles > 0) {
      if (_game.shuffle(_random)) {
        _progress.useShuffle();
        _closeRescue();
      } else {
        showToast(context, 'Şu an karıştırılabilecek bir dizilim bulunamadı');
      }
      return;
    }
    final ok = await _confirmPurchase(
      title: 'KARIŞTIR',
      message: '1 karıştırma satın alıp hemen kullan?',
      price: EconomyConfig.shufflePrice,
    );
    if (!ok) return;
    // Coins are only spent if the shuffle actually happens.
    if (_progress.spend(EconomyConfig.shufflePrice, () => _game.shuffle(_random))) {
      _audio.play(Sfx.purchase);
      _closeRescue();
    } else if (mounted) {
      showToast(context, 'Karıştırılamadı, altın harcanmadı');
    }
  }

  Future<void> _extraBottle() async {
    if (!_engine.canAddBottle) {
      showToast(context, 'Bu bölümde ekstra şişe zaten kullanıldı');
      return;
    }
    if (_progress.extraBottles > 0) {
      if (_game.addExtraBottle()) {
        _progress.useExtraBottle();
        _closeRescue();
        _checkFailure();
      }
      return;
    }
    final ok = await _confirmPurchase(
      title: 'EKSTRA ŞİŞE',
      message: '1 ekstra şişe satın alıp hemen kullan?',
      price: EconomyConfig.extraBottlePrice,
    );
    if (!ok) return;
    if (_progress.spend(EconomyConfig.extraBottlePrice, _game.addExtraBottle)) {
      _audio.play(Sfx.purchase);
      _closeRescue();
      _checkFailure();
    }
  }

  // ------------------------------------------------------------------ rescue

  /// 200 coins → one extra empty bottle (the level's single extra slot).
  Future<void> _coinRescue() async {
    if (!_engine.canAddBottle) return;
    final ok = await _confirmPurchase(
      title: 'KURTAR',
      message: 'Bölüme 1 boş şişe eklenecek.',
      price: EconomyConfig.rescueWithCoinsPrice,
    );
    if (!ok) return;
    if (_rescueBusy) return;
    _rescueBusy = true;
    // Atomic: coins are deducted only if the bottle was actually added.
    if (_progress.spend(EconomyConfig.rescueWithCoinsPrice, _game.addExtraBottle)) {
      _audio.play(Sfx.purchase);
      await _afterRescueAction();
    }
    _rescueBusy = false;
  }

  Future<void> _adRescue() async {
    final ads = AppScope.adsOf(context);
    // Reward only on a confirmed completed ad.
    if (await ads.show(AdPlacement.rescue) != AdResult.completed || !mounted) return;
    if (_game.addExtraBottle()) await _afterRescueAction();
  }

  /// Retrying a FAILED level costs exactly one life (spent once, atomically).
  void _retryAfterFailure() {
    if (_retrying) return;
    _retrying = true;
    final result = _session.restart();
    if (result == RestartResult.noLives) {
      _retrying = false;
      _openOutOfLives();
      return;
    }
    _rebuildBoard();
    _retrying = false;
  }

  void _openOutOfLives() {
    Navigator.of(context).push(GameRoute(const OutOfLivesScreen()));
  }

  // ------------------------------------------------------------------ flow

  /// Manual restart: free while PLAYING. (While FAILED the board is covered
  /// by the rescue screen; if reached anyway it is charged as a retry.)
  void _restartBoard() {
    if (_session.isFailed) return _retryAfterFailure();
    _session.restart();
    _rebuildBoard();
  }

  void _replay() {
    _session.replay();
    _rebuildBoard();
  }

  void _rebuildBoard() {
    _monitor.reset();
    _game.restart();
    setState(() {
      _rescue = null;
      _won = false;
      _result = null;
    });
  }

  Future<void> _confirmRestart() async {
    if (_engine.moveCount == 0) return _restartBoard();
    final ok = await showGameDialog<bool>(
      context,
      title: 'BAŞTAN BAŞLA?',
      message: 'Bölüm ilk haline dönecek. Can kaybetmezsin.',
      actions: const [
        DialogAction('BAŞTAN BAŞLA', true, palette: ButtonPalette.purple),
        DialogAction('VAZGEÇ', false, palette: ButtonPalette.navy),
      ],
    );
    if (ok == true && mounted) _restartBoard();
  }

  void _leave() => Navigator.of(context).pop();

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
        _restartBoard();
      case _Exit.settings:
        await _openSettings();
      case _Exit.home:
        _leave();
      case _Exit.resume || null:
        break;
    }
  }

  // ------------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context);
    final rescue = _rescue;
    return Scaffold(
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
                    undos: p.undos,
                    shuffles: p.shuffles,
                    extraBottles: p.extraBottles,
                    canAddBottle: _engine.canAddBottle,
                    enabled: !_won,
                    onUndo: _undo,
                    onShuffle: _shuffle,
                    onExtraBottle: _extraBottle,
                    onRestart: _confirmRestart,
                  ),
                ],
              ),
            ),
            if (rescue != null && !_won)
              Positioned.fill(
                child: RescueOverlay(
                  key: ValueKey(_rescueEpoch),
                  status: rescue,
                  canUndo: _engine.canUndo && p.undos > 0,
                  canAddBottle: _engine.canAddBottle,
                  adReady: AppScope.adsOf(context).isReady(AdPlacement.rescue),
                  reduceMotion: p.reduceMotion,
                  onUndo: _applyUndo,
                  onCoinRescue: _coinRescue,
                  onAdRescue: _adRescue,
                  onRetry: _retryAfterFailure,
                  onOutOfLives: _openOutOfLives,
                  onHome: _leave,
                ),
              ),
            if (_result != null)
              Positioned.fill(
                child: LevelCompleteOverlay(
                  level: widget.level,
                  stars: _result!.stars,
                  coins: _result!.coins,
                  moves: _result!.moves,
                  reduceMotion: p.reduceMotion,
                  onReplay: _replay,
                ),
              ),
          ],
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
    required this.undos,
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
  final int undos;
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
              count: undos > 0 ? '$undos' : '+',
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
