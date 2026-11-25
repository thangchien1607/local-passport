import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../data/community.dart';
import 'photo_service.dart';

enum SyncState { offline, syncing, synced, error }

/// Giới hạn an toàn dưới ngưỡng 500 thao tác/WriteBatch của Cloud Firestore.
const maxBatchOperations = 450;

/// Giới hạn số phần tử tối đa của toán tử `whereIn` trong Cloud Firestore.
const maxWhereInIds = 30;

/// Trần hợp lý cho XP và số dấu mộc trên bảng xếp hạng (khớp `firestore.rules`).
const maxLeaderboardXp = 50000;
const maxLeaderboardStamps = 200;

/// Chia danh sách ID thành các nhóm nhỏ tối đa [chunkSize] phần tử (mặc định 30)
/// để dùng với truy vấn `whereIn`.
List<List<T>> chunkIds<T>(List<T> ids, {int chunkSize = maxWhereInIds}) {
  if (chunkSize <= 0) {
    throw ArgumentError.value(chunkSize, 'chunkSize', 'Phải lớn hơn 0');
  }
  if (ids.isEmpty) return const [];
  final result = <List<T>>[];
  for (var i = 0; i < ids.length; i += chunkSize) {
    final end = i + chunkSize < ids.length ? i + chunkSize : ids.length;
    result.add(ids.sublist(i, end));
  }
  return result;
}

/// Truy vấn song song theo lô (tối đa [chunkSize] ID mỗi nhóm) bằng `Future.wait`
/// để loại bỏ vòng lặp N+1.
Future<List<T>> fetchInChunks<T>({
  required List<String> ids,
  required Future<List<T>> Function(List<String> chunk) queryChunk,
  int chunkSize = maxWhereInIds,
}) async {
  final uniqueIds = ids.toSet().toList();
  final chunks = chunkIds(uniqueIds, chunkSize: chunkSize);
  if (chunks.isEmpty) return const [];
  final groups = await Future.wait([
    for (final chunk in chunks) queryChunk(chunk),
  ]);
  return [for (final g in groups) ...g];
}

/// Chia các nhóm thao tác nguyên tử thành nhiều lô, mỗi lô tối đa [maxOps]
/// thao tác và không bao giờ tách đôi một nhóm nguyên tử (vd tạo cặp
/// `reflection_owners/{id}` + `reflections/{id}`).
List<List<T>> chunkAtomicOps<T>(
  List<List<T>> atomicGroups, {
  int maxOps = maxBatchOperations,
}) {
  if (maxOps <= 0) {
    throw ArgumentError.value(maxOps, 'maxOps', 'Phải lớn hơn 0');
  }
  final chunks = <List<T>>[];
  var current = <T>[];
  for (final group in atomicGroups) {
    if (group.isEmpty) continue;
    if (group.length > maxOps) {
      throw StateError('Nhóm nguyên tử (${group.length}) vượt quá $maxOps.');
    }
    if (current.isNotEmpty && current.length + group.length > maxOps) {
      chunks.add(current);
      current = <T>[];
    }
    current.addAll(group);
  }
  if (current.isNotEmpty) {
    chunks.add(current);
  }
  return chunks;
}

/// Một thao tác ghi/xóa trên document dùng cho bộ gom lô kiểm thử được.
sealed class SyncWriteOp {
  const SyncWriteOp(this.path);
  final String path;
}

class SyncSetOp extends SyncWriteOp {
  const SyncSetOp(super.path, this.data, {this.merge = false});
  final Map<String, dynamic> data;
  final bool merge;
}

class SyncDeleteOp extends SyncWriteOp {
  const SyncDeleteOp(super.path);
}

/// Giao diện lưu trữ document mức thấp để tách logic chia lô & đồng bộ
/// idempotent khỏi SDK Firestore thật (giúp test >500 bản ghi trực tiếp).
abstract class SyncStorageAdapter {
  Future<Set<String>> listVisitIds(String uid);
  Future<Set<String>> listNotificationIds(String uid);
  Future<Set<String>> listOwnedReflectionIds(String uid);
  Future<bool> reflectionOwnerExists(String reflectionId);
  Future<bool> reflectionDocExists(String reflectionId);
  Future<void> commitBatch(List<SyncWriteOp> ops);
}

