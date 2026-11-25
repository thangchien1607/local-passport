import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_passport/data/routes.dart';
import 'package:local_passport/screens/qr_scanner_screen.dart';
import 'package:local_passport/state/passport_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Chú thích bán kính quét QR vừa màn hình hẹp', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    final store = await PassportStore.load();
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      PassportScope(
        store: store,
        child: MaterialApp(
          home: QrScannerScreen(location: locationById['dien-hai']!),
        ),
      ),
    );
    await tester.pump();

    final hint = find.textContaining('Cần ở trong bán kính');
    expect(hint, findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(tester.getBottomRight(hint).dx, lessThanOrEqualTo(430));
  });
}
