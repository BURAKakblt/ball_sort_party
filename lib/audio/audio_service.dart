import 'package:flutter/widgets.dart';

import '../data/player_progress.dart';
import '../game/engine/ball_type.dart';

/// One-shot sound effects.
enum Sfx {
  select,
  invalid,
  button,
  bottleComplete,
  win,
  lose,
  giftOpen,
  coin,
  life,
  purchase,
}

/// Where the player is; the game screen plays music quieter.
enum MusicMood { menu, game }

/// Platform audio operations. Swappable so the service can be unit tested.
abstract interface class AudioBackend {
  Future<void> init();

  /// Prepares an effect. Returns false if the asset is missing/unplayable.
  Future<bool> preloadSfx(String asset);
  Future<void> playSfx(String asset, double volume);

  /// Stops every effect that is currently sounding.
  Future<void> stopAllSfx();

  /// Starts looping [asset]. Returns false if it could not be played.
  Future<bool> startMusic(String asset, double volume);
  Future<void> setMusicVolume(double volume);
  Future<void> pauseMusic();
  Future<void> resumeMusic();
  Future<void> dispose();
}

/// Backend that does nothing (tests, or when audio is unavailable).
class NoopAudioBackend implements AudioBackend {
  @override
  Future<void> init() async {}
  @override
  Future<bool> preloadSfx(String asset) async => true;
  @override
  Future<void> playSfx(String asset, double volume) async {}
  @override
  Future<void> stopAllSfx() async {}
  @override
  Future<bool> startMusic(String asset, double volume) async => true;
  @override
  Future<void> setMusicVolume(double volume) async {}
  @override
  Future<void> pauseMusic() async {}
  @override
  Future<void> resumeMusic() async {}
  @override
  Future<void> dispose() async {}
}

enum _MusicState { stopped, playing, paused }

/// Central sound manager: separate music/effects channels, user settings,
/// throttling of repeated effects and pausing music in the background.
class AudioService with WidgetsBindingObserver {
  AudioService(this._backend, this._progress, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  /// Service that never plays anything.
  factory AudioService.disabled() => AudioService(NoopAudioBackend(), null);

  static const musicAsset = 'audio/music/party_loop.wav';

  static const sfxAssets = {
    Sfx.select: 'audio/sfx/select.wav',
    Sfx.invalid: 'audio/sfx/invalid.wav',
    Sfx.button: 'audio/sfx/button.wav',
    Sfx.bottleComplete: 'audio/sfx/bottle_complete.wav',
    Sfx.win: 'audio/sfx/win.wav',
    Sfx.lose: 'audio/sfx/lose.wav',
    Sfx.giftOpen: 'audio/sfx/gift_open.wav',
    Sfx.coin: 'audio/sfx/coin.wav',
    Sfx.life: 'audio/sfx/life.wav',
    Sfx.purchase: 'audio/sfx/purchase.wav',
  };

  static const landAssets = {
    BallType.basketball: 'audio/sfx/land_basketball.wav',
    BallType.football: 'audio/sfx/land_football.wav',
    BallType.baseball: 'audio/sfx/land_baseball.wav',
    BallType.tennis: 'audio/sfx/land_tennis.wav',
    BallType.volleyball: 'audio/sfx/land_volleyball.wav',
  };

  /// Single-impact landings used with "reduce motion": the ball doesn't
  /// rebound visually, so the sound has no rebound taps either.
  static const landSingleAssets = {
    BallType.basketball: 'audio/sfx/land_basketball_single.wav',
    BallType.football: 'audio/sfx/land_football_single.wav',
    BallType.baseball: 'audio/sfx/land_baseball_single.wav',
    BallType.tennis: 'audio/sfx/land_tennis_single.wav',
    BallType.volleyball: 'audio/sfx/land_volleyball_single.wav',
  };

  /// Minimum gap between two plays of the same effect.
  static const minGap = Duration(milliseconds: 70);

  /// At most [burstLimit] effects may start within [burstWindow]; extra
  /// ones are dropped so rapid play never piles up sounds.
  static const burstLimit = 5;
  static const burstWindow = Duration(milliseconds: 250);

  /// Music volume multiplier per mood.
  static const moodVolume = {MusicMood.menu: 0.55, MusicMood.game: 0.3};

  final AudioBackend _backend;
  final PlayerProgress? _progress;
  final DateTime Function() _now;

  final Map<String, DateTime> _lastPlayed = {};
  final List<DateTime> _recent = [];
  double? _appliedMusicVolume;
  bool _sfxWasEnabled = false;
  final Set<String> _missing = {};
  _MusicState _music = _MusicState.stopped;
  MusicMood _mood = MusicMood.menu;
  bool _foreground = true;
  bool _initialized = false;
  bool _musicMissing = false;

  /// Assets that failed to load (shown in settings).
  List<String> get missingAssets => List.unmodifiable([
    ..._missing,
    if (_musicMissing) musicAsset,
  ]);

  bool get isMusicPlaying => _music == _MusicState.playing;
  MusicMood get mood => _mood;

  bool get _sfxEnabled => (_progress?.soundOn ?? false) && (_progress?.sfxVolume ?? 0) > 0;
  bool get _musicEnabled => (_progress?.musicOn ?? false) && (_progress?.musicVolume ?? 0) > 0;
  double get _musicVolume => (_progress?.musicVolume ?? 0) * moodVolume[_mood]!;

  Future<void> init({bool observeLifecycle = true}) async {
    if (_initialized) return;
    _initialized = true;
    // Each step is guarded separately: one failure must not silence the rest.
    await _guard(_backend.init);
    for (final asset in [...sfxAssets.values, ...landAssets.values, ...landSingleAssets.values]) {
      if (!await _guardResult(() => _backend.preloadSfx(asset))) _missing.add(asset);
    }
    if (_missing.isNotEmpty) debugPrint('AudioService: missing sounds $_missing');
    if (observeLifecycle) WidgetsBinding.instance.addObserver(this);
    _progress?.addListener(_applySettings);
    await _applySettings();
  }

  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    _progress?.removeListener(_applySettings);
    await _guard(_backend.dispose);
  }

