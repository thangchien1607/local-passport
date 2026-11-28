import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_passport/data/routes.dart';
import 'package:local_passport/screens/qr_scanner_screen.dart';
import 'package:local_passport/state/passport_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('QR đúng địa điểm nhưng sai mã xác thực báo đúng nguyên nhân', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    final store = (await tester.runAsync(PassportStore.load))!;
    addTearDown(store.dispose);
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: PassportScope(
          store: store,
          child: QrScannerScreen(
            location: locationById['dien-hai']!,
            presetCode: 'LOCALPASSPORT|dien-hai|SAI',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Mã xác thực QR không hợp lệ.'), findsOneWidget);
    expect(find.textContaining('không phải điểm bạn đang mở'), findsNothing);
  });
}