class _FirestoreSyncAdapter implements SyncStorageAdapter {
  _FirestoreSyncAdapter(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _ref(String path) => _db.doc(path);

  @override
  Future<Set<String>> listVisitIds(String uid) async {
    final snap = await _db
        .collection('user_passports')
        .doc(uid)
        .collection('visits')
        .get();
    return {for (final d in snap.docs) d.id};
  }

  @override
  Future<Set<String>> listNotificationIds(String uid) async {
    final snap = await _db
        .collection('user_passports')
        .doc(uid)
        .collection('notifications')
        .get();
    return {for (final d in snap.docs) d.id};
  }

  @override
  Future<Set<String>> listOwnedReflectionIds(String uid) async {
    final snap = await _db
        .collection('reflection_owners')
        .where('uid', isEqualTo: uid)
        .get();
    return {for (final d in snap.docs) d.id};
  }

  @override
  Future<bool> reflectionOwnerExists(String reflectionId) async {
    final snap = await _db
        .collection('reflection_owners')
        .doc(reflectionId)
        .get();
    return snap.exists;
  }

  @override
  Future<bool> reflectionDocExists(String reflectionId) async {
    final snap = await _db.collection('reflections').doc(reflectionId).get();
    return snap.exists;
  }

  @override
  Future<void> commitBatch(List<SyncWriteOp> ops) async {
    if (ops.isEmpty) return;
    final batch = _db.batch();
    for (final op in ops) {
      final ref = _ref(op.path);
      switch (op) {
        case SyncSetOp(:final data, :final merge):
          if (merge) {
            batch.set(ref, data, SetOptions(merge: true));
          } else {
            batch.set(ref, data);
          }
        case SyncDeleteOp():
          batch.delete(ref);
      }
    }
    await batch.commit();
  }
}

/// Thực thi đồng bộ hộ chiếu theo lô <= [maxBatchOperations], không phụ thuộc
/// cache cục bộ và luôn kiểm tra tồn tại `reflection_owners/{id}` trước khi tạo
/// mới để tránh ghi đè document bị `allow update: if false`.
Future<int> runIdempotentChunkedSync({
  required String uid,
  required Map<String, dynamic> data,
  required SyncStorageAdapter adapter,
  int maxOpsPerBatch = maxBatchOperations,
}) async {
  final (existingVisits, existingNotes, existingOwnedReflections) = await (
    adapter.listVisitIds(uid),
    adapter.listNotificationIds(uid),
    adapter.listOwnedReflectionIds(uid),
  ).wait;

  final groups = <List<SyncWriteOp>>[];
  final user = data['user'] as Map<String, dynamic>?;
  final progress = data['progress'] as Map<String, dynamic>? ?? const {};
  final stamps = data['stamps'] as Map<String, dynamic>? ?? const {};
  final reflections = (data['reflections'] as List? ?? const [])
      .map((e) => Reflection.fromJson(e as Map<String, dynamic>))
      .toList();
  final notes = (data['notifications'] as List? ?? const [])
      .cast<Map<String, dynamic>>();

  final currentVisitIds = <String>{...progress.keys, ...stamps.keys};
  final currentNoteIds = <String>{for (final n in notes) n['id'] as String};
  final currentReflectionIds = <String>{for (final r in reflections) r.id};

  if (user != null) {
    groups.add([
      SyncSetOp('user_passports/$uid', {
        'name': user['name'],
        'passportNo': user['passportNo'],
        'joinedAt': _toTimestamp(user['joinedAt']),
        'xp': data['xp'] ?? 0,
        'stampCount': stamps.length,
      }),
    ]);

    for (final id in currentVisitIds) {
      final p = progress[id] as Map<String, dynamic>? ?? const {};
      final taskPhotosMap = decodeTaskPhotosField(p['taskPhotos']);
      final taskPhotoUrlsMap =
          (p['taskPhotoUrls'] as Map<String, dynamic>? ??
          const <String, dynamic>{});
      final visitDoc = <String, dynamic>{
        'unlocked': p['unlocked'] ?? false,
        'unlockedAt': _toTimestamp(p['unlockedAt']),
        'tasks': p['tasks'] ?? const <String>[],
        'taskPhotos': encodeTaskPhotosList(taskPhotosMap),
        if (taskPhotoUrlsMap.isNotEmpty) 'taskPhotoUrls': taskPhotoUrlsMap,
        'stampedAt': _toTimestamp(stamps[id]),
      };
      if (estimateFirestoreDocBytes(visitDoc) > maxFirestoreDocBytes) {
        throw const PhotoLimitException(
          'Document chuyến thăm vượt ngưỡng an toàn 800 KB, không thể đồng bộ.',
        );
      }
      groups.add([SyncSetOp('user_passports/$uid/visits/$id', visitDoc)]);
    }

    for (final n in notes) {
      final id = n['id'] as String;
      groups.add([
        SyncSetOp('user_passports/$uid/notifications/$id', {
          'type': n['type'],
          'title': n['title'],
          'body': n['body'],
          'locationId': n['locationId'],
          'read': n['read'] ?? false,
          'createdAt': _toTimestamp(n['createdAt']),
        }),
      ]);
    }

    // Kiểm tra tồn tại `reflection_owners/{id}` và `reflections/{id}` song song
    // thay vì phụ thuộc vào map cache `_written`.
    final existenceChecks = await Future.wait([
      for (final r in reflections)
        () async {
          final ownerExists = existingOwnedReflections.contains(r.id)
              ? true
              : await adapter.reflectionOwnerExists(r.id);
          final docExists = await adapter.reflectionDocExists(r.id);
          return (
            reflection: r,
            ownerExists: ownerExists,
            docExists: docExists,
          );
        }(),
    ]);

    for (final item in existenceChecks) {
      final r = item.reflection;
      if (item.ownerExists && item.docExists) {
        final updateDoc = <String, dynamic>{
          'displayAuthor': r.displayAuthor,
          'isAnonymous': r.isAnonymous,
          'content': r.content,
          'aiScore': r.aiScore.clamp(0, 100),
          'photoBase64': r.photoBase64,
          'photoUrl': ?r.photoUrl,
        };
        if (estimateFirestoreDocBytes(updateDoc) > maxFirestoreDocBytes) {
          throw const PhotoLimitException(
            'Bài cảm nhận vượt ngưỡng an toàn 800 KB, không thể đồng bộ.',
          );
        }
        groups.add([SyncSetOp('reflections/${r.id}', updateDoc, merge: true)]);
      } else if (item.ownerExists && !item.docExists) {
        final createDoc = FirestorePassportRemote.reflectionToCreateDoc(r);
        if (estimateFirestoreDocBytes(createDoc) > maxFirestoreDocBytes) {
          throw const PhotoLimitException(
            'Bài cảm nhận vượt ngưỡng an toàn 800 KB, không thể đồng bộ.',
          );
        }
        groups.add([SyncSetOp('reflections/${r.id}', createDoc)]);
      } else {
        final createDoc = FirestorePassportRemote.reflectionToCreateDoc(r);
        if (estimateFirestoreDocBytes(createDoc) > maxFirestoreDocBytes) {
          throw const PhotoLimitException(
            'Bài cảm nhận vượt ngưỡng an toàn 800 KB, không thể đồng bộ.',
          );
        }
        // Tạo mới cả cặp trong cùng một nhóm nguyên tử để qua kiểm tra `getAfter`.
        groups.add([
          SyncSetOp('reflection_owners/${r.id}', {'uid': uid}),
          SyncSetOp('reflections/${r.id}', createDoc),
        ]);
      }
    }
  } else {
    groups.add([SyncDeleteOp('user_passports/$uid')]);
  }

  // Xóa những document có trên server nhưng không còn trong trạng thái cục bộ.
  for (final id in existingVisits.difference(
    user == null ? const <String>{} : currentVisitIds,
  )) {
    groups.add([SyncDeleteOp('user_passports/$uid/visits/$id')]);
  }
  for (final id in existingNotes.difference(
    user == null ? const <String>{} : currentNoteIds,
  )) {
    groups.add([SyncDeleteOp('user_passports/$uid/notifications/$id')]);
  }
  for (final id in existingOwnedReflections.difference(
    user == null ? const <String>{} : currentReflectionIds,
  )) {
    groups.add([
      SyncDeleteOp('reflections/$id'),
      SyncDeleteOp('reflection_owners/$id'),
    ]);
  }

  final chunks = chunkAtomicOps(groups, maxOps: maxOpsPerBatch);
  for (final chunk in chunks) {
    await adapter.commitBatch(chunk);
  }
  return chunks.length;
}

/// Xóa toàn bộ dữ liệu Firestore của [uid] theo lô <= [maxBatchOperations].
/// Luôn xóa cặp `reflections/{id}` + `reflection_owners/{id}` trong cùng nhóm
/// nguyên tử để thỏa mãn rule `ownerOf(id) == request.auth.uid`, đồng thời
/// idempotent khi người dùng thử lại sau lỗi mạng giữa chừng.
Future<int> runChunkedUserDataDeletion({
  required String uid,
  required SyncStorageAdapter adapter,
  int maxOpsPerBatch = maxBatchOperations,
}) async {
  final (visitIds, noteIds, ownedReflectionIds) = await (
    adapter.listVisitIds(uid),
    adapter.listNotificationIds(uid),
    adapter.listOwnedReflectionIds(uid),
  ).wait;

  final groups = <List<SyncWriteOp>>[
    for (final id in visitIds) [SyncDeleteOp('user_passports/$uid/visits/$id')],
    for (final id in noteIds)
      [SyncDeleteOp('user_passports/$uid/notifications/$id')],
    for (final id in ownedReflectionIds)
      [SyncDeleteOp('reflections/$id'), SyncDeleteOp('reflection_owners/$id')],
    [SyncDeleteOp('leaderboard_public/$uid')],
    [SyncDeleteOp('user_passports/$uid')],
  ];

  final chunks = chunkAtomicOps(groups, maxOps: maxOpsPerBatch);
  for (final chunk in chunks) {
    await adapter.commitBatch(chunk);
  }
  return chunks.length;
}

Timestamp? _toTimestamp(Object? iso) =>
    iso == null ? null : Timestamp.fromDate(DateTime.parse(iso as String));

/// Kết quả một trang bài cảm nhận cộng đồng (phân trang bằng `startAfterDocument`).
class CommunityPage {
  const CommunityPage({
    required this.items,
    required this.hasMore,
    this.cursor,
  });

