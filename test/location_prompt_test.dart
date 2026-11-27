import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_passport/data/routes.dart';
import 'package:local_passport/services/geo.dart';
import 'package:local_passport/widgets/location_prompt.dart';

const _here = LatLng(16.0611, 108.2278);

/// Giả lập máy: lần đầu ném [first] (nếu có), các lần sau trả [_here].
class _FakeDevice {
  _FakeDevice([this.first, this.keepFailing = false]);

  final LocationException? first;
  final bool keepFailing;
  int locateCalls = 0;
  final opened = <LocationIssue>[];
  int waited = 0;

  Future<LatLng> locate() async {
    locateCalls++;
    final err = first;
    if (err != null && (locateCalls == 1 || keepFailing)) throw err;
    return _here;
  }

  Future<bool> openSettings(LocationIssue issue) async {
    opened.add(issue);
    return true;
  }

  Future<void> waitForReturn() async => waited++;
}

const _off = LocationException('off', LocationIssue.serviceOff);
const _denied = LocationException('denied', LocationIssue.denied);
const _blocked = LocationException('blocked', LocationIssue.deniedForever);

/// Gọi requestLocation từ một nút, trả về kết quả qua [onResult].
Future<void> _start(
  WidgetTester tester,
  _FakeDevice device, {
  bool quiet = false,
  bool isWeb = false,
  required void Function(Object? result) onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            try {
              onResult(
                await requestLocation(
                  context,
                  quiet: quiet,
                  locate: device.locate,
                  openSettings: device.openSettings,
                  waitForReturn: device.waitForReturn,
                  isWeb: isWeb,
                ),
              );
            } catch (e) {
              onResult(e);
            }
          },
          child: const Text('go'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(resetLocationPrompt);

  testWidgets('Định vị bật sẵn: lấy vị trí luôn, không hỏi', (tester) async {
    final device = _FakeDevice();
    Object? result;
    await _start(tester, device, onResult: (r) => result = r);
    expect(find.byType(ShareLocationDialog), findsNothing);
    expect(result, _here);
  });

  testWidgets('Định vị tắt: hỏi, mở cài đặt, quay lại thì lấy được vị trí', (
    tester,
  ) async {
    final device = _FakeDevice(_off);
    Object? result = 'chưa xong';
    await _start(tester, device, onResult: (r) => result = r);

    expect(find.text('Chia sẻ vị trí của bạn?'), findsOneWidget);
    await tester.tap(find.text('Bật định vị'));
    await tester.pumpAndSettle();

    expect(device.opened, [LocationIssue.serviceOff]);
    expect(device.waited, 1);
    expect(device.locateCalls, 2);
    expect(result, _here);
  });

  testWidgets('Chọn "Để sau": không mở cài đặt, trả về null', (tester) async {
    final device = _FakeDevice(_off);
    Object? result = 'chưa xong';
    await _start(tester, device, onResult: (r) => result = r);

    await tester.tap(find.text('Để sau'));
    await tester.pumpAndSettle();

    expect(device.opened, isEmpty);
    expect(device.locateCalls, 1);
    expect(result, isNull);
  });

  testWidgets('Bật xong vẫn tắt: trả về null, không hỏi dồn', (tester) async {
    final device = _FakeDevice(_off, true);
    Object? result = 'chưa xong';
    await _start(tester, device, onResult: (r) => result = r);

    await tester.tap(find.text('Bật định vị'));
    await tester.pumpAndSettle();

    expect(find.byType(ShareLocationDialog), findsNothing);
    expect(result, isNull);
  });

  testWidgets('Tự động khi mở bản đồ: chỉ hỏi 1 lần mỗi phiên', (tester) async {
    final first = _FakeDevice(_off);
    await _start(tester, first, quiet: true, onResult: (_) {});
    expect(find.byType(ShareLocationDialog), findsOneWidget);
    await tester.tap(find.text('Để sau'));
    await tester.pumpAndSettle();

    Object? result = 'chưa xong';
    await _start(
      tester,
      _FakeDevice(_off),
      quiet: true,
      onResult: (r) => result = r,
    );
    expect(find.byType(ShareLocationDialog), findsNothing);
    expect(result, isNull);
  });

  testWidgets('Tự động: vừa từ chối quyền thì không hỏi lại', (tester) async {
    Object? result = 'chưa xong';
    await _start(
      tester,
      _FakeDevice(_denied),
      quiet: true,
      onResult: (r) => result = r,
    );
    expect(find.byType(ShareLocationDialog), findsNothing);
    expect(result, isNull);
  });

  testWidgets('Bấm nút khi đã từ chối quyền: "Cho phép" xin quyền lại', (
    tester,
  ) async {
    final device = _FakeDevice(_denied);
    Object? result = 'chưa xong';
    await _start(tester, device, onResult: (r) => result = r);

    await tester.tap(find.text('Cho phép'));
    await tester.pumpAndSettle();

    expect(device.opened, isEmpty, reason: 'Hộp thoại xin quyền tự hiện');
    expect(device.locateCalls, 2);
    expect(result, _here);
  });

  testWidgets('Quyền bị chặn trên Android: mở cài đặt app', (tester) async {
    final device = _FakeDevice(_blocked);
    Object? result = 'chưa xong';
    await _start(tester, device, onResult: (r) => result = r);

    await tester.tap(find.text('Mở cài đặt'));
    await tester.pumpAndSettle();

    expect(device.opened, [LocationIssue.deniedForever]);
    expect(result, _here);
  });

  testWidgets('Web bị chặn/từ chối: hướng dẫn kiểm tra rồi "Thử lại"', (
    tester,
  ) async {
    final device = _FakeDevice(_blocked);
    Object? result = 'chưa xong';
    await _start(tester, device, isWeb: true, onResult: (r) => result = r);

    expect(find.textContaining('Hãy kiểm tra 2 điều'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(device.opened, isEmpty, reason: 'Web không mở được cài đặt');
    expect(device.locateCalls, 2);
    expect(result, _here);
  });

  testWidgets('Web trên điện thoại tắt GPS: hướng dẫn bật rồi "Thử lại"', (
    tester,
  ) async {
    final device = _FakeDevice(_off);
    Object? result = 'chưa xong';
    await _start(tester, device, isWeb: true, onResult: (r) => result = r);

    expect(find.textContaining('Kéo thanh thông báo xuống'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(device.locateCalls, 2);
    expect(result, _here);
  });

  testWidgets('Web: từ chối hộp thoại trình duyệt → "Thử lại" hỏi lại', (
    tester,
  ) async {
    final device = _FakeDevice(_denied);
    Object? result = 'chưa xong';
    await _start(tester, device, isWeb: true, onResult: (r) => result = r);

    expect(find.textContaining('Hãy kiểm tra 2 điều'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(device.opened, isEmpty);
    expect(result, _here);
  });

  testWidgets('Lỗi tạm thời (hết giờ) vẫn báo ra ngoài', (tester) async {
    Object? result;
    await _start(
      tester,
      _FakeDevice(const LocationException('Không lấy được vị trí.')),
      onResult: (r) => result = r,
    );
    expect(find.byType(ShareLocationDialog), findsNothing);
    expect(result, isA<LocationException>());
  });
}
