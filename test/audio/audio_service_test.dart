import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';


import 'package:ball_sort_party/audio/audio_service.dart';
import 'package:ball_sort_party/data/player_progress.dart';
import 'package:ball_sort_party/game/engine/ball_type.dart';
import 'package:ball_sort_party/game/flame/components/ball_component.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeBackend implements AudioBackend {
  final calls = <String>[];
  bool initThrows = false;
  final missing = <String>{};
  bool musicFails = false;
  bool throwOnPlay = false;
  double? musicVolume;

  @override
  Future<void> init() async {
    if (initThrows) throw StateError('bad audio session');
    calls.add('init');
  }
  @override
  Future<bool> preloadSfx(String asset) async => !missing.contains(asset);
  @override
  Future<void> playSfx(String asset, double volume) async {
    if (throwOnPlay) throw StateError('device error');
    calls.add('sfx:$asset@$volume');
  }

  @override
  Future<void> stopAllSfx() async => calls.add('sfx:stopAll');

  int volumeCalls = 0;

  @override
  Future<bool> startMusic(String asset, double volume) async {
    if (musicFails) return false;
    calls.add('music:start');
    musicVolume = volume;
    return true;
  }

  @override
  Future<void> setMusicVolume(double volume) async {
    volumeCalls++;
    musicVolume = volume;
  }
  @override
  Future<void> pauseMusic() async => calls.add('music:pause');
  @override
  Future<void> resumeMusic() async => calls.add('music:resume');
  @override
  Future<void> dispose() async {}

  int count(String prefix) => calls.where((c) => c.startsWith(prefix) && c != 'sfx:stopAll').length;
}