  final List<Reflection> items;
  final bool hasMore;

  /// Con trỏ trang cuối (`DocumentSnapshot` trên Firestore hoặc giá trị tùy chọn trong test).
  final Object? cursor;
}

/// Nơi lưu trữ trực tuyến của hộ chiếu. PassportStore gọi qua lớp này để
/// test chạy được mà không cần Firebase (truyền null hoặc bản giả).
abstract class PassportRemote {
  /// Trạng thái đồng bộ để hiện trên giao diện.
  ValueListenable<SyncState> get state;

  /// uid của người dùng đang đăng nhập (null khi chưa đăng nhập).
  String? get uid;

  /// Tải dữ liệu của người dùng, cùng dạng JSON với bản lưu cục bộ.
  /// Trả về null nếu chưa đăng nhập hoặc trên server chưa có hộ chiếu.
  Future<Map<String, dynamic>?> fetch();

  /// Bài cảm nhận công khai của mọi người (trang đầu, mới nhất trước).
  Future<List<Reflection>> fetchCommunity();

  /// Tải một trang bài cảm nhận công khai bằng `startAfterDocument`.
  Future<CommunityPage> fetchCommunityPage({
    int limit = 20,
    Object? startAfter,
  });

  /// Luồng realtime (`snapshots()`) lắng nghe các bài cảm nhận mới nhất.
  Stream<List<Reflection>> watchLatestCommunity({int limit = 20});

