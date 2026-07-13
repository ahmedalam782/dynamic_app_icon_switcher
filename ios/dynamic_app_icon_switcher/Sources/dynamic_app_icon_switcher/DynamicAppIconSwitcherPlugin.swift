import Flutter
import UIKit

/// Switches the home-screen icon via `UIApplication.setAlternateIconName`.
public class DynamicAppIconSwitcherPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "dynamic_app_icon_switcher",
      binaryMessenger: registrar.messenger()
    )
    let instance = DynamicAppIconSwitcherPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "supportsAlternateIcons":
      result(UIApplication.shared.supportsAlternateIcons)

    case "getAvailableIcons":
      result(Self.alternateIconNames())

    case "currentIcon":
      result(UIApplication.shared.alternateIconName ?? "default")

    case "setIcon":
      guard let args = call.arguments as? [String: Any],
            let iconName = args["iconName"] as? String,
            !iconName.isEmpty
      else {
        result(
          FlutterError(
            code: "ICON_NOT_FOUND",
            message: "iconName must not be empty.",
            details: nil
          )
        )
        return
      }

      guard UIApplication.shared.supportsAlternateIcons else {
        result(
          FlutterError(
            code: "PLATFORM_NOT_SUPPORTED",
            message: "Alternate icons are not supported on this device.",
            details: nil
          )
        )
        return
      }

      let normalized = iconName.lowercased() == "default" ? nil : iconName

      if let name = normalized {
        let known = Self.alternateIconNames()
        if !known.contains(name) {
          result(
            FlutterError(
              code: "ICON_NOT_FOUND",
              message:
                "No CFBundleAlternateIcons entry found for '\(name)'. Declared: \(known)",
              details: nil
            )
          )
          return
        }
      }

      UIApplication.shared.setAlternateIconName(normalized) { error in
        if let error = error {
          result(
            FlutterError(
              code: "SET_ICON_FAILED",
              message: error.localizedDescription,
              details: nil
            )
          )
        } else {
          result(nil)
        }
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Reads alternate icon keys from the main bundle's Info.plist.
  private static func alternateIconNames() -> [String] {
    guard
      let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
      let alternate = icons["CFBundleAlternateIcons"] as? [String: Any]
    else {
      return []
    }
    return Array(alternate.keys).sorted()
  }
}
