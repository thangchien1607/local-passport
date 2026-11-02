import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_passport/screens/stamp_ceremony.dart';
import 'package:local_passport/state/passport_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Màn đóng dấu nền tối, có con dấu và nút Tiếp tục', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    final store = await PassportStore.load();
    store.login('Gia Huy');
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      PassportScope(
        store: store,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showStampCeremony(context, 'dien-hai'),
                child: const Text('mở'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();

    expect(find.text('HOÀN THÀNH 100%'), findsOneWidget);
    expect(find.text('Cộp!'), findsOneWidget);
    expect(find.text('Dấu mộc mới!'), findsOneWidget);
    expect(find.text('ĐÀ NẴNG · VN'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    expect(
      find.text('Bạn có muốn lưu lại cảm nhận tại đây không?'),
      findsOneWidget,
    );
  });
}
