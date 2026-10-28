import 'dart:math';

import 'package:geolocator/geolocator.dart';

import '../data/routes.dart';

/// Bán kính chấp nhận khi check-in tại di tích.
const checkinRadiusM = 300.0;

/// Khoảng cách Haversine (mét) giữa 2 tọa độ.
double distanceMeters(LatLng a, LatLng b) {
  const r = 6371000.0;
  double rad(double d) => d * pi / 180;
  final dLat = rad(b.lat - a.lat);
  final dLng = rad(b.lng - a.lng);
  final h =
      pow(sin(dLat / 2), 2) +
      cos(rad(a.lat)) * cos(rad(b.lat)) * pow(sin(dLng / 2), 2);
  return 2 * r * asin(sqrt(h));
}

String formatDistance(double m) =>
    m < 1000 ? '${m.round()} m' : '${(m / 1000).toStringAsFixed(1)} km';

Future<LatLng> currentPosition() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw Exception('Dịch vụ định vị đang tắt.');
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    throw Exception('Bạn chưa cho phép truy cập vị trí.');
  }
  try {
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
    return LatLng(pos.latitude, pos.longitude);
  } catch (_) {
    throw Exception('Không lấy được vị trí, hãy thử lại.');
  }
}

/// Đã được cấp quyền vị trí chưa — chỉ kiểm tra, không bật hộp thoại xin quyền.
Future<bool> hasLocationPermission() async {
  try {
    final p = await Geolocator.checkPermission();
    return p == LocationPermission.always || p == LocationPermission.whileInUse;
  } catch (_) {
    return false;
  }
}

/// Theo dõi vị trí liên tục cho chấm "Bạn ở đây" trên bản đồ.
Stream<LatLng> watchPosition() => Geolocator.getPositionStream(
  locationSettings: const LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10,
  ),
).map((p) => LatLng(p.latitude, p.longitude));

/// Địa chỉ bản web đã deploy — mã QR trỏ về đây để quét bằng camera thường cũng mở được app.
const appUrl = 'https://local-passport-danang.web.app/';

/// Đọc mã QR dán tại di tích. Chấp nhận 2 dạng:
/// - Link: `https://…/?checkin=<locationId>&k=<qrCodeSecret>` (dạng in trên bảng QR)
/// - Chuỗi cũ: `LOCALPASSPORT|<locationId>|<qrCodeSecret>`
({String locationId, String secret})? parseQr(String text) {
  final uri = Uri.tryParse(text.trim());
  if (uri != null && uri.hasScheme && uri.scheme.startsWith('http')) {
    final id = uri.queryParameters['checkin'];
    final k = uri.queryParameters['k'];
    if (id == null || id.isEmpty || k == null || k.isEmpty) return null;
    return (locationId: id, secret: k);
  }
  final parts = text.trim().split('|');
  if (parts.length != 3 ||
      parts[0] != 'LOCALPASSPORT' ||
      parts[1].isEmpty ||
      parts[2].isEmpty) {
    return null;
  }
  return (locationId: parts[1], secret: parts[2]);
}

String qrPayloadFor(Location l) =>
    '$appUrl?checkin=${l.id}&k=${Uri.encodeQueryComponent(l.qrCodeSecret)}';
