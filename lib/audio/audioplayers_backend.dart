import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import 'audio_service.dart';

/// [AudioBackend] built on the `audioplayers` package (iOS + Android).
/// All assets are bundled, so audio works offline.
class AudioplayersBackend implements AudioBackend {
  final Map<String, AudioPool> _pools = {};
  AudioPlayer? _music;

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
      _pools[asset] = await AudioPool.createFromAsset(path: asset, maxPlayers: 3);
      return true;
    } catch (_) {
      return false; // unplayable file
    }
  }

  @override
  Future<void> playSfx(String asset, double volume) async {
    await _pools[asset]?.start(volume: volume);
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