  void play(Sfx sfx) => _playAsset(sfxAssets[sfx]!);

  /// Landing sound for [type], matching the current animation style.
  void playLand(BallType type) {
    final reduced = _progress?.reduceMotion ?? false;
    _playAsset((reduced ? landSingleAssets : landAssets)[type]!);
  }

  void _playAsset(String asset) {
    if (!_initialized || !_sfxEnabled || !_foreground || _missing.contains(asset)) return;
    final now = _now();
    final last = _lastPlayed[asset];
    if (last != null && now.difference(last) < minGap) return;
    _recent.removeWhere((t) => now.difference(t) >= burstWindow);
    if (_recent.length >= burstLimit) return;
    _recent.add(now);
    _lastPlayed[asset] = now;
    _guard(() => _backend.playSfx(asset, _progress!.sfxVolume));
  }

  void setMood(MusicMood mood) {
    if (_mood == mood) return;
    _mood = mood;
    if (_music == _MusicState.playing) _setMusicVolume();
  }

  /// Only talks to the platform when the volume actually changed.
  Future<void> _setMusicVolume() async {
    final v = _musicVolume;
    if (v == _appliedMusicVolume) return;
    _appliedMusicVolume = v;
    await _guard(() => _backend.setMusicVolume(v));
  }

  Future<void> _applySettings() async {
    if (!_initialized) return;
    // Muting effects (or leaving the app) silences sounds already playing.
    final sfxOn = _sfxEnabled && _foreground;
    if (_sfxWasEnabled && !sfxOn) await _guard(_backend.stopAllSfx);
    _sfxWasEnabled = sfxOn;
    final shouldPlay = _musicEnabled && _foreground && !_musicMissing;
    switch ((_music, shouldPlay)) {
      case (_MusicState.stopped, true):
        _music = _MusicState.playing; // set first: never start twice
        _appliedMusicVolume = _musicVolume;
        final ok = await _guardResult(() => _backend.startMusic(musicAsset, _musicVolume));
        if (!ok) {
          _musicMissing = true;
          _music = _MusicState.stopped;
        }
      case (_MusicState.paused, true):
        _music = _MusicState.playing;
        await _setMusicVolume();
        await _guard(_backend.resumeMusic);
      case (_MusicState.playing, true):
        await _setMusicVolume();
      case (_MusicState.playing, false):
        _music = _MusicState.paused;
        await _guard(_backend.pauseMusic);
      default:
        break;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    handleLifecycle(state);
  }

  /// Pauses music when the app leaves the foreground, resumes on return.
  @visibleForTesting
  Future<void> handleLifecycle(AppLifecycleState state) async {
    _foreground = state == AppLifecycleState.resumed;
    await _applySettings();
  }

  Future<void> _guard(Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      debugPrint('AudioService error: $e');
    }
  }

  Future<bool> _guardResult(Future<bool> Function() f) async {
    try {
      return await f();
    } catch (e) {
      debugPrint('AudioService error: $e');
      return false;
    }
  }
}
