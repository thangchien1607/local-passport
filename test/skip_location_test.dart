import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_passport/data/routes.dart';
import 'package:local_passport/screens/qr_scanner_screen.dart';
import 'package:local_passport/services/geo.dart';
import 'package:local_passport/state/passport_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mở màn quét bằng link QR có sẵn (như khi quét bằng camera thường),
/// trả về kết quả màn quét đóng lại với.
Future<ScanResult?> _scanPreset(
  WidgetTester tester,
  PassportStore store,
  String code,
) async {
  // Màn quét được thiết kế cho điện thoại dọc (Pixel 7).
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  final loc = publishedLocations.first;
  ScanResult? result;
  await tester.pumpWidget(
    PassportScope(
      store: store,
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<ScanResult>(
                MaterialPageRoute(
                  builder: (_) =>
                      QrScannerScreen(location: loc, presetCode: code),
                ),
              );
            },
            child: const Text('go'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('go'));
  await tester.pump();
  // Hết hiệu ứng mở trang + thời gian màn quét báo "Mã QR hợp lệ".
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
  return result;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('Bỏ qua kiểm tra vị trí: mặc định tắt, bật được và nhớ lại', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await PassportStore.load();
    expect(store.skipLocationCheck, isFalse);

    store.setSkipLocationCheck(true);
    expect(store.skipLocationCheck, isTrue);

    final again = await PassportStore.load();
    expect(again.skipLocationCheck, isTrue, reason: 'Lưu trên máy');
  });

  testWidgets('Đang bỏ qua vị trí: mã QR đúng thì check-in không cần GPS', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = await PassportStore.load();
    store.setSkipLocationCheck(true);

    final loc = publishedLocations.first;
    final result = await _scanPreset(tester, store, qrPayloadFor(loc));
    expect(result, ScanResult.skippedLocation);
  });

  testWidgets('Đang bỏ qua vị trí: mã QR sai vẫn bị từ chối', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await PassportStore.load();
    store.setSkipLocationCheck(true);

    final other = publishedLocations[1];
    final result = await _scanPreset(tester, store, qrPayloadFor(other));
    expect(result, isNull);
    expect(find.textContaining('không phải điểm bạn đang mở'), findsOneWidget);
  });
}
