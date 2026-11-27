import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
// ignore: depend_on_referenced_packages
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:local_passport/screens/stamp_ceremony.dart';
import 'package:local_passport/state/passport_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CorruptImagePicker extends ImagePickerPlatform {
  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async => XFile.fromData(
    Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0xDE, 0xAD]),
    mimeType: 'image/jpeg',
  );
}

void main() {
  testWidgets(
    'Ảnh JPEG hỏng hiện lỗi trực tiếp trong hộp thoại cảm nhận, không bị che sau dialog (BUG-15)',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      SharedPreferences.setMockInitialValues({});
      final store = (await tester.runAsync(PassportStore.load))!;
      store.login('QA Photo');

      final origPicker = ImagePickerPlatform.instance;
      ImagePickerPlatform.instance = _CorruptImagePicker();
      addTearDown(() => ImagePickerPlatform.instance = origPicker);

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        PassportScope(
          store: store,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showStampCeremony(
                    context,
                    'cau-rong',
                    startAtFeedback: true,
                  ),
                  child: const Text('Mở cảm nhận'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Mở cảm nhận'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField),
        'Cầu Rồng phun lửa tối cuối tuần rất đẹp và ấn tượng bên sông Hàn Đà Nẵng.',
      );
      await tester.pump();

      await tester.tap(find.text('Thêm ảnh thực tế'));
      await tester.pumpAndSettle();
      // Dọn ngoại lệ giải mã preview nếu có trên bản gốc để kiểm tra tiếp bước Gửi.
      tester.takeException();

      await tester.tap(find.text('Gửi cảm nhận'));
      await tester.pumpAndSettle();

      // Lỗi phải nằm trực tiếp trong hộp thoại (không phải SnackBar bị che phía sau showGeneralDialog).
      final errFinder = find.textContaining('Không giải mã được định dạng ảnh');
      expect(errFinder, findsOneWidget);
      expect(
        find.ancestor(of: errFinder, matching: find.byType(SnackBar)),
        findsNothing,
      );
    },
  );
}
