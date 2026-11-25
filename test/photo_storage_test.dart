import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:local_passport/data/community.dart';
import 'package:local_passport/data/routes.dart';
import 'package:local_passport/services/photo_service.dart';
import 'package:local_passport/state/passport_store.dart';
import 'package:local_passport/widgets/reflection_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

Uint8List _createTestPng(int width, int height) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(180, 90, 40));
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  test('compressImageBytes thu nhỏ ảnh lớn và xuất JPEG hợp lệ', () async {
    final raw = _createTestPng(2000, 1000);
    final out = await compressImageBytes(raw);
    final decoded = img.decodeImage(out);
    expect(decoded, isNotNull);
    expect(decoded!.width, lessThanOrEqualTo(1280));
    expect(decoded.height, lessThanOrEqualTo(640));
  });

  test('saveTaskPhotoBytes nén ảnh và lưu vào trạng thái nhiệm vụ', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await PassportStore.load();
    store.login('Minh Anh');

    final photoLoc = locations.firstWhere(
      (l) => l.tasks.any((t) => t.type == TaskType.photo),
    );
    final photoTask = photoLoc.tasks.firstWhere(
      (t) => t.type == TaskType.photo,
    );
    store.unlock(photoLoc.id);

    final bytes = _createTestPng(1600, 900);
    await store.saveTaskPhotoBytes(photoLoc.id, photoTask.id, bytes);

    final saved = store.taskPhoto(photoLoc.id, photoTask.id);
    expect(saved, isNotNull);
    expect(base64Decode(saved!), isNotEmpty);

    store.setTaskPhoto(photoLoc.id, photoTask.id, null);
    expect(store.taskPhoto(photoLoc.id, photoTask.id), isNull);
  });

  testWidgets('Hiển thị được ảnh photoBase64 trên ReflectionCard', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final b64 = base64Encode(_createTestPng(40, 40));
    final reflection = Reflection(
      id: 'b64-1',
      locationId: 'dien-hai',
      displayAuthor: 'Lữ khách',
      isAnonymous: false,
      content: 'Bài cảm nhận có ảnh base64 đã nén hiển thị tốt trên bảng tin.',
      aiScore: 80,
      createdAt: DateTime(2026, 10, 1),
      photoBase64: b64,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ReflectionCard(reflection: reflection)),
      ),
    );
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
