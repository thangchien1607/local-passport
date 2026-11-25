import 'package:flutter/foundation.dart';

import 'maps_loader.dart';

/// Google Maps API key, truyền lúc build: `--dart-define=MAPS_API_KEY=...`.
/// Để trống thì app dùng bản đồ OpenStreetMap (OsmDiscoveryMap).
const mapsApiKey = String.fromEnvironment('MAPS_API_KEY');

var _ready = false;

/// true khi đã có key và SDK sẵn sàng → dùng GoogleDiscoveryMap.
bool get useGoogleMaps => _ready;

/// Gọi một lần trong main() trước runApp.
/// - Web: nạp Maps JS SDK bằng `MAPS_API_KEY` từ `--dart-define`.
/// - Android: nhận `MAPS_API_KEY` qua `build.gradle.kts` -> `AndroidManifest.xml`.
/// - iOS: nhận `MAPS_API_KEY` từ `ios/Flutter/Secrets.xcconfig` -> `Info.plist` -> `AppDelegate.swift`.
Future<void> initGoogleMaps() async {
  if (mapsApiKey.isEmpty) return;
  try {
    await loadMapsSdk(mapsApiKey);
    _ready = true;
  } catch (e) {
    debugPrint('Google Maps: $e — dùng bản đồ OpenStreetMap');
  }
}
