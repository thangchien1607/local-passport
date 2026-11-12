import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/community.dart';
import '../data/routes.dart';

// Trạng thái này tương ứng document `user_passports/{uid}` và collection `reflections`.
// Bản MVP lưu bằng shared_preferences (localStorage trên web);
// khi nối Firestore chỉ cần thay _load/_save.
const _storageKey = 'local-passport/v1';

class UserProfile {
  const UserProfile({
    required this.name,
    required this.passportNo,
    required this.joinedAt,
  });

  final String name;
  final String passportNo;
  final DateTime joinedAt;

  Map<String, dynamic> toJson() => {
    'name': name,
    'passportNo': passportNo,
    'joinedAt': joinedAt.toIso8601String(),
  };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    name: j['name'] as String,
    passportNo: j['passportNo'] as String,
    joinedAt: DateTime.parse(j['joinedAt'] as String),
  );
}

class LocationProgress {
  LocationProgress({
    this.unlocked = false,
    this.unlockedAt,
    Set<String>? tasks,
    Map<String, String>? taskPhotos,
  }) : tasks = tasks ?? {},
       taskPhotos = taskPhotos ?? {};

  bool unlocked;
  DateTime? unlockedAt;
  final Set<String> tasks;
  final Map<String, String> taskPhotos;

  Map<String, dynamic> toJson() => {
    'unlocked': unlocked,
    'unlockedAt': unlockedAt?.toIso8601String(),
    'tasks': tasks.toList(),
    'taskPhotos': taskPhotos,
  };

  factory LocationProgress.fromJson(Map<String, dynamic> j) => LocationProgress(
    unlocked: j['unlocked'] as bool? ?? false,
    unlockedAt: j['unlockedAt'] == null
        ? null
        : DateTime.parse(j['unlockedAt'] as String),
    tasks: {...(j['tasks'] as List? ?? const []).cast<String>()},
    taskPhotos: (j['taskPhotos'] as Map<String, dynamic>? ?? {}).map(
      (k, v) => MapEntry(k, v as String),
    ),
  );
}

typedef RouteProgress = ({int stamped, int total, int percent});

class PassportStore extends ChangeNotifier {
  PassportStore._(this._prefs);

  final SharedPreferences _prefs;

  UserProfile? user;
  Map<String, LocationProgress> progress = {};
  Map<String, DateTime> stamps = {};
  int xp = 0;
  List<Reflection> reflections = [];

  static Future<PassportStore> load() async {
    final store = PassportStore._(await SharedPreferences.getInstance());
    store._load();
    return store;
  }

  void _load() {
    final raw = _prefs.getString(_storageKey);
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      user = j['user'] == null
          ? null
          : UserProfile.fromJson(j['user'] as Map<String, dynamic>);
      progress = (j['progress'] as Map<String, dynamic>? ?? {}).map(
        (k, v) =>
            MapEntry(k, LocationProgress.fromJson(v as Map<String, dynamic>)),
      );
      stamps = (j['stamps'] as Map<String, dynamic>? ?? {}).map(
        (k, v) => MapEntry(k, DateTime.parse(v as String)),
      );
      xp = j['xp'] as int? ?? 0;
      reflections = (j['reflections'] as List? ?? const [])
          .map((e) => Reflection.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Dữ liệu hỏng: bắt đầu lại từ trạng thái trống.
    }
  }

  void _commit() {
    notifyListeners();
    final data = {
      'user': user?.toJson(),
      'progress': progress.map((k, v) => MapEntry(k, v.toJson())),
      'stamps': stamps.map((k, v) => MapEntry(k, v.toIso8601String())),
      'xp': xp,
      'reflections': reflections.map((r) => r.toJson()).toList(),
    };
    _prefs.setString(_storageKey, jsonEncode(data)).catchError((_) => false);
  }

  int get totalStamps => stamps.keys
      .where((id) => publishedLocations.any((l) => l.id == id))
      .length;
  int get totalLocations => publishedLocations.length;

  bool isUnlocked(String id) => progress[id]?.unlocked ?? false;
  bool isTaskDone(String id, String taskId) =>
      progress[id]?.tasks.contains(taskId) ?? false;

  String? taskPhoto(String id, String taskId) =>
      progress[id]?.taskPhotos[taskId];

  /// Progress_location = (QR + số mục checklist xong) / (1 + tổng số mục checklist) × 100%
  int locationProgress(String id) {
    final loc = locationById[id];
    final p = progress[id];
    if (loc == null || p == null) return 0;
    final done = loc.tasks.where((t) => p.tasks.contains(t.id)).length;
    return (((p.unlocked ? 1 : 0) + done) / (1 + loc.tasks.length) * 100)
        .round();
  }

