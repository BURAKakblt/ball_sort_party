import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import 'audio_service.dart';

/// [AudioBackend] built on the `audioplayers` package (iOS + Android).
/// All assets are bundled, so audio works offline.
class AudioplayersBackend implements AudioBackend {
  final Map<String, AudioPool> _pools = {};
  AudioPlayer? _music;

  /// Copies of one effect allowed to sound at once. AudioPool itself would
  /// create unlimited players when busy, so rapid moves are capped here.
  static const maxVoicesPerSound = 3;
  final Map<String, int> _voices = {};
  final Map<String, Duration> _durations = {};
  final Set<Future<void> Function()> _stops = {};

  @override
  Future<void> init() async {
    // Like most casual games: mix with other apps' audio and, on iOS,
    // respect the silent switch (the "ambient" session category).
    await AudioPlayer.global.setAudioContext(
      AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers)
          .build()
          .copy(iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient)),
    );
  }

  Future<bool> _exists(String asset) async {
    try {
      await rootBundle.load('assets/$asset');
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> preloadSfx(String asset) async {
    if (!await _exists(asset)) return false;
    try {
      final pool = await AudioPool.createFromAsset(path: asset, maxPlayers: maxVoicesPerSound);
      _pools[asset] = pool;
      _durations[asset] = await pool.getDuration() ?? const Duration(milliseconds: 2500);
      return true;
    } catch (_) {
      return false; // unplayable file
    }
  }

  @override
  Future<void> playSfx(String asset, double volume) async {
    final pool = _pools[asset];
    if (pool == null || (_voices[asset] ?? 0) >= maxVoicesPerSound) return;
    _voices[asset] = (_voices[asset] ?? 0) + 1;
    try {
      final stop = await pool.start(volume: volume);
      _stops.add(stop);
      // Release the voice slot when this clip has finished.
      final length = _durations[asset] ?? const Duration(milliseconds: 2500);
      Future<void>.delayed(length + const Duration(milliseconds: 50), () {
        _stops.remove(stop);
        _voices[asset] = ((_voices[asset] ?? 1) - 1).clamp(0, maxVoicesPerSound);
      });
    } catch (_) {
      _voices[asset] = ((_voices[asset] ?? 1) - 1).clamp(0, maxVoicesPerSound);
      rethrow;
    }
  }

  @override
  Future<void> stopAllSfx() async {
    final stops = _stops.toList();
    _stops.clear();
    for (final stop in stops) {
      await stop();
    }
  }

  @override
  Future<bool> startMusic(String asset, double volume) async {
    if (!await _exists(asset)) return false;
    final player = _music ??= AudioPlayer(playerId: 'music');
    await player.setReleaseMode(ReleaseMode.loop);
    await player.setVolume(volume);
    await player.play(AssetSource(asset));
    return true;
  }

  @override
  Future<void> setMusicVolume(double volume) async => _music?.setVolume(volume);

  @override
  Future<void> pauseMusic() async => _music?.pause();

  @override
  Future<void> resumeMusic() async => _music?.resume();

  @override
  Future<void> dispose() async {
    for (final pool in _pools.values) {
      await pool.dispose();
    }
    await _music?.dispose();
  }
}