  /// Bảng xếp hạng công khai từ collection `leaderboard_public`.
  Future<List<LeaderEntry>> fetchLeaderboard({int limit = 50});

  /// Client tự đẩy tóm tắt hồ sơ lên `leaderboard_public/{uid}` (kiến trúc Spark).
  Future<void> syncLeaderboardEntry({
    required String displayName,
    required int xp,
    required int stampCount,
    String? avatarUrl,
  });

  /// Ghi trạng thái hiện tại lên server (chia lô <= 450 thao tác, idempotent).
  Future<void> sync(Map<String, dynamic> data);

  /// Xóa toàn bộ dữ liệu Firestore của [uid] theo lô <= 450 thao tác (dùng khi xóa tài khoản).
  Future<void> deleteAllUserData(String uid);

  /// Đặt lại trạng thái khi đăng xuất hoặc đổi tài khoản.
  void forget();
}

/// Cấu trúc Cloud Firestore (thuần gói Spark):
/// - `user_passports/{uid}`: hồ sơ, XP, số dấu mộc
/// - `user_passports/{uid}/visits/{locationId}`: mở khóa, nhiệm vụ, ảnh nén Base64 (`taskPhotos` <= 3), thời điểm nhận dấu
/// - `user_passports/{uid}/notifications/{id}`: thông báo trong app
/// - `reflections/{reflectionId}`: bài cảm nhận công khai (không chứa uid; ảnh `photoBase64` <= 120 KB; `aiScore` 0–100)
/// - `reflection_owners/{reflectionId}`: uid chủ bài, chỉ chủ bài đọc/xóa (`allow update: if false`)
/// - `leaderboard_public/{uid}`: tóm tắt công khai do chủ tài khoản tự cập nhật có debounce
class FirestorePassportRemote implements PassportRemote {
  FirestorePassportRemote({FirebaseFirestore? db, FirebaseAuth? auth})
    : _db = db ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final _state = ValueNotifier(SyncState.offline);
  Future<void> _queue = Future.value();

