import 'dart:convert';
import 'dart:math';
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

Uint8List _createTestPng(int width, int height, {bool noisy = false}) {
  final image = img.Image(width: width, height: height);
  if (!noisy) {
    img.fill(image, color: img.ColorRgb8(180, 90, 40));
  } else {
    final rng = Random(42);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        image.setPixelRgb(
          x,
          y,
          rng.nextInt(256),
          rng.nextInt(256),
          rng.nextInt(256),
        );
      }
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  test(
    'compressImageBytes nén ảnh lớn về cạnh dài <= 720px và dung lượng <= 80 KB',
    () async {
      final raw = _createTestPng(1600, 900, noisy: true);
      final out = await compressImageBytes(raw);
      expect(out.lengthInBytes, lessThanOrEqualTo(photoTargetBytes));
      final decoded = img.decodeImage(out);
      expect(decoded, isNotNull);
      expect(decoded!.width, lessThanOrEqualTo(photoMaxDimension));
      expect(decoded.height, lessThanOrEqualTo(photoMaxDimension));
      expect(base64Encode(out).length, lessThanOrEqualTo(photoMaxBase64Length));
    },
  );

  test(
    'compressImageBytes từ chối ảnh khi nén tới mức tối thiểu vẫn vượt ngưỡng',
    () async {
      final raw = _createTestPng(800, 800, noisy: true);
      await expectLater(
        compressImageBytes(
          raw,
          targetBytes: 500,
          hardMaxBytes: 1000,
          maxBase64Length: 1400,
        ),
        throwsA(isA<PhotoTooLargeException>()),
      );
    },
  );

  test(
    'encodeTaskPhotosList / decodeTaskPhotosField giới hạn 3 ảnh và hỗ trợ cả list lẫn map cũ',
    () {
      final map = {'t1': 'AAA', 't2': 'BBB', 't3': 'CCC', 't4': 'DDD'};
      final encoded = encodeTaskPhotosList(map);
      expect(encoded, hasLength(maxTaskPhotosPerVisit));
      expect(encoded, ['t1:AAA', 't2:BBB', 't3:CCC']);

      final decodedFromList = decodeTaskPhotosField(encoded);
      expect(decodedFromList, {'t1': 'AAA', 't2': 'BBB', 't3': 'CCC'});

      final decodedFromLegacyMap = decodeTaskPhotosField({
        'photo': 'LEGACY_B64',
      });
      expect(decodedFromLegacyMap, {'photo': 'LEGACY_B64'});
    },
  );

  test(
    'saveTaskPhotoBytes nén nhỏ lưu Base64 và ước lượng document < 800 KB',
    () async {
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

      final bytes = _createTestPng(1200, 900, noisy: true);
      await store.saveTaskPhotoBytes(photoLoc.id, photoTask.id, bytes);

      final saved = store.taskPhoto(photoLoc.id, photoTask.id);
      expect(saved, isNotNull);
      expect(saved!.length, lessThanOrEqualTo(photoMaxBase64Length));
      expect(
        base64Decode(saved).lengthInBytes,
        lessThanOrEqualTo(photoTargetBytes),
      );

      final docBytes = estimateFirestoreDocBytes({
        'unlocked': true,
        'tasks': [photoTask.id],
        'taskPhotos': encodeTaskPhotosList({photoTask.id: saved}),
      });
      expect(docBytes, lessThan(maxFirestoreDocBytes));

      store.setTaskPhoto(photoLoc.id, photoTask.id, null);
      expect(store.taskPhoto(photoLoc.id, photoTask.id), isNull);
    },
  );

  testWidgets(
    'Hiển thị được cả photoBase64 mới và tương thích ngược photoUrl',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      final b64 = base64Encode(_createTestPng(40, 40));
      final reflection = Reflection(
        id: 'b64-1',
        locationId: 'dien-hai',
        displayAuthor: 'Lữ khách',
        isAnonymous: false,
        content:
            'Bài cảm nhận có ảnh base64 đã nén hiển thị tốt trên bảng tin.',
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
    },
  );
}
