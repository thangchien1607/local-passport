import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_passport/services/maps_config.dart';

void main() {
  test('Không truyền MAPS_API_KEY thì dùng bản đồ OpenStreetMap', () async {
    await initGoogleMaps();
    expect(mapsApiKey, isEmpty);
    expect(useGoogleMaps, isFalse);
  });

  test(
    'Cấu hình MAPS_API_KEY cho iOS dùng xcconfig mẫu và bỏ qua file bí mật trong gitignore',
    () {
      expect(File('ios/Flutter/Secrets.xcconfig.example').existsSync(), isTrue);
      expect(File('ios/Flutter/Secrets.xcconfig').existsSync(), isFalse);

      final gitignore = File('.gitignore').readAsStringSync();
      expect(gitignore, contains('ios/Flutter/Secrets.xcconfig'));

      final debugCfg = File('ios/Flutter/Debug.xcconfig').readAsStringSync();
      final releaseCfg = File(
        'ios/Flutter/Release.xcconfig',
      ).readAsStringSync();
      expect(debugCfg, contains('#include? "Secrets.xcconfig"'));
      expect(releaseCfg, contains('#include? "Secrets.xcconfig"'));

      final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(infoPlist, contains('<key>GMSApiKey</key>'));
      expect(infoPlist, contains(r'$(MAPS_API_KEY)'));

      final appDelegate = File(
        'ios/Runner/AppDelegate.swift',
      ).readAsStringSync();
      expect(appDelegate, contains('GMSServices.provideAPIKey'));
    },
  );
}
