import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:local_passport/data/community.dart';
import 'package:local_passport/data/routes.dart';
import 'package:local_passport/services/auth_service.dart';
import 'package:local_passport/services/passport_remote.dart';
import 'package:local_passport/services/photo_service.dart';
import 'package:local_passport/state/passport_store.dart';
import 'package:local_passport/widgets/reflection_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePhotoStorage implements PhotoStorageGateway {
  final uploadedPaths = <String>[];
  final deletedUrls = <String>[];

  @override
  Future<String> uploadTaskPhoto({
    required String uid,
    required String locationId,
    required String taskId,
    required Uint8List bytes,
  }) async {
    final compressed = await compressImageBytes(bytes);
    expect(compressed, isNotEmpty);
    final path = 'users/$uid/tasks/$locationId/$taskId.jpg';
    uploadedPaths.add(path);
    return 'https://firebasestorage.googleapis.com/v0/b/test/o/$path';
  }

  @override
  Future<String> uploadReflectionPhoto({
    required String uid,
    required String reflectionId,
    required Uint8List bytes,
  }) async {
    final compressed = await compressImageBytes(bytes);
    expect(compressed, isNotEmpty);
    final path = 'users/$uid/reflections/$reflectionId.jpg';
    uploadedPaths.add(path);
    return 'https://firebasestorage.googleapis.com/v0/b/test/o/$path';
  }

  @override
  Future<void> deleteByUrl(String url) async {
    deletedUrls.add(url);
  }
}

class _FakeAuth implements AuthGateway {
  @override
  String? get uid => 'u-photo';
  @override
  String? get email => 'photo@example.com';
  @override
  bool get isGuest => false;
  @override
  Future<void> register(String email, String password) async {}
  @override
  Future<void> signIn(String email, String password) async {}
  @override
  Future<void> signInGuest() async {}
  @override
  Future<void> sendPasswordReset(String email) async {}
  @override
  Future<void> signOut() async {}
}

class _CapturingRemote implements PassportRemote {
  Map<String, dynamic>? lastSynced;

  @override
  final state = ValueNotifier(SyncState.synced);
  @override
  String? get uid => 'u-photo';
  @override
  Future<Map<String, dynamic>?> fetch() async => null;
  @override
  Future<List<Reflection>> fetchCommunity() async => const [];
  @override
  Future<List<LeaderEntry>> fetchLeaderboard({int limit = 50}) async =>
      const [];
  @override
  Future<void> sync(Map<String, dynamic> data) async {
    lastSynced = data;
  }

  @override
  void forget() {}
}

Uint8List _createTestPng(int width, int height) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(180, 90, 40));
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  test(
    'compressImageBytes thu nhỏ ảnh lớn về cạnh dài tối đa 1280px',
    () async {
      final raw = _createTestPng(2000, 1000);
      final out = await compressImageBytes(raw);
      final decoded = img.decodeImage(out);
      expect(decoded, isNotNull);
      expect(decoded!.width, lessThanOrEqualTo(1280));
      expect(decoded.height, lessThanOrEqualTo(640));
    },
  );

  test(
    'Lưu ảnh nhiệm vụ và ảnh cảm nhận chỉ lưu URL (< 50 KB), không lưu photoBase64',
    () async {
      SharedPreferences.setMockInitialValues({});
      final auth = _FakeAuth();
      final remote = _CapturingRemote();
      final photos = _FakePhotoStorage();
      final store = await PassportStore.load(
        remote: remote,
        auth: auth,
        photos: photos,
      );
      store.login('Minh Anh');

      // Tìm địa điểm có nhiệm vụ chụp ảnh.
      final photoLoc = locations.firstWhere(
        (l) => l.tasks.any((t) => t.type == TaskType.photo),
      );
      final photoTask = photoLoc.tasks.firstWhere(
        (t) => t.type == TaskType.photo,
      );
      store.unlock(photoLoc.id);

      final bytes = _createTestPng(1600, 900);
      await store.saveTaskPhotoBytes(photoLoc.id, photoTask.id, bytes);

      final savedUrl = store.taskPhoto(photoLoc.id, photoTask.id);
      expect(savedUrl, startsWith('https://'));
      expect(photos.uploadedPaths.first, contains('users/u-photo/tasks/'));

      final reflectionUrl = await store.uploadReflectionPhoto('r-test', bytes);
      expect(reflectionUrl, startsWith('https://'));
      store.addReflection(
        id: 'r-test',
        locationId: photoLoc.id,
        content: 'Cảm nhận thử nghiệm có ảnh lưu trên Firebase Storage.',
        isAnonymous: false,
        aiScore: 85,
        bonusXp: 40,
        photoUrl: reflectionUrl,
      );

      final payload = remote.lastSynced!;
      final payloadBytes = utf8.encode(jsonEncode(payload)).length;
      expect(payloadBytes, lessThan(50 * 1024));

      final syncedReflection =
          (payload['reflections'] as List).single as Map<String, dynamic>;
      expect(syncedReflection['photoUrl'], reflectionUrl);
      expect(syncedReflection.containsKey('photoBase64'), isFalse);

      // Xóa ảnh nhiệm vụ gọi deleteByUrl trên Storage.
      store.setTaskPhoto(photoLoc.id, photoTask.id, null);
      expect(photos.deletedUrls, contains(savedUrl));
    },
  );

  testWidgets('Tương thích ngược: vẫn hiển thị được ảnh photoBase64 cũ', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final legacyB64 = base64Encode(_createTestPng(40, 40));
    final legacyReflection = Reflection(
      id: 'legacy-1',
      locationId: 'dien-hai',
      displayAuthor: 'Lữ khách cũ',
      isAnonymous: false,
      content: 'Bài cảm nhận cũ lưu ảnh bằng base64 vẫn phải hiển thị được.',
      aiScore: 80,
      createdAt: DateTime(2026, 10, 1),
      photoBase64: legacyB64,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ReflectionCard(reflection: legacyReflection)),
      ),
    );
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