void main() {
  late DateTime now;
  late FakeBackend backend;
  late PlayerProgress progress;
  late AudioService audio;

  Future<void> setup({void Function(FakeBackend b)? configure}) async {
    SharedPreferences.setMockInitialValues({});
    progress = await PlayerProgress.load();
    backend = FakeBackend();
    configure?.call(backend);
    now = DateTime(2026);
    audio = AudioService(backend, progress, clock: () => now);
    await audio.init(observeLifecycle: false);
  }

  Future<void> flush() => Future<void>.delayed(Duration.zero);

  test('effects play with the configured volume', () async {
    await setup();
    progress.setSfxVolume(0.5);
    audio.play(Sfx.select);
    expect(backend.calls, contains('sfx:${AudioService.sfxAssets[Sfx.select]}@0.5'));
  });

  test('each ball type has its own landing sound', () async {
    await setup();
    for (final t in BallType.values) {
      audio.playLand(t);
    }
    expect(backend.count('sfx:'), BallType.values.length);
    expect(AudioService.landAssets.values.toSet().length, BallType.values.length);
  });

  test('no effect plays when effects are off', () async {
    await setup();
    progress.setSound(false);
    audio.play(Sfx.win);
    audio.playLand(BallType.tennis);
    expect(backend.count('sfx:'), 0);
  });

  test('the same effect is throttled when triggered too often', () async {
    await setup();
    audio.play(Sfx.button);
    audio.play(Sfx.button);
    now = now.add(const Duration(milliseconds: 30));
    audio.play(Sfx.button);
    expect(backend.count('sfx:'), 1);
    now = now.add(AudioService.minGap);
    audio.play(Sfx.button);
    expect(backend.count('sfx:'), 2);
  });

  test('music starts once and never twice', () async {
    await setup();
    expect(backend.count('music:start'), 1);
    progress.setMusicVolume(0.4); // settings change
    progress.setSfxVolume(0.2);
    await flush();
    expect(backend.count('music:start'), 1);
    expect(audio.isMusicPlaying, isTrue);
  });

  test('turning music off pauses it, turning on resumes it', () async {
    await setup();
    progress.setMusic(false);
    await flush();
    expect(backend.count('music:pause'), 1);
    expect(audio.isMusicPlaying, isFalse);
    progress.setMusic(true);
    await flush();
    expect(backend.count('music:resume'), 1);
    expect(backend.count('music:start'), 1);
  });

  test('music pauses in the background and resumes in the foreground', () async {
    await setup();
    await audio.handleLifecycle(AppLifecycleState.paused);
    expect(backend.count('music:pause'), 1);
    audio.play(Sfx.coin);
    expect(backend.count('sfx:'), 0, reason: 'no effects while backgrounded');
    await audio.handleLifecycle(AppLifecycleState.resumed);
    expect(backend.count('music:resume'), 1);
  });

  test('music stays paused on return if the player turned it off', () async {
    await setup();
    await audio.handleLifecycle(AppLifecycleState.paused);
    progress.setMusic(false);
    await audio.handleLifecycle(AppLifecycleState.resumed);
    expect(backend.count('music:resume'), 0);
  });

  test('game screen plays music quieter than the menu', () async {
    await setup();
    final menu = backend.musicVolume!;
    audio.setMood(MusicMood.game);
    await flush();
    expect(backend.musicVolume!, lessThan(menu));
  });

  test('missing files are reported and never crash', () async {
    await setup(configure: (b) {
      b.missing.add(AudioService.sfxAssets[Sfx.win]!);
      b.musicFails = true;
    });
    audio.play(Sfx.win);
    expect(backend.count('sfx:'), 0);
    expect(audio.missingAssets, contains(AudioService.sfxAssets[Sfx.win]));
    expect(audio.missingAssets, contains(AudioService.musicAsset));
  });

  test('backend errors are swallowed', () async {
    await setup(configure: (b) => b.throwOnPlay = true);
    expect(() => audio.play(Sfx.coin), returnsNormally);
  });

  test('disabled service never plays anything', () async {
    final silent = AudioService.disabled();
    await silent.init(observeLifecycle: false);
    expect(() => silent.play(Sfx.coin), returnsNormally);
    expect(silent.isMusicPlaying, isFalse);
  });

  test('all referenced audio assets exist on disk', () {
    final files = [AudioService.musicAsset, ...AudioService.sfxAssets.values, ...AudioService.landAssets.values];
    for (final f in files) {
      expect(File('assets/$f').existsSync(), isTrue, reason: f);
      expect(File('assets/$f').lengthSync(), greaterThan(1000), reason: '$f is not empty');
    }
  });

  test('a failing audio-session setup does not prevent loading sounds', () async {
    await setup(configure: (b) => b.initThrows = true);
    audio.play(Sfx.coin);
    expect(backend.count('sfx:'), 1);
    expect(audio.isMusicPlaying, isTrue);
  });

  test('bursts of different effects are capped (rapid moves)', () async {
    await setup();
    for (final t in BallType.values) {
      audio.playLand(t);
    }
    audio.play(Sfx.select);
    audio.play(Sfx.bottleComplete);
    expect(backend.count('sfx:'), AudioService.burstLimit);
    now = now.add(AudioService.burstWindow);
    audio.play(Sfx.select);
    expect(backend.count('sfx:'), AudioService.burstLimit + 1);
  });

  test('muting effects stops sounds that are already playing', () async {
    await setup();
    audio.play(Sfx.win);
    progress.setSound(false);
    await flush();
    expect(backend.calls, contains('sfx:stopAll'));
  });

  test('going to background stops effects and pauses music', () async {
    await setup();
    await audio.handleLifecycle(AppLifecycleState.inactive);
    expect(backend.calls, contains('sfx:stopAll'));
    expect(backend.count('music:pause'), 1);
    await audio.handleLifecycle(AppLifecycleState.hidden);
    await audio.handleLifecycle(AppLifecycleState.paused);
    expect(backend.count('music:pause'), 1, reason: 'pause only once');
  });

  test('frequent progress saves never restart music or spam volume calls', () async {
    await setup();
    final before = backend.volumeCalls;
    for (var i = 0; i < 50; i++) {
      progress.addCoins(1); // e.g. saves after every move
    }
    await flush();
    expect(backend.count('music:start'), 1);
    expect(backend.volumeCalls, before);
  });

  test('music and effect volumes are independent', () async {
    await setup();
    progress.setMusicVolume(0.2);
    await flush();
    final music = backend.musicVolume;
    progress.setSfxVolume(0.9);
    await flush();
    expect(backend.musicVolume, music);
    audio.play(Sfx.coin);
    expect(backend.calls.last, endsWith('@0.9'));
  });

  test('landing sound rebounds line up with the bounce animation', () {
    // Rebound offsets baked into tool/gen_audio.dart (seconds after impact).
    const baked = {
      BallType.basketball: [0.24, 0.38],
      BallType.football: [0.2],
      BallType.baseball: [0.08],
      BallType.tennis: [0.15, 0.245, 0.31],
      BallType.volleyball: [0.22],
    };
    for (final type in BallType.values) {
      final p = LandingProfile.byType[type]!;
      final impacts = <double>[];
      var t = 0.0;
      for (final h in p.bounces) {
        t += p.bounceTime * math.sqrt(h / p.bounces.first);
        impacts.add(t);
      }
      expect(impacts.length, baked[type]!.length, reason: '$type');
      for (var i = 0; i < impacts.length; i++) {
        expect(impacts[i], closeTo(baked[type]![i], 0.025), reason: '$type rebound $i');
      }
    }
  });

  test('music loop is seamless at the wrap point', () {
    final bytes = File('assets/${AudioService.musicAsset}').readAsBytesSync();
    final data = ByteData.sublistView(bytes, 44);
    final n = data.lengthInBytes ~/ 2;
    int sample(int i) => data.getInt16(i * 2, Endian.little);
    var sum = 0;
    for (var i = 0; i < n - 1; i++) {
      sum += (sample(i + 1) - sample(i)).abs();
    }
    final typicalStep = sum / (n - 1);
    final seam = (sample(0) - sample(n - 1)).abs();
    expect(seam, lessThan(typicalStep * 2), reason: 'no click when looping');
    expect(n / 22050, closeTo(38.4, 0.01), reason: 'exactly 16 bars at 100 BPM');
  });
}