  /// Progress_route = số dấu mộc trong tuyến / tổng số địa điểm của tuyến × 100%
  RouteProgress routeProgress(String routeId) {
    final locs = locationsOfRoute(routeId);
    final stamped = locs.where((l) => stamps.containsKey(l.id)).length;
    if (locs.isEmpty) return (stamped: 0, total: 0, percent: 0);
    return (
      stamped: stamped,
      total: locs.length,
      percent: (stamped / locs.length * 100).round(),
    );
  }

  /// Đóng mộc nếu địa điểm vừa đạt 100%. Trả về true nếu vừa nhận mộc mới.
  bool _checkStamp(String id) {
    if (stamps.containsKey(id) || locationProgress(id) < 100) return false;
    stamps[id] = DateTime.now();
    xp += stampXp;
    return true;
  }

  void login(String name) {
    user = UserProfile(
      name: name.isEmpty ? 'Lữ khách' : name,
      passportNo: 'DN${100000 + Random().nextInt(899999)}',
      joinedAt: DateTime.now(),
    );
    _commit();
  }

  bool unlock(String id) {
    final p = progress.putIfAbsent(id, LocationProgress.new);
    if (p.unlocked) return false;
    p
      ..unlocked = true
      ..unlockedAt = DateTime.now();
    final stamped = _checkStamp(id);
    _commit();
    return stamped;
  }

  bool setTask(String id, String taskId, bool done) {
    final p = progress[id];
    final task = locationById[id]?.tasks
        .where((t) => t.id == taskId)
        .firstOrNull;
    if (p == null || !p.unlocked || p.tasks.contains(taskId) == done) {
      return false;
    }
    if (task?.type == TaskType.photo) return false;
    done ? p.tasks.add(taskId) : p.tasks.remove(taskId);
    final stamped = _checkStamp(id);
    _commit();
    return stamped;
  }

  bool setTaskPhoto(String id, String taskId, String? photoBase64) {
    final p = progress[id];
    final location = locationById[id];
    final task = location?.tasks.where((t) => t.id == taskId).firstOrNull;
    if (p == null || !p.unlocked || task?.type != TaskType.photo) return false;
    if (photoBase64 == null) {
      p.taskPhotos.remove(taskId);
      p.tasks.remove(taskId);
    } else {
      p.taskPhotos[taskId] = photoBase64;
      p.tasks.add(taskId);
    }
    final stamped = _checkStamp(id);
    _commit();
    return stamped;
  }

  void addReflection({
    required String locationId,
    required String content,
    required bool isAnonymous,
    required int aiScore,
    required int bonusXp,
    String? photoBase64,
  }) {
    reflections.insert(
      0,
      Reflection(
        id: 'r${DateTime.now().millisecondsSinceEpoch}',
        locationId: locationId,
        displayAuthor: _authorName(isAnonymous),
        isAnonymous: isAnonymous,
        content: content,
        aiScore: aiScore,
        createdAt: DateTime.now(),
        photoBase64: photoBase64,
      ),
    );
    xp += bonusXp;
    _commit();
  }

  String _authorName(bool isAnonymous) =>
      isAnonymous ? anonymousAuthor : (user?.name ?? 'Lữ khách');

  /// Bài này có phải của người dùng (sửa/xóa được) không. Bài mẫu chỉ đọc.
  bool isMyReflection(String id) => reflections.any((r) => r.id == id);

  /// Đổi chế độ ẩn danh của bài cảm nhận; giữ nguyên nội dung, điểm AI, ảnh, ngày tạo.
  bool setReflectionAnonymous(String id, bool isAnonymous) {
    final i = reflections.indexWhere((r) => r.id == id);
    if (i < 0 || reflections[i].isAnonymous == isAnonymous) return false;
    reflections[i] = reflections[i].copyWith(
      isAnonymous: isAnonymous,
      displayAuthor: _authorName(isAnonymous),
    );
    _commit();
    return true;
  }

  /// Xóa bài cảm nhận. Không trừ XP, không đụng dấu mộc.
  bool deleteReflection(String id) {
    final before = reflections.length;
    reflections.removeWhere((r) => r.id == id);
    if (reflections.length == before) return false;
    _commit();
    return true;
  }

  void reset() {
    progress = {};
    stamps = {};
    xp = 0;
    reflections = [];
    _commit();
  }

  void logout() {
    user = null;
    reset();
  }
}

class PassportScope extends InheritedNotifier<PassportStore> {
  const PassportScope({
    super.key,
    required PassportStore store,
    required super.child,
  }) : super(notifier: store);

  static PassportStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PassportScope>()!.notifier!;

  static PassportStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<PassportScope>()!.notifier!;
}
