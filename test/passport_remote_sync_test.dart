import 'package:flutter_test/flutter_test.dart';
import 'package:local_passport/services/passport_remote.dart';

/// Mô phỏng Firestore với đúng ràng buộc:
/// - Mỗi batch tối đa 500 thao tác (vượt quá ném lỗi).
/// - `reflection_owners/{id}` có `allow update: if false` (ghi đè document đã tồn tại ném permission-denied).
/// - `reflections/{id}` không cho phép client ghi `aiScore` hay `photoBase64`.
class _RuleEnforcingMemoryAdapter implements SyncStorageAdapter {
  final docs = <String, Map<String, dynamic>>{};
  final committedBatchSizes = <int>[];

  @override
  Future<Set<String>> listVisitIds(String uid) async {
    final prefix = 'user_passports/$uid/visits/';
    return {
      for (final k in docs.keys)
        if (k.startsWith(prefix)) k.substring(prefix.length),
    };
  }

  @override
  Future<Set<String>> listNotificationIds(String uid) async {
    final prefix = 'user_passports/$uid/notifications/';
    return {
      for (final k in docs.keys)
        if (k.startsWith(prefix)) k.substring(prefix.length),
    };
  }

  @override
  Future<Set<String>> listOwnedReflectionIds(String uid) async {
    const prefix = 'reflection_owners/';
    return {
      for (final e in docs.entries)
        if (e.key.startsWith(prefix) && e.value['uid'] == uid)
          e.key.substring(prefix.length),
    };
  }

  @override
  Future<bool> reflectionOwnerExists(String reflectionId) async =>
      docs.containsKey('reflection_owners/$reflectionId');

  @override
  Future<bool> reflectionDocExists(String reflectionId) async =>
      docs.containsKey('reflections/$reflectionId');

  @override
  Future<void> commitBatch(List<SyncWriteOp> ops) async {
    if (ops.length > 500) {
      throw StateError('Firestore batch vượt 500 thao tác: ${ops.length}');
    }
    committedBatchSizes.add(ops.length);
    for (final op in ops) {
      switch (op) {
        case SyncSetOp(:final path, :final data, :final merge):
          if (path.startsWith('reflection_owners/') && docs.containsKey(path)) {
            throw StateError(
              'permission-denied: allow update: if false ($path)',
            );
          }
          if (path.startsWith('reflections/')) {
            if (data.containsKey('aiScore')) {
              throw StateError('permission-denied: client cấm ghi aiScore');
            }
            final b64 = data['photoBase64'];
            if (b64 is String && b64.length > 120000) {
              throw StateError(
                'permission-denied: photoBase64 vượt 120000 ký tự',
              );
            }
          }
          if (merge && docs.containsKey(path)) {
            docs[path] = {...docs[path]!, ...data};
          } else {
            docs[path] = Map<String, dynamic>.from(data);
          }
        case SyncDeleteOp(:final path):
          docs.remove(path);
      }
    }
  }
}

Map<String, dynamic> _largePassportPayload({
  required int visitCount,
  required int reflectionCount,
  required int noteCount,
}) {
  final now = DateTime.utc(2026, 11, 1).toIso8601String();
  return {
    'user': {
      'name': 'Người dùng kiểm thử',
      'passportNo': 'DN999999',
      'joinedAt': now,
    },
    'xp': 1250,
    'progress': {
      for (var i = 0; i < visitCount; i++)
        'loc-$i': {
          'unlocked': true,
          'unlockedAt': now,
          'tasks': ['story'],
          'taskPhotoUrls': <String, String>{},
        },
    },
    'stamps': {for (var i = 0; i < visitCount; i++) 'loc-$i': now},
    'notifications': [
      for (var i = 0; i < noteCount; i++)
        {
          'id': 'n-$i',
          'type': 'stamp',
          'title': 'Thông báo $i',
          'body': 'Nội dung $i',
          'locationId': 'loc-0',
          'read': false,
          'createdAt': now,
        },
    ],
    'reflections': [
      for (var i = 0; i < reflectionCount; i++)
        {
          'id': 'r-$i',
          'locationId': 'dien-hai',
          'displayAuthor': 'Người dùng kiểm thử',
          'isAnonymous': false,
          'content': 'Bài cảm nhận số $i rất thú vị về di tích Đà Nẵng.',
          'aiScore': 80,
          'createdAt': now,
          'photoUrl': null,
        },
    ],
  };
}

void main() {
  test('chunkAtomicOps giữ nguyên nhóm nguyên tử và mỗi lô <= 450', () {
    final groups = [
      for (var i = 0; i < 300; i++) ['owner-$i', 'reflection-$i'],
    ];
    final chunks = chunkAtomicOps(groups, maxOps: maxBatchOperations);
    expect(chunks.length, greaterThanOrEqualTo(2));
    for (final chunk in chunks) {
      expect(chunk.length, lessThanOrEqualTo(maxBatchOperations));
      // Mỗi cặp owner/reflection phải đi cùng nhau trong cùng một lô.
      expect(chunk.length.isEven, isTrue);
    }
    expect(chunks.expand((c) => c).length, 600);
  });

  test(
    'Đồng bộ > 500 bản ghi thành công theo lô <= 450 và idempotent khi chạy lặp lại',
    () async {
      final adapter = _RuleEnforcingMemoryAdapter();
      final payload = _largePassportPayload(
        visitCount: 400,
        reflectionCount: 100,
        noteCount: 60,
      );

      // Lần sync đầu: 1 user + 400 visits + 60 notes + 100*(owner+reflection) = 661 thao tác.
      final firstBatches = await runIdempotentChunkedSync(
        uid: 'u-big',
        data: payload,
        adapter: adapter,
      );
      expect(firstBatches, greaterThanOrEqualTo(2));
      for (final size in adapter.committedBatchSizes) {
        expect(size, lessThanOrEqualTo(maxBatchOperations));
      }
      expect(adapter.docs.length, 1 + 400 + 60 + 200);

      // Giả lập Cloud Function đã ghi aiScore vào một bài viết.
      adapter.docs['reflections/r-0']!['aiScore'] = 95;

      // Chạy sync lại lần 2 & lần 3 không cần cache `_written`: phải thành công,
      // không ghi đè `reflection_owners` (permission-denied) và giữ nguyên `aiScore`.
      await runIdempotentChunkedSync(
        uid: 'u-big',
        data: payload,
        adapter: adapter,
      );
      await runIdempotentChunkedSync(
        uid: 'u-big',
        data: payload,
        adapter: adapter,
      );
      expect(adapter.docs['reflections/r-0']!['aiScore'], 95);

      // Xóa một bài cảm nhận ở client rồi sync lại -> xóa cả reflection và owner.
      final reduced = Map<String, dynamic>.from(payload);
      reduced['reflections'] = (payload['reflections'] as List).sublist(1);
      await runIdempotentChunkedSync(
        uid: 'u-big',
        data: reduced,
        adapter: adapter,
      );
      expect(adapter.docs.containsKey('reflections/r-0'), isFalse);
      expect(adapter.docs.containsKey('reflection_owners/r-0'), isFalse);
    },
  );
}
