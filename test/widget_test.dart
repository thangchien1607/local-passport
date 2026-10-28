import 'package:flutter_test/flutter_test.dart';
import 'package:local_passport/data/routes.dart';
import 'package:local_passport/services/geo.dart';

void main() {
  test('parseQr đọc đúng mã của di tích', () {
    final qr = parseQr(qrPayloadFor(locations.first));
    expect(qr?.locationId, locations.first.id);
    expect(qr?.secret, locations.first.qrCodeSecret);
    expect(parseQr('https://example.com'), isNull);
    final legacy = parseQr('LOCALPASSPORT|dien-hai|DH-1813');
    expect(legacy?.locationId, 'dien-hai');
    expect(
      parseQr(qrPayloadFor(locations[4]))?.secret,
      locations[4].qrCodeSecret,
    );
  });

  test('rankForXp', () {
    expect(rankForXp(0).current.title, 'Tân binh');
    expect(rankForXp(398).current.title, 'Nhà thám hiểm');
    expect(rankForXp(900).next, isNull);
  });
}
