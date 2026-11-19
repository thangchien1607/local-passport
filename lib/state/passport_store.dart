import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/community.dart';
import '../data/notifications.dart';
import '../data/routes.dart';
import '../services/auth_service.dart';
import '../services/passport_remote.dart';

// Trạng thái này tương ứng document `user_passports/{uid}` và collection `reflections`.
// Luôn lưu một bản cục bộ bằng shared_preferences (localStorage trên web) để mở app
// nhanh và dùng được khi mất mạng; khi có [PassportRemote] (Cloud Firestore trên web)
// thì mỗi lần _commit() cũng ghi lên server.
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
  PassportStore._(this._prefs, this.remote, this.auth) {
    remote?.state.addListener(_onSyncState);
  }

  final SharedPreferences _prefs;

  /// Nơi lưu trực tuyến (Cloud Firestore). null: chỉ lưu cục bộ.
  final PassportRemote? remote;

  /// Tài khoản (Firebase Auth). null: chỉ có hồ sơ cục bộ, không đăng nhập.
  final AuthGateway? auth;

  /// Thông báo trong app, mới nhất trước.
  List<AppNotification> notifications = [];

  /// Câu báo lỗi khi lưu thất bại (null: đang ổn). Giao diện hiện SnackBar.
  final saveProblem = ValueNotifier<String?>(null);

  /// uid của tài khoản sở hữu dữ liệu đang giữ trên máy.
  String? _ownerUid;
  int _noteSeq = 0;

  /// Bài cảm nhận của người khác tải từ Firestore.
  List<Reflection> communityReflections = [];

  /// Đã có thay đổi trước khi tải xong dữ liệu từ server: không ghi đè bằng bản server.
  bool _changedBeforePull = false;

  UserProfile? user;
  Map<String, LocationProgress> progress = {};
  Map<String, DateTime> stamps = {};
  int xp = 0;
  List<Reflection> reflections = [];

  static Future<PassportStore> load({
    PassportRemote? remote,
    AuthGateway? auth,
  }) async {
    final store = PassportStore._(
      await SharedPreferences.getInstance(),
      remote,
      auth,
    );
    store._load();
    if (auth != null) {
      // Dữ liệu trên máy chỉ dùng khi thuộc đúng tài khoản đang đăng nhập.
      final uid = auth.uid;
      if (uid == null || store._ownerUid != uid) {
        store._clearState();
        store._ownerUid = uid;
      }
    }
    if (remote != null && (auth == null || auth.uid != null)) {
      store._pullRemote();
    }
    return store;
  }

  void _onSyncState() {
    if (remote?.state.value == SyncState.error) {
      saveProblem.value =
          'Chưa lưu được lên máy chủ. Dữ liệu vẫn còn trên máy này.';
    } else if (remote?.state.value == SyncState.synced) {
      saveProblem.value = null;
    }
  }

  /// Gửi lại toàn bộ dữ liệu sau khi lưu thất bại.
  void retrySave() {
    saveProblem.value = null;
    _saveLocal();
    remote?.sync(_toJson());
  }

  void _clearState() {
    user = null;
    progress = {};
    stamps = {};
    xp = 0;
    reflections = [];
    notifications = [];
    _changedBeforePull = false;
  }

  // ---- Tài khoản ----

  /// Có đăng ký/đăng nhập bằng email (bản web và Android đã cấu hình Firebase).
  bool get hasAccounts => auth != null;

  /// Đang dùng tài khoản khách: dữ liệu mất khi đăng xuất.
  bool get isGuest => auth?.isGuest ?? false;

  String? get accountEmail => auth?.email;

  UserProfile _newProfile(String name) => UserProfile(
    name: name.trim().isEmpty ? 'Lữ khách' : name.trim(),
    passportNo: 'DN${100000 + Random().nextInt(899999)}',
    joinedAt: DateTime.now(),
  );

  /// Tạo tài khoản email. Nếu đang là khách thì giữ nguyên hộ chiếu hiện có.
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final a = auth!;
    final current = user;
    final keepGuestData = a.isGuest && current != null;
    await a.register(email, password);
    if (keepGuestData) {
      user = UserProfile(
        name: name.trim(),
        passportNo: current.passportNo,
        joinedAt: current.joinedAt,
      );
      _notify(
        NotificationType.account,
        'Đã lưu hộ chiếu vào tài khoản',
        'Đăng nhập bằng ${email.trim()} trên máy khác để đi tiếp hành trình.',
      );
    } else {
      remote?.forget();
      _clearState();
      user = _newProfile(name);
      _welcome();
    }
    _ownerUid = a.uid;
    _commit();
  }

  /// Đăng nhập email rồi tải hộ chiếu của tài khoản đó từ Firestore.
  Future<void> signIn({required String email, required String password}) async {
    final a = auth!;
    await a.signIn(email, password);
    remote?.forget();
    _clearState();
    _ownerUid = a.uid;
    try {
      await _pullRemote(rethrowErrors: true);
    } catch (_) {
      await a.signOut();
      _ownerUid = null;
      throw const AuthFailure(
        'Không tải được hộ chiếu từ máy chủ. Kiểm tra mạng rồi thử lại.',
      );
    }
    if (user == null) {
      // Tài khoản chưa có hộ chiếu (ví dụ lần ghi đầu tiên bị lỗi): tạo mới.
      user = _newProfile(email.split('@').first);
      _welcome();
      _commit();
    }
  }

  /// Vào nhanh bằng tài khoản khách (ẩn danh), có thể nâng lên tài khoản sau.
  Future<void> enterAsGuest(String name) async {
    final a = auth!;
    await a.signInGuest();
    remote?.forget();
    _clearState();
    _ownerUid = a.uid;
    user = _newProfile(name);
    _welcome();
    _commit();
  }

  Future<void> sendPasswordReset(String email) =>
      auth!.sendPasswordReset(email);

  /// Đăng xuất: chỉ xóa dữ liệu trên máy, dữ liệu trên server vẫn giữ.
  Future<void> logout() async {
    await auth?.signOut();
    remote?.forget();
    _clearState();
    _ownerUid = null;
    saveProblem.value = null;
    _saveLocal();
    notifyListeners();
  }

  // ---- Thông báo ----

  int get unreadCount => notifications.where((n) => !n.read).length;

  void _notify(
    NotificationType type,
    String title,
    String body, {
    String? locationId,
  }) {
    notifications.insert(
      0,
      AppNotification(
        id: 'n${DateTime.now().millisecondsSinceEpoch}_${_noteSeq++}',
        type: type,
        title: title,
        body: body,
        createdAt: DateTime.now(),
        locationId: locationId,
      ),
    );
    if (notifications.length > 50) {
      notifications.removeRange(50, notifications.length);
    }
  }

  void _welcome() => _notify(
    NotificationType.welcome,
    'Chào mừng ${user?.name ?? 'Lữ khách'}!',
    'Hộ chiếu ${user?.passportNo ?? ''} đã sẵn sàng. Đến một di tích và quét mã QR để nhận dấu mộc đầu tiên.',
  );

  /// Cộng XP và báo khi lên hạng.
  void _addXp(int amount) {
    if (amount <= 0) return;
    final before = rankForXp(xp).current;
    xp += amount;
    final after = rankForXp(xp).current;
    if (after.minXp > before.minXp) {
      _notify(
        NotificationType.rank,
        'Lên hạng ${after.title}!',
        'Bạn đã đạt $xp XP. Tiếp tục sưu tầm dấu mộc để lên hạng tiếp theo.',
      );
    }
  }

  void markNotificationRead(String id) {
    final i = notifications.indexWhere((n) => n.id == id);
    if (i < 0 || notifications[i].read) return;
    notifications[i] = notifications[i].copyWith(read: true);
    _commit();
  }

  void markAllNotificationsRead() {
    if (unreadCount == 0) return;
    notifications = [for (final n in notifications) n.copyWith(read: true)];
    _commit();
  }

  void deleteNotification(String id) {
    final before = notifications.length;
    notifications.removeWhere((n) => n.id == id);
    if (notifications.length != before) _commit();
  }

  void _load() {
    final raw = _prefs.getString(_storageKey);
    if (raw == null) return;
    _apply(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Lấy dữ liệu trên Firestore về; server chưa có thì đẩy bản cục bộ lên.
  Future<void> _pullRemote({bool rethrowErrors = false}) async {
    final r = remote;
    if (r == null) return;
    try {
      final data = await r.fetch();
      if (!_changedBeforePull) {
        if (data != null) {
          _apply(data);
          _saveLocal();
          notifyListeners();
        } else if (user != null) {
          r.sync(_toJson());
        }
      } else {
        r.sync(_toJson());
      }
    } catch (_) {
      // Không kết nối được: vẫn dùng bản cục bộ.
      if (rethrowErrors) rethrow;
      return;
    }
    await refreshCommunity();
  }

  /// Tải lại bài cảm nhận của mọi người từ Firestore.
  Future<void> refreshCommunity() async {
    final r = remote;
    if (r == null) return;
    try {
      final all = await r.fetchCommunity();
      communityReflections = all
          .where((x) => !reflections.any((m) => m.id == x.id))
          .toList();
      notifyListeners();
    } catch (_) {}
  }

  void _apply(Map<String, dynamic> j) {
    try {
      _ownerUid = j['uid'] as String? ?? _ownerUid;
      notifications = (j['notifications'] as List? ?? const [])
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .toList();
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

  Map<String, dynamic> _toJson() => {
    'uid': _ownerUid,
    'notifications': notifications.map((n) => n.toJson()).toList(),
    'user': user?.toJson(),
    'progress': progress.map((k, v) => MapEntry(k, v.toJson())),
    'stamps': stamps.map((k, v) => MapEntry(k, v.toIso8601String())),
    'xp': xp,
    'reflections': reflections.map((r) => r.toJson()).toList(),
  };

  void _saveLocal() {
    _prefs
        .setString(_storageKey, jsonEncode(_toJson()))
        .then(
          (ok) {
            if (!ok) {
              saveProblem.value = 'Không lưu được dữ liệu trên máy này.';
            }
            return ok;
          },
          onError: (_) {
            saveProblem.value =
                'Không lưu được dữ liệu trên máy (bộ nhớ đầy hoặc bị chặn).';
            return false;
          },
        );
  }

  void _commit() {
    notifyListeners();
    _saveLocal();
    _changedBeforePull = true;
    remote?.sync(_toJson());
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
    _notify(
      NotificationType.stamp,
      'Nhận dấu mộc ${locationById[id]?.name ?? id}',
      '+$stampXp XP. Hộ chiếu đã có $totalStamps/$totalLocations dấu mộc.',
      locationId: id,
    );
    _addXp(stampXp);
    return true;
  }

  /// Tạo hồ sơ chỉ lưu trên máy (khi không có Firebase, ví dụ iOS hoặc test).
  void login(String name) {
    user = _newProfile(name);
    _welcome();
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
    _notify(
      NotificationType.reflection,
      'Cảm nhận đã được đăng',
      'Bài tại ${locationById[locationId]?.name ?? locationId} đã lên Bảng tin'
          '${bonusXp > 0 ? ', +$bonusXp XP' : ''}.',
      locationId: locationId,
    );
    _addXp(bonusXp);
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
    notifications = [];
    _commit();
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
