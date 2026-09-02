import Flutter
import UIKit

/// iOS stub: Play Install Referrer is Android-only. Always returns nil (silent no-op).
public class FlinkuSdkPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "flinku_sdk/install_referrer",
      binaryMessenger: registrar.messenger()
    )
    let instance = FlinkuSdkPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    // Silent no-op on every method, including getInstallReferrer.
    result(nil)
  }
}