  @override
  ValueListenable<SyncState> get state => _state;

  @override
  String? get uid => _auth.currentUser?.uid;

  @override
  void forget() {
    _state.value = SyncState.offline;
  }

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('user_passports').doc(uid);

  @override
  Future<Map<String, dynamic>?> fetch() async {
    final uid = this.uid;
    if (uid == null) {
      _state.value = SyncState.offline;
      return null;
    }
    _state.value = SyncState.syncing;
    try {
      final (userSnap, visits, notes, owners) = await (
        _userDoc(uid).get(),
        _userDoc(uid).collection('visits').get(),
        _userDoc(uid)
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .limit(50)
            .get(),
        _db.collection('reflection_owners').where('uid', isEqualTo: uid).get(),
      ).wait;

      final ownerIds = [for (final o in owners.docs) o.id];
      final reflections = await fetchInChunks<Reflection>(
        ids: ownerIds,
        queryChunk: (chunk) async {
          final snap = await _db
              .collection('reflections')
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
          return [
            for (final d in snap.docs) _reflectionFromDoc(d.id, d.data()),
          ];
        },
      );
      reflections.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final u = userSnap.data();
      _state.value = SyncState.synced;
      if (u == null) return null;
      final progress = <String, dynamic>{};
      final stamps = <String, dynamic>{};
      for (final v in visits.docs) {
        final d = v.data();
        progress[v.id] = {
          'unlocked': d['unlocked'] ?? false,
          'unlockedAt': _iso(d['unlockedAt']),
          'tasks': d['tasks'] ?? const [],
          'taskPhotos': decodeTaskPhotosField(d['taskPhotos']),
          // Tương thích ngược với URL ảnh cũ (nếu đã lưu trước khi chuyển Spark).
          'taskPhotoUrls': ?d['taskPhotoUrls'],
        };
        final stampedAt = _iso(d['stampedAt']);
        if (stampedAt != null) stamps[v.id] = stampedAt;
      }
      return {
        'uid': uid,
        'user': {
          'name': u['name'],
          'passportNo': u['passportNo'],
          'joinedAt': _iso(u['joinedAt']),
        },
        'progress': progress,
        'stamps': stamps,
        'xp': u['xp'] ?? 0,
        'reflections': reflections.map((r) => r.toJson()).toList(),
        'notifications': [
          for (final n in notes.docs)
            {'id': n.id, ...n.data(), 'createdAt': _iso(n.data()['createdAt'])},
        ],
      };
    } catch (e) {
      debugPrint('Firestore fetch lỗi: $e');
      _state.value = SyncState.error;
      rethrow;
    }
  }

  @override
  Future<List<Reflection>> fetchCommunity() async {
    final page = await fetchCommunityPage(limit: 20);
    return page.items;
  }

  @override
  Future<CommunityPage> fetchCommunityPage({
    int limit = 20,
    Object? startAfter,
  }) async {
    var query = _db
        .collection('reflections')
        .orderBy('createdAt', descending: true)
        .limit(limit);
    if (startAfter is DocumentSnapshot) {
      query = query.startAfterDocument(startAfter);
    }
    final snap = await query.get();
    final items = [
      for (final d in snap.docs) _reflectionFromDoc(d.id, d.data()),
    ];
    return CommunityPage(
      items: items,
      hasMore: snap.docs.length >= limit,
      cursor: snap.docs.isEmpty ? startAfter : snap.docs.last,
    );
  }

  @override
  Stream<List<Reflection>> watchLatestCommunity({int limit = 20}) {
    return _db
        .collection('reflections')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => [
            for (final d in snap.docs) _reflectionFromDoc(d.id, d.data()),
          ],
        );
  }

