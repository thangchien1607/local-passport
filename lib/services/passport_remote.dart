import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../data/community.dart';

enum SyncState { offline, syncing, synced, error }

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

  /// Bài cảm nhận công khai của mọi người (mới nhất trước).
  Future<List<Reflection>> fetchCommunity();

  /// Ghi trạng thái hiện tại lên server (chỉ ghi phần thay đổi).
  Future<void> sync(Map<String, dynamic> data);

  /// Quên những gì đã ghi cho tài khoản cũ (gọi khi đăng xuất, đổi tài khoản).
  void forget();
}

/// Cấu trúc Cloud Firestore:
/// - `user_passports/{uid}`: hồ sơ, XP, số dấu mộc
/// - `user_passports/{uid}/visits/{locationId}`: mở khóa, nhiệm vụ, ảnh, thời điểm nhận dấu
/// - `user_passports/{uid}/notifications/{id}`: thông báo trong app
/// - `reflections/{reflectionId}`: bài cảm nhận công khai (không chứa uid)
/// - `reflection_owners/{reflectionId}`: uid chủ bài, chỉ chủ bài đọc được
class FirestorePassportRemote implements PassportRemote {
  FirestorePassportRemote({FirebaseFirestore? db, FirebaseAuth? auth})
    : _db = db ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final _state = ValueNotifier(SyncState.offline);

  /// Bản đã ghi gần nhất của từng document, để bỏ qua document không đổi.
  final _written = <String, String>{};
  Future<void> _queue = Future.value();

  @override
  ValueListenable<SyncState> get state => _state;

  @override
  String? get uid => _auth.currentUser?.uid;

