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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "MegrimShortcuts") {
      MegrimShortcuts.register(with: registrar)
    }
  }
}

/// The app-icon "Log migraine" shortcut (backlog #23, step 1), declared in Info.plist under
/// UIApplicationShortcutItems. Same channel and messages as MainActivity on Android: Dart asks
/// for the launching shortcut with "initialAction", and a shortcut used while running is pushed
/// as "action". Dart decides when to act on it (foreground, and unlocked if app lock is on).
/// Scene hooks follow Flutter's own quick_actions_ios plugin.
final class MegrimShortcuts: NSObject, FlutterPlugin, FlutterSceneLifeCycleDelegate {
  private static let logMigraineType = "org.maegley.megrim.log_migraine"
  private let channel: FlutterMethodChannel
  /// A shortcut that launched the app, until Dart (or sceneDidBecomeActive) collects it.
  private var launching: String?

  init(channel: FlutterMethodChannel) {
    self.channel = channel
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "org.maegley.megrim/shortcut", binaryMessenger: registrar.messenger())
    let instance = MegrimShortcuts(channel: channel)
    registrar.addMethodCallDelegate(instance, channel: channel)
    registrar.addApplicationDelegate(instance)
    registrar.addSceneDelegate(instance)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "initialAction" {
      result(launching)
      launching = nil
    } else {
      result(FlutterMethodNotImplemented)
    }
  }

  private static func action(for type: String) -> String? {
    type == logMigraineType ? "log_migraine" : nil
  }

  private func push(_ type: String) {
    if let action = MegrimShortcuts.action(for: type) {
      channel.invokeMethod("action", arguments: action)
    }
  }

  // Cold start: hold the shortcut. Dart's "initialAction" usually collects it; if Dart hasn't by
  // the time the scene is active, push it instead. Whichever comes first clears it.
  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    guard let item = connectionOptions?.shortcutItem else { return false }
    launching = MegrimShortcuts.action(for: item.type)
    return launching != nil
  }

  func sceneDidBecomeActive(_ scene: UIScene) {
    if let pending = launching {
      launching = nil
      channel.invokeMethod("action", arguments: pending)
    }
  }

  // While running.
  func windowScene(
    _ windowScene: UIWindowScene,
    performActionFor shortcutItem: UIApplicationShortcutItem,
    completionHandler: @escaping (Bool) -> Void
  ) -> Bool {
    push(shortcutItem.type)
    completionHandler(true)
    return true
  }

  // Pre-scene fallbacks, as quick_actions_ios keeps them.
  func application(
    _ application: UIApplication,
    performActionFor shortcutItem: UIApplicationShortcutItem,
    completionHandler: @escaping (Bool) -> Void
  ) -> Bool {
    push(shortcutItem.type)
    completionHandler(true)
    return true
  }
}
