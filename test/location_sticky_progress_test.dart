import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_passport/screens/location_screen.dart';
import 'package:local_passport/state/passport_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Thẻ tiến độ vẫn hiện trên màn hình khi cuộn xuống', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    final store = await PassportStore.load();
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: PassportScope(
          store: store,
          child: const LocationScreen(locationId: 'dien-hai'),
        ),
      ),
    );
    await tester.pump();

    final progress = find.textContaining('nhiệm vụ');
    expect(progress, findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1500));
    await tester.pumpAndSettle();

    expect(progress, findsOneWidget);
    final top = tester.getRect(progress).top;
    expect(top, inInclusiveRange(0, 200));
    expect(tester.takeException(), isNull);
  });
}
