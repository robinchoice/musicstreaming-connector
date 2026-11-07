import Flutter
import Intents
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Friends as "friend:<name>", groups as "group:<name>" with their members, see ShareModel.pick(conversation:)
  private static func conversations(_ json: String?) -> [String: [String]] {
    guard let data = json?.data(using: .utf8),
          let social = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return [:] }
    var result: [String: [String]] = [:]
    for friend in social["friends"] as? [[String: Any]] ?? [] {
      if let name = friend["name"] as? String { result["friend:\(name)"] = [name] }
    }
    for group in social["groups"] as? [[String: Any]] ?? [] {
      if let name = group["name"] as? String { result["group:\(name)"] = group["members"] as? [String] ?? [] }
    }
    return result
  }

  // The same as donate in the share extension's ShareViewController
  private static func donate(_ id: String, names: [String]) {
    let recipients = names.map {
      INPerson(personHandle: INPersonHandle(value: "friend:\($0)", type: .unknown), nameComponents: nil, displayName: $0, image: nil, contactIdentifier: nil, customIdentifier: "friend:\($0)")
    }
    let group = id.hasPrefix("group:") ? INSpeakableString(spokenPhrase: String(id.dropFirst("group:".count))) : nil
    let intent = INSendMessageIntent(recipients: recipients, outgoingMessageType: .outgoingMessageText, content: nil, speakableGroupName: group, conversationIdentifier: id, serviceName: nil, sender: nil, attachments: nil)
    let interaction = INInteraction(intent: intent, response: nil)
    interaction.direction = .outgoing
    interaction.groupIdentifier = id
    interaction.donate(completion: nil)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(name: "org.musiclink.prototype/preferences", binaryMessenger: engineBridge.applicationRegistrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard let preferences = UserDefaults(suiteName: "group.org.musiclink.prototype") else {
        result(FlutterError(code: "preferences", message: "Preferences unavailable", details: nil))
        return
      }
      switch call.method {
      case "getPreferences":
        result(["target": preferences.string(forKey: "target") ?? "appleMusic", "shareSetupSeen": preferences.bool(forKey: "shareSetupSeen") ? "true" : "false"])
      // Friends, groups and the own invite as one JSON string, shared with the share extension
      case "getSocial":
        // Friends saved before the share sheet suggestions existed are suggested once
        if !preferences.bool(forKey: "suggestionsDonated") {
          for (id, names) in Self.conversations(preferences.string(forKey: "social")) { Self.donate(id, names: names) }
          preferences.set(true, forKey: "suggestionsDonated")
        }
        result(preferences.string(forKey: "social"))
      case "setSocial":
        guard let value = call.arguments as? String else { result(FlutterMethodNotImplemented); return }
        let before = Self.conversations(preferences.string(forKey: "social"))
        preferences.set(value, forKey: "social")
        let after = Self.conversations(value)
        // New friends and groups appear among the share sheet's suggestions, removed ones leave
        for id in before.keys where after[id] == nil { INInteraction.delete(with: id, completion: nil) }
        for (id, names) in after where before[id] == nil { Self.donate(id, names: names) }
        result(nil)
      // Whether the bug button shows, nil until someone flips the switch
      case "getTestMode":
        result(preferences.object(forKey: "testMode") as? Bool)
      case "setTestMode":
        guard let value = call.arguments as? Bool else { result(FlutterMethodNotImplemented); return }
        preferences.set(value, forKey: "testMode")
        result(nil)
      // The chosen language, nil until someone switches it. The share extension reads it too.
      case "getLocale":
        result(preferences.string(forKey: "locale"))
      case "setLocale":
        guard let value = call.arguments as? String else { result(FlutterMethodNotImplemented); return }
        preferences.set(value, forKey: "locale")
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