  @override
  void forget() {
    _written.clear();
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
      final userSnap = await _userDoc(uid).get();
      final visits = await _userDoc(uid).collection('visits').get();
      final notes = await _userDoc(uid)
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();
      final owners = await _db
          .collection('reflection_owners')
          .where('uid', isEqualTo: uid)
          .get();
      final reflections = <Reflection>[];
      for (final o in owners.docs) {
        final snap = await _db.collection('reflections').doc(o.id).get();
        final r = snap.data();
        if (r != null) reflections.add(_reflectionFromDoc(snap.id, r));
      }
      reflections.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Ghi nhớ những gì đang có trên server để lần sync sau biết cần xóa gì.
      _written.clear();
      for (final v in visits.docs) {
        _written['visits/${v.id}'] = '';
      }
      for (final n in notes.docs) {
        _written['notifications/${n.id}'] = '';
      }
      for (final r in reflections) {
        _written['reflections/${r.id}'] = jsonEncode(_reflectionToDoc(r));
      }

      final u = userSnap.data();
      _state.value = SyncState.synced;
      if (u == null) return null;
      _written['user'] = '';
      final progress = <String, dynamic>{};
      final stamps = <String, dynamic>{};
      for (final v in visits.docs) {
        final d = v.data();
        progress[v.id] = {
          'unlocked': d['unlocked'] ?? false,
          'unlockedAt': _iso(d['unlockedAt']),
          'tasks': d['tasks'] ?? const [],
          'taskPhotoUrls': d['taskPhotoUrls'] ?? const <String, dynamic>{},
          // Tương thích ngược với ảnh base64 cũ đã lưu trước khi chuyển Storage.
          if (d['taskPhotos'] != null) 'taskPhotos': d['taskPhotos'],
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
    final snap = await _db
        .collection('reflections')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();
    return [for (final d in snap.docs) _reflectionFromDoc(d.id, d.data())];
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
    final before = Map.of(_written);
    final batch = _db.batch();
    var ops = 0;
    final seen = <String>{};

    void put(String key, DocumentReference ref, Map<String, dynamic> doc) {
      seen.add(key);
      final encoded = jsonEncode(doc, toEncodable: (o) => o.toString());
      if (_written[key] == encoded) return;
      batch.set(ref, doc);
      _written[key] = encoded;
      ops++;
    }

    final user = data['user'] as Map<String, dynamic>?;
    final progress = data['progress'] as Map<String, dynamic>;
    final stamps = data['stamps'] as Map<String, dynamic>;
    final reflections = (data['reflections'] as List)
        .map((e) => Reflection.fromJson(e as Map<String, dynamic>))
        .toList();
    final notes = (data['notifications'] as List? ?? const [])
        .cast<Map<String, dynamic>>();

    if (user != null) {
      put('user', _userDoc(uid), {
        'name': user['name'],
        'passportNo': user['passportNo'],
        'joinedAt': _ts(user['joinedAt']),
        'xp': data['xp'],
        'stampCount': stamps.length,
      });
      for (final id in {...progress.keys, ...stamps.keys}) {
        final p = progress[id] as Map<String, dynamic>? ?? const {};
        put('visits/$id', _userDoc(uid).collection('visits').doc(id), {
          'unlocked': p['unlocked'] ?? false,
          'unlockedAt': _ts(p['unlockedAt']),
          'tasks': p['tasks'] ?? const [],
          'taskPhotoUrls': p['taskPhotoUrls'] ?? const <String, dynamic>{},
          'stampedAt': _ts(stamps[id]),
        });
      }
      for (final n in notes) {
        final id = n['id'] as String;
        put(
          'notifications/$id',
          _userDoc(uid).collection('notifications').doc(id),
          {
            'type': n['type'],
            'title': n['title'],
            'body': n['body'],
            'locationId': n['locationId'],
            'read': n['read'] ?? false,
            'createdAt': _ts(n['createdAt']),
          },
        );
      }
      for (final r in reflections) {
        final key = 'reflections/${r.id}';
        final isNew = !_written.containsKey(key);
        final doc = _reflectionToDoc(r);
        seen.add(key);
        final encoded = jsonEncode(doc, toEncodable: (o) => o.toString());
        if (_written[key] != encoded) {
          // Dùng merge: true để không ghi đè trường `aiScore` do Cloud Function quản lý.
          batch.set(
            _db.collection('reflections').doc(r.id),
            doc,
            SetOptions(merge: true),
          );
          _written[key] = encoded;
          ops++;
        }
        if (isNew) {
          batch.set(_db.collection('reflection_owners').doc(r.id), {
            'uid': uid,
          });
          ops++;
        }
      }
    }

    // Xóa những document không còn trong trạng thái hiện tại.
    for (final key in _written.keys.where((k) => !seen.contains(k)).toList()) {
      _written.remove(key);
      final slash = key.indexOf('/');
      final id = slash < 0 ? '' : key.substring(slash + 1);
      if (key == 'user') {
        batch.delete(_userDoc(uid));
      } else if (key.startsWith('visits/')) {
        batch.delete(_userDoc(uid).collection('visits').doc(id));
      } else if (key.startsWith('notifications/')) {
        batch.delete(_userDoc(uid).collection('notifications').doc(id));
      } else if (key.startsWith('reflections/')) {
        batch
          ..delete(_db.collection('reflections').doc(id))
          ..delete(_db.collection('reflection_owners').doc(id));
        ops++;
      }
      ops++;
    }

    try {
      if (ops > 0) await batch.commit();
    } catch (_) {
      // Ghi thất bại: quay lại trạng thái trước để lần sau gửi lại đủ.
      _written
        ..clear()
        ..addAll(before);
      rethrow;
    }
    _state.value = SyncState.synced;
  }

  /// Dữ liệu bài cảm nhận ghi từ client — KHÔNG bao gồm `aiScore`
  /// vì `aiScore` chỉ do Cloud Function ghi bằng Admin SDK.
  static Map<String, dynamic> _reflectionToDoc(Reflection r) => {
    'locationId': r.locationId,
    'displayAuthor': r.displayAuthor,
    'isAnonymous': r.isAnonymous,
    'content': r.content,
    'createdAt': Timestamp.fromDate(r.createdAt),
    'photoUrl': r.photoUrl,
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
        photoUrl: d['photoUrl'] as String?,
        // Tương thích ngược với các bài cũ có trường photoBase64.
        photoBase64: d['photoBase64'] as String?,
      );

  static Timestamp? _ts(Object? iso) =>
      iso == null ? null : Timestamp.fromDate(DateTime.parse(iso as String));

  static String? _iso(Object? v) =>
      v is Timestamp ? v.toDate().toIso8601String() : null;
}
