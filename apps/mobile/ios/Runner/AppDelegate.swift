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
    let channel = FlutterMethodChannel(name: "org.musiclink.prototype/preferences", binaryMessenger: engineBridge.applicationRegistrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard let preferences = UserDefaults(suiteName: "group.org.musiclink.prototype") else {
        result(FlutterError(code: "preferences", message: "Einstellungen nicht verfügbar", details: nil))
        return
      }
      switch call.method {
      case "getPreferences":
        result(["target": preferences.string(forKey: "target") ?? "appleMusic", "shareSetupSeen": preferences.bool(forKey: "shareSetupSeen") ? "true" : "false"])
      // Friends, groups and the own invite as one JSON string, shared with the share extension
      case "getSocial":
        result(preferences.string(forKey: "social"))
      case "setSocial":
        guard let value = call.arguments as? String else { result(FlutterMethodNotImplemented); return }
        preferences.set(value, forKey: "social")
        result(nil)
      case "dismissShareSetup":
        preferences.set(true, forKey: "shareSetupSeen")
        result(nil)
      case "setPreferences":
        guard let values = call.arguments as? [String: String] else { result(FlutterMethodNotImplemented); return }
        preferences.set(values["target"], forKey: "target")
        result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }
}
