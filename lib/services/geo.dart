import 'dart:math';

import 'package:flutter/foundation.dart';
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

/// Lý do không lấy được vị trí mà người dùng tự sửa được.
enum LocationIssue {
  /// Công tắc định vị (GPS) của máy đang tắt.
  serviceOff,

  /// Người dùng vừa từ chối hộp thoại xin quyền.
  denied,

  /// Quyền bị chặn hẳn: chỉ mở lại được trong cài đặt máy/trình duyệt.
  deniedForever,
}

class LocationException implements Exception {
  const LocationException(this.message, [this.issue]);

  final String message;

  /// null: lỗi tạm thời (hết giờ, mất tín hiệu), thử lại là được.
  final LocationIssue? issue;

  @override
  String toString() => message;
}

const _serviceOff = LocationException(
  'Định vị trên máy đang tắt.',
  LocationIssue.serviceOff,
);
const _denied = LocationException(
  'Bạn chưa cho phép truy cập vị trí.',
  LocationIssue.denied,
);
const _blocked = LocationException(
  'Quyền truy cập vị trí đang bị chặn.',
  LocationIssue.deniedForever,
);
const _failed = LocationException('Không lấy được vị trí, hãy thử lại.');

const _settings = LocationSettings(
  accuracy: LocationAccuracy.high,
  timeLimit: Duration(seconds: 15),
);

/// Lấy vị trí hiện tại, ném [LocationException] nói rõ lý do nếu không được.
Future<LatLng> currentPosition({bool isWeb = kIsWeb}) =>
    isWeb ? _webPosition() : _appPosition();

/// App Android/iOS: hỏi hệ điều hành trực tiếp.
Future<LatLng> _appPosition() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) throw _serviceOff;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) throw _blocked;
    if (permission == LocationPermission.denied) throw _denied;
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: _settings,
    );
    return LatLng(pos.latitude, pos.longitude);
  } on LocationException {
    rethrow;
  } on LocationServiceDisabledException {
    throw _serviceOff; // Tắt định vị giữa chừng.
  } on PermissionDeniedException {
    throw _denied;
  } catch (_) {
    throw _failed;
  }
}

/// Bản web (kể cả mở trên điện thoại): trình duyệt luôn báo "định vị bật",
/// nên phải đọc lỗi khi lấy vị trí để biết GPS tắt hay trang bị chặn.
Future<LatLng> _webPosition() async {
  final before = await _webPermission();
  if (before == LocationPermission.deniedForever) throw _blocked;
  try {
    // Trạng thái "prompt": chính lệnh này làm trình duyệt hiện hỏi quyền.
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: _settings,
    );
    return LatLng(pos.latitude, pos.longitude);
  } on PermissionDeniedException {
    // Mã 1: người dùng vừa từ chối, hoặc trang đã được phép nhưng
    // GPS của điện thoại tắt (iPhone báo kiểu này).
    return switch (await _webPermission()) {
      LocationPermission.whileInUse ||
      LocationPermission.always => throw _serviceOff,
      LocationPermission.denied => throw _denied,
      _ => throw _blocked,
    };
  } on PositionUpdateException {
    throw _serviceOff; // Mã 2: không xác định được vị trí, thường do GPS tắt.
  } catch (_) {
    throw _failed; // Hết giờ chờ.
  }
}

/// null khi trình duyệt không hỗ trợ hỏi trạng thái quyền (Safari cũ,
/// trình duyệt trong Zalo/Messenger...): cứ thử lấy vị trí là biết.
Future<LocationPermission?> _webPermission() async {
  try {
    return await Geolocator.checkPermission();
  } catch (_) {
    return null;
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
