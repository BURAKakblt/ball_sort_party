import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Dart side of the iOS `GaplessMusicPlugin` (ios/Runner/AppDelegate.swift).
///
/// Used only on iOS, where audioplayers' loop restarts the track with a
/// seek after it ended (audible gap). Every call fails soft: [start] returns
/// false when the native side is missing so the caller can fall back.
class GaplessMusic {
  GaplessMusic({MethodChannel? channel, bool? enabled})
    : _channel = channel ?? const MethodChannel('ball_sort_party/gapless_music'),
      enabled = enabled ?? (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS);

  final MethodChannel _channel;

  /// Whether to try the native player at all on this platform.
  final bool enabled;

  bool _active = false;

  /// True once the native player is playing the music.
  bool get isActive => _active;

  /// Starts looping [asset] (relative to `assets/`). False → use a fallback.
  Future<bool> start(String asset, double volume) async {
    if (!enabled) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('start', {
        'asset': 'assets/$asset',
        'volume': volume,
      });
      _active = ok ?? false;
    } on MissingPluginException {
      _active = false;
    } on PlatformException {
      _active = false;
    }
    return _active;
  }

  Future<void> setVolume(double volume) => _call('setVolume', {'volume': volume});
  Future<void> pause() => _call('pause');
  Future<void> resume() => _call('resume');

  Future<void> stop() async {
    await _call('stop');
    _active = false;
  }

  /// Diagnostics (simulator checks): playing flag, position, duration, loops.
  Future<Map<Object?, Object?>?> status() async {
    if (!_active) return null;
    return _channel.invokeMethod<Map<Object?, Object?>>('status');
  }

  /// Diagnostics: jump to [seconds].
  Future<void> seek(double seconds) => _call('seek', {'seconds': seconds});

  Future<void> _call(String method, [Map<String, Object?>? args]) async {
    if (!_active) return;
    try {
      await _channel.invokeMethod<void>(method, args);
    } on MissingPluginException {
      _active = false;
    } on PlatformException {
      // Ignore: music is non-critical.
    }
  }
}