  @override
  Future<List<LeaderEntry>> fetchLeaderboard({int limit = 50}) async {
    final myUid = uid;
    final snap = await _db
        .collection('leaderboard_public')
        .orderBy('xp', descending: true)
        .orderBy('stampCount', descending: true)
        .limit(limit)
        .get();
    return [
      for (final d in snap.docs)
        LeaderEntry(
          d.id,
          d.data()['displayName'] as String? ?? 'Lữ khách',
          (d.data()['xp'] as num?)?.toInt() ?? 0,
          (d.data()['stampCount'] as num?)?.toInt() ?? 0,
          avatarUrl: d.data()['avatarUrl'] as String?,
          isMe: myUid != null && d.id == myUid,
        ),
    ];
  }

  @override
  Future<void> syncLeaderboardEntry({
    required String displayName,
    required int xp,
    required int stampCount,
    String? avatarUrl,
  }) async {
    final myUid = uid;
    if (myUid == null) return;
    final trimmed = displayName.trim().isEmpty
        ? 'Lữ khách'
        : displayName.trim();
    final safeName = trimmed.length > 40 ? trimmed.substring(0, 40) : trimmed;
    final safeAvatar =
        (avatarUrl != null &&
            avatarUrl.length <= 2048 &&
            isNetworkImageUrl(avatarUrl))
        ? avatarUrl
        : null;
    await _db.collection('leaderboard_public').doc(myUid).set({
      'displayName': safeName,
      'xp': xp.clamp(0, maxLeaderboardXp),
      'stampCount': stampCount.clamp(0, maxLeaderboardStamps),
      'avatarUrl': safeAvatar,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> sync(Map<String, dynamic> data) {
    // Lấy uid ngay lúc gọi để dữ liệu không ghi nhầm sang tài khoản khác.
    final uid = this.uid;
    if (uid == null) return _queue;
    // Ghi tuần tự để các thay đổi liên tiếp không chen nhau.
    _queue = _queue.then((_) => _sync(uid, data)).catchError((Object e) {
      debugPrint('Firestore sync lỗi: $e');
      _state.value = SyncState.error;
    });
    return _queue;
  }

  Future<void> _sync(String uid, Map<String, dynamic> data) async {
    if (this.uid != uid) return;
    _state.value = SyncState.syncing;
    await runIdempotentChunkedSync(
      uid: uid,
      data: data,
      adapter: _FirestoreSyncAdapter(_db),
    );
    _state.value = SyncState.synced;
  }

  @override
  Future<void> deleteAllUserData(String uid) async {
    // Chờ các lệnh sync đang chạy dở kết thúc để tránh ghi đè lại sau khi xóa.
    await _queue.catchError((_) {});
    await runChunkedUserDataDeletion(
      uid: uid,
      adapter: _FirestoreSyncAdapter(_db),
    );
  }

  /// Dữ liệu bài cảm nhận ghi từ client (lưu `photoBase64` đã nén <= 120 KB
  /// và `aiScore` 0–100 do heuristic offline hoặc endpoint ngoài tính).
  static Map<String, dynamic> reflectionToCreateDoc(Reflection r) => {
    'locationId': r.locationId,
    'displayAuthor': r.displayAuthor,
    'isAnonymous': r.isAnonymous,
    'content': r.content,
    'aiScore': r.aiScore.clamp(0, 100),
    'createdAt': Timestamp.fromDate(r.createdAt),
    'photoBase64': r.photoBase64,
    'photoUrl': ?r.photoUrl,
  };

  static Reflection _reflectionFromDoc(String id, Map<String, dynamic> d) =>
      Reflection(
        id: id,
        locationId: d['locationId'] as String,
        displayAuthor: d['displayAuthor'] as String,
        isAnonymous: d['isAnonymous'] as bool? ?? false,
        content: d['content'] as String,
        aiScore: (d['aiScore'] as num?)?.toInt() ?? 0,
        createdAt: (d['createdAt'] as Timestamp).toDate(),
        photoBase64: d['photoBase64'] as String?,
        // Tương thích ngược với URL ảnh cũ (nếu có).
        photoUrl: d['photoUrl'] as String?,
      );

  static String? _iso(Object? v) =>
      v is Timestamp ? v.toDate().toIso8601String() : null;
}
