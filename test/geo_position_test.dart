import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:local_passport/services/geo.dart';

/// Giả lập máy/trình duyệt trả lời các câu hỏi của geolocator.
class _FakePlatform extends GeolocatorPlatform {
  _FakePlatform({
    this.serviceOn = true,
    List<LocationPermission>? permissions,
    this.permissionThrows = false,
    this.afterRequest = LocationPermission.whileInUse,
    this.positionError,
  }) : permissions = permissions ?? [LocationPermission.whileInUse];

  final bool serviceOn;

  /// Kết quả checkPermission lần lượt (lần cuối lặp lại).
  final List<LocationPermission> permissions;
  final bool permissionThrows;
  final LocationPermission afterRequest;
  final Object? positionError;
  int checks = 0;
  int requests = 0;
  int positions = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceOn;

  @override
  Future<LocationPermission> checkPermission() async {
    if (permissionThrows) throw UnsupportedError('permissions API');
    final i = checks < permissions.length ? checks : permissions.length - 1;
    checks++;
    return permissions[i];
  }

  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    return afterRequest;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    positions++;
    final err = positionError;
    if (err != null) throw err;
    return Position(
      latitude: 16.06,
      longitude: 108.22,
      timestamp: DateTime(2026),
      accuracy: 10,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}

Future<LocationIssue?> _issueOf(Future<Object> f) async {
  try {
    await f;
    fail('Phải ném LocationException');
  } on LocationException catch (e) {
    return e.issue;
  }
}

void main() {
  late GeolocatorPlatform original;
  setUp(() => original = GeolocatorPlatform.instance);
  tearDown(() => GeolocatorPlatform.instance = original);

  _FakePlatform use(_FakePlatform p) => GeolocatorPlatform.instance = p;

  group('Web trên điện thoại', () {
    test('Chưa hỏi quyền: lấy vị trí luôn (trình duyệt tự hỏi)', () async {
      final p = use(_FakePlatform(permissions: [LocationPermission.denied]));
      final here = await currentPosition(isWeb: true);
      expect(here.lat, 16.06);
      expect(p.requests, 0);
    });

    test('Trang đã bị chặn: báo bị chặn, không thử lấy vị trí', () async {
      final p = use(
        _FakePlatform(permissions: [LocationPermission.deniedForever]),
      );
      expect(
        await _issueOf(currentPosition(isWeb: true)),
        LocationIssue.deniedForever,
      );
      expect(p.positions, 0);
    });

    test('GPS tắt (Android Chrome báo mã 2) → định vị tắt', () async {
      use(_FakePlatform(positionError: const PositionUpdateException('x')));
      expect(
        await _issueOf(currentPosition(isWeb: true)),
        LocationIssue.serviceOff,
      );
    });

    test(
      'Đã cho phép mà vẫn bị từ chối (iPhone tắt GPS) → định vị tắt',
      () async {
        use(_FakePlatform(positionError: const PermissionDeniedException('x')));
        expect(
          await _issueOf(currentPosition(isWeb: true)),
          LocationIssue.serviceOff,
        );
      },
    );

    test('Vừa bấm Chặn trong hộp thoại trình duyệt → bị chặn', () async {
      use(
        _FakePlatform(
          permissions: [
            LocationPermission.denied,
            LocationPermission.deniedForever,
          ],
          positionError: const PermissionDeniedException('x'),
        ),
      );
      expect(
        await _issueOf(currentPosition(isWeb: true)),
        LocationIssue.deniedForever,
      );
    });

    test('Đóng hộp thoại trình duyệt không chọn → chưa cho phép', () async {
      use(
        _FakePlatform(
          permissions: [LocationPermission.denied],
          positionError: const PermissionDeniedException('x'),
        ),
      );
      expect(
        await _issueOf(currentPosition(isWeb: true)),
        LocationIssue.denied,
      );
    });

    test(
      'Trình duyệt không hỗ trợ hỏi quyền (Zalo...): vẫn lấy được',
      () async {
        use(_FakePlatform(permissionThrows: true));
        expect((await currentPosition(isWeb: true)).lng, 108.22);
      },
    );

    test('Hết giờ chờ: lỗi tạm thời, không gắn lý do', () async {
      use(_FakePlatform(positionError: TimeoutException('x')));
      expect(await _issueOf(currentPosition(isWeb: true)), isNull);
    });
  });

  group('App Android', () {
    test('Định vị tắt: báo tắt, chưa xin quyền', () async {
      final p = use(_FakePlatform(serviceOn: false));
      expect(
        await _issueOf(currentPosition(isWeb: false)),
        LocationIssue.serviceOff,
      );
      expect(p.requests, 0);
    });

    test('Chưa có quyền: xin quyền rồi lấy vị trí', () async {
      final p = use(_FakePlatform(permissions: [LocationPermission.denied]));
      expect((await currentPosition(isWeb: false)).lat, 16.06);
      expect(p.requests, 1);
    });

    test('Từ chối hộp thoại xin quyền → chưa cho phép', () async {
      use(
        _FakePlatform(
          permissions: [LocationPermission.denied],
          afterRequest: LocationPermission.denied,
        ),
      );
      expect(
        await _issueOf(currentPosition(isWeb: false)),
        LocationIssue.denied,
      );
    });

    test('Chặn hẳn quyền → bị chặn', () async {
      use(_FakePlatform(permissions: [LocationPermission.deniedForever]));
      expect(
        await _issueOf(currentPosition(isWeb: false)),
        LocationIssue.deniedForever,
      );
    });

    test('Tắt định vị giữa chừng → định vị tắt', () async {
      use(
        _FakePlatform(positionError: const LocationServiceDisabledException()),
      );
      expect(
        await _issueOf(currentPosition(isWeb: false)),
        LocationIssue.serviceOff,
      );
    });
  });
}
