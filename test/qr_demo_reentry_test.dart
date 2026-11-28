import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_passport/data/routes.dart';
import 'package:local_passport/screens/qr_scanner_screen.dart';
import 'package:local_passport/state/passport_store.dart';
import 'package:local_passport/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PopObserver extends NavigatorObserver {
  int pops = 0;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pops++;
  }
}

void main() {
  testWidgets('Nhấn Demo liên tiếp chỉ đóng màn hình quét một lần', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    final store = (await tester.runAsync(PassportStore.load))!;
    addTearDown(store.dispose);
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final observer = _PopObserver();
    final navigator = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [observer],
        home: const Scaffold(body: Text('Trang chủ thử nghiệm')),
      ),
    );
    navigator.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Chi tiết điểm đến')),
      ),
    );
    await tester.pumpAndSettle();
    final result = navigator.currentState!.push<ScanResult>(
      MaterialPageRoute<ScanResult>(
        builder: (_) => PassportScope(
          store: store,
          child: QrScannerScreen(location: locationById['dien-hai']!),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Hai thao tác đến trước khi Flutter dựng lại nút thành trạng thái bận.
    final demo = tester.widget<SecondaryButton>(find.byType(SecondaryButton));
    demo.onPressed!();
    demo.onPressed!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pumpAndSettle();

    expect(await result, ScanResult.demo);
    expect(observer.pops, 1);
    expect(find.text('Chi tiết điểm đến'), findsOneWidget);
  });
}
