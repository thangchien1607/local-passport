import Flutter
import UIKit
#if canImport(GoogleMaps)
import GoogleMaps
#endif

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    #if canImport(GoogleMaps)
    if let rawKey = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String {
      let apiKey = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
      if !apiKey.isEmpty && apiKey != "YOUR_IOS_GOOGLE_MAPS_API_KEY" && !apiKey.hasPrefix("$(") {
        GMSServices.provideAPIKey(apiKey)
      }
    }
    #endif
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
