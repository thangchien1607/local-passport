import 'package:flutter_test/flutter_test.dart';
import 'package:local_passport/services/passport_remote.dart';

/// Mô phỏng Firestore với đúng ràng buộc Spark:
/// - Mỗi batch tối đa 500 thao tác (vượt quá ném lỗi).
/// - `reflection_owners/{id}` có `allow update: if false` (ghi đè document đã tồn tại ném permission-denied).
/// - `reflections/{id}` ràng buộc `aiScore` 0..100, `photoBase64` <= 120000 ký tự, và khi xóa phải có `reflection_owners/{id}` tồn tại trước batch.
class _RuleEnforcingMemoryAdapter implements SyncStorageAdapter {
  final docs = <String, Map<String, dynamic>>{};
  final committedBatchSizes = <int>[];
  int? failAtCommitNumber;
  int _commitAttempts = 0;

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
    _commitAttempts++;
    if (failAtCommitNumber != null && _commitAttempts == failAtCommitNumber) {
      throw StateError('network-error: mô phỏng lỗi giữa chừng');
    }
    if (ops.length > 500) {
      throw StateError('Firestore batch vượt 500 thao tác: ${ops.length}');
    }
    // Kiểm tra rule xóa reflections/{id} dựa trên trạng thái TRƯỚC batch (giống Firestore Rules).
    for (final op in ops) {
      if (op is SyncDeleteOp && op.path.startsWith('reflections/')) {
        final id = op.path.substring('reflections/'.length);
        if (!docs.containsKey('reflection_owners/$id')) {
          throw StateError(
            'permission-denied: thiếu reflection_owners/$id khi xóa ${op.path}',
          );
        }
      }
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
            final score = data['aiScore'];
            if (score != null && (score is! int || score < 0 || score > 100)) {
              throw StateError('permission-denied: aiScore ngoài 0..100');
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

      // Chạy sync lại lần 2 & lần 3 không cần cache `_written`: phải thành công,
      // không ghi đè `reflection_owners` (permission-denied).
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
      expect(adapter.docs['reflections/r-0']!['aiScore'], 80);

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

  test(
    'runChunkedUserDataDeletion xóa > 500 document theo lô <= 450 và idempotent khi thử lại sau lỗi giữa chừng',
    () async {
      final adapter = _RuleEnforcingMemoryAdapter();
      final payload = _largePassportPayload(
        visitCount: 400,
        reflectionCount: 100,
        noteCount: 60,
      );
      await runIdempotentChunkedSync(
        uid: 'u-del',
        data: payload,
        adapter: adapter,
      );
      adapter.docs['leaderboard_public/u-del'] = {
        'displayName': 'Người dùng kiểm thử',
        'xp': 1250,
      };
      // Dữ liệu của người dùng khác tuyệt đối không được bị xóa nhầm.
      adapter.docs['user_passports/other'] = {'name': 'Người khác'};
      adapter.docs['leaderboard_public/other'] = {'displayName': 'Người khác'};
      adapter.docs['reflection_owners/r-other'] = {'uid': 'other'};
      adapter.docs['reflections/r-other'] = {'content': 'Bài của người khác'};

      // Giả lập lỗi mạng ở lô xóa thứ 2 (đã ghi 2 lô sync trước đó -> lỗi ở commit thứ 4).
      adapter.committedBatchSizes.clear();
      adapter.failAtCommitNumber = 4;
      await expectLater(
        runChunkedUserDataDeletion(uid: 'u-del', adapter: adapter),
        throwsA(isA<StateError>()),
      );
      // Lô đầu đã xóa một phần, vẫn còn dữ liệu chưa xóa hết.
      expect(adapter.docs.containsKey('user_passports/u-del'), isTrue);

      // Thử lại sau khi mạng ổn định: phải xóa sạch toàn bộ dữ liệu còn lại của u-del.
      adapter.failAtCommitNumber = null;
      final retryBatches = await runChunkedUserDataDeletion(
        uid: 'u-del',
        adapter: adapter,
      );
      expect(retryBatches, greaterThanOrEqualTo(1));
      for (final size in adapter.committedBatchSizes) {
        expect(size, lessThanOrEqualTo(maxBatchOperations));
      }

      // Không còn bất kỳ document nào của u-del; dữ liệu của `other` vẫn nguyên vẹn.
      expect(
        adapter.docs.keys.where(
          (k) => k.contains('u-del') || k.startsWith('reflections/r-'),
        ),
        ['reflections/r-other'],
      );
      expect(adapter.docs.keys.toSet(), {
        'user_passports/other',
        'leaderboard_public/other',
        'reflection_owners/r-other',
        'reflections/r-other',
      });
    },
  );

  test(
    'Đồng bộ cảm nhận mới không gọi get() lên reflection_owners chưa tồn tại (BUG-14)',
    () async {
      final adapter = _StrictOwnerReadAdapter();
      final now = DateTime.utc(2026, 11, 26).toIso8601String();
      final payload = <String, dynamic>{
        'user': {'name': 'QA Sync', 'passportNo': 'DN123456', 'joinedAt': now},
        'xp': 125,
        'progress': {
          'dien-hai': {
            'unlocked': true,
            'unlockedAt': now,
            'tasks': ['timelens', 'story', 'statue'],
            'taskPhotos': <String, String>{},
          },
        },
        'stamps': {'dien-hai': now},
        'notifications': const <Map<String, dynamic>>[],
        'reflections': [
          {
            'id': 'r-new-bug14',
            'locationId': 'dien-hai',
            'displayAuthor': 'QA Sync',
            'isAnonymous': false,
            'content': 'Thành Điện Hải gắn liền lịch sử bảo vệ Đà Nẵng.',
            'aiScore': 80,
            'createdAt': now,
            'photoUrl': null,
          },
        ],
      };

      // Phải thành công ngay cả khi Firestore Rules chặn get() document chưa tồn tại ở reflection_owners.
      await runIdempotentChunkedSync(
        uid: 'u-bug14',
        data: payload,
        adapter: adapter,
      );
      expect(adapter.ownerExistsCalls, 0);
      expect(adapter.docs['reflection_owners/r-new-bug14'], {'uid': 'u-bug14'});
      expect(adapter.docs.containsKey('reflections/r-new-bug14'), isTrue);
    },
  );
}

/// Giống Firestore Rules thật (`firestore.rules:143`):
/// `allow read: if signedIn() && resource.data.uid == request.auth.uid;`
/// nên `get()` trên `reflection_owners/{id}` chưa tồn tại ném `permission-denied`.
class _StrictOwnerReadAdapter extends _RuleEnforcingMemoryAdapter {
  int ownerExistsCalls = 0;

  @override
  Future<bool> reflectionOwnerExists(String reflectionId) async {
    ownerExistsCalls++;
    if (!docs.containsKey('reflection_owners/$reflectionId')) {
      throw StateError(
        'permission-denied: reflection_owners/$reflectionId không tồn tại (resource == null)',
      );
    }
    return true;
  }
}
