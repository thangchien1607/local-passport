import 'package:flutter/foundation.dart';

import 'maps_loader.dart';

/// Google Maps API key, truyền lúc build: `--dart-define=MAPS_API_KEY=...`.
/// Để trống thì app dùng bản đồ minh họa (DiscoveryMap) như cũ.
const mapsApiKey = String.fromEnvironment('MAPS_API_KEY');

var _ready = false;

/// true khi đã có key và SDK sẵn sàng → dùng GoogleDiscoveryMap.
bool get useGoogleMaps => _ready;

/// Gọi một lần trong main() trước runApp.
Future<void> initGoogleMaps() async {
  if (mapsApiKey.isEmpty) return;
  // iOS cần gọi GMSServices.provideAPIKey trong AppDelegate, chưa cấu hình
  // nên tạm dùng bản đồ minh họa.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) return;
  try {
    await loadMapsSdk(mapsApiKey);
    _ready = true;
  } catch (e) {
    debugPrint('Google Maps: $e — dùng bản đồ minh họa');
  }
}
