import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "GaplessMusicPlugin") {
      GaplessMusicPlugin.register(with: registrar)
    }
  }
}

/// Gapless background-music loop for iOS.
///
/// audioplayers loops on iOS by waiting for AVPlayerItemDidPlayToEndTime and
/// then seeking back to 0, which leaves an audible gap at every loop point.
/// AVAudioPlayer with numberOfLoops = -1 loops PCM audio sample-accurately
/// inside the audio engine, with no round trip. The shared AVAudioSession
/// (ambient category, configured from Dart) is respected.
final class GaplessMusicPlugin: NSObject, FlutterPlugin {
  private let registrar: FlutterPluginRegistrar
  private var player: AVAudioPlayer?

  init(registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "ball_sort_party/gapless_music",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(GaplessMusicPlugin(registrar: registrar), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "start":
      guard let asset = args["asset"] as? String else { return result(false) }
      let key = registrar.lookupKey(forAsset: asset)
      guard let path = Bundle.main.path(forResource: key, ofType: nil) else { return result(false) }
      do {
        player?.stop()
        let p = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
        p.numberOfLoops = -1
        p.volume = Float(args["volume"] as? Double ?? 1)
        p.prepareToPlay()
        p.play()
        player = p
        result(true)
      } catch {
        result(false)
      }
    case "setVolume":
      player?.volume = Float(args["volume"] as? Double ?? 1)
      result(nil)
    case "pause":
      player?.pause()
      result(nil)
    case "resume":
      player?.play()
      result(nil)
    case "stop":
      player?.stop()
      player = nil
      result(nil)
    case "seek":  // diagnostics: jump close to the loop point
      player?.currentTime = args["seconds"] as? Double ?? 0
      result(nil)
    case "status":
      result([
        "playing": player?.isPlaying ?? false,
        "position": player?.currentTime ?? 0,
        "duration": player?.duration ?? 0,
        "loops": player?.numberOfLoops ?? 0,
      ])
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
