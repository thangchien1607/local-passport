import 'package:flutter_test/flutter_test.dart';
import 'package:local_passport/services/maps_config.dart';

void main() {
  test('Không truyền MAPS_API_KEY thì dùng bản đồ minh họa', () async {
    await initGoogleMaps();
    expect(mapsApiKey, isEmpty);
    expect(useGoogleMaps, isFalse);
  });
}
