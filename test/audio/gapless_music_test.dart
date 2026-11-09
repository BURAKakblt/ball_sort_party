import 'package:ball_sort_party/audio/gapless_music.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('ball_sort_party/gapless_music');
  final calls = <MethodCall>[];

  void mockNative(Object? Function(MethodCall call)? handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      handler == null ? null : (call) async {
        calls.add(call);
        return handler(call);
      },
    );
  }

  setUp(calls.clear);
  tearDown(() => mockNative(null));

  test('iOS: music goes through the native gapless player', () async {
    mockNative((c) => c.method == 'start' ? true : null);
    final g = GaplessMusic(channel: channel, enabled: true);
    expect(await g.start('audio/music/party_loop.wav', 0.3), isTrue);
    await g.setVolume(0.1);
    await g.pause();
    await g.resume();
    expect(calls.map((c) => c.method), ['start', 'setVolume', 'pause', 'resume']);
    expect(calls.first.arguments, {'asset': 'assets/audio/music/party_loop.wav', 'volume': 0.3});
  });

  test('missing native side → start returns false (caller falls back)', () async {
    mockNative(null); // no handler: MissingPluginException
    final g = GaplessMusic(channel: channel, enabled: true);
    expect(await g.start('audio/music/party_loop.wav', 0.3), isFalse);
    expect(g.isActive, isFalse);
    await g.pause(); // no-op, no throw
  });

  test('native error → falls back without crashing', () async {
    mockNative((c) => throw PlatformException(code: 'boom'));
    final g = GaplessMusic(channel: channel, enabled: true);
    expect(await g.start('audio/music/party_loop.wav', 0.3), isFalse);
  });

  test('other platforms never call the native channel', () async {
    mockNative((c) => true);
    final g = GaplessMusic(channel: channel, enabled: false);
    expect(await g.start('audio/music/party_loop.wav', 0.3), isFalse);
    expect(calls, isEmpty);
  });
}
