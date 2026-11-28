import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/community.dart';
import '../data/notifications.dart';
import '../data/routes.dart';
import '../services/auth_service.dart';
import '../services/passport_remote.dart';
import '../services/photo_service.dart';
import '../services/validators.dart';

// Trạng thái này tương ứng document `user_passports/{uid}` và collection `reflections`.
// Luôn lưu một bản cục bộ bằng shared_preferences (localStorage trên web) để mở app
// nhanh và dùng được khi mất mạng; khi có [PassportRemote] (Cloud Firestore trên web)
// thì mỗi lần _commit() cũng ghi lên server.
const _storageKey = 'local-passport/v1';

/// Cài đặt riêng của máy, không đổi theo tài khoản.
const _demoKey = 'local-passport/demo-qr';
const _skipLocationKey = 'local-passport/skip-location';

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
    Map<String, String>? taskPhotoUrls,
    Map<String, String>? taskPhotos,
  }) : tasks = tasks ?? {},
       taskPhotoUrls = taskPhotoUrls ?? {},
       taskPhotos = taskPhotos ?? {};

  bool unlocked;
  DateTime? unlockedAt;
  final Set<String> tasks;

  /// Ảnh nhiệm vụ dạng Base64 đã nén nhỏ (tối đa [maxTaskPhotosPerVisit] ảnh/visit).
  final Map<String, String> taskPhotos;

  /// URL ảnh nhiệm vụ cũ — giữ để đọc tương thích ngược nếu từng lưu Storage URL.
  final Map<String, String> taskPhotoUrls;

  Map<String, dynamic> toJson() => {
    'unlocked': unlocked,
    'unlockedAt': unlockedAt?.toIso8601String(),
    'tasks': tasks.toList(),
    'taskPhotos': taskPhotos,
    if (taskPhotoUrls.isNotEmpty) 'taskPhotoUrls': taskPhotoUrls,
  };

  factory LocationProgress.fromJson(Map<String, dynamic> j) => LocationProgress(
    unlocked: j['unlocked'] as bool? ?? false,
    unlockedAt: j['unlockedAt'] == null
        ? null
        : DateTime.parse(j['unlockedAt'] as String),
    tasks: {...(j['tasks'] as List? ?? const []).cast<String>()},
    taskPhotoUrls: (j['taskPhotoUrls'] as Map<String, dynamic>? ?? {}).map(
      (k, v) => MapEntry(k, v as String),
    ),
    taskPhotos: (j['taskPhotos'] as Map<String, dynamic>? ?? {}).map(
      (k, v) => MapEntry(k, v as String),
    ),
  );
}

typedef RouteProgress = ({int stamped, int total, int percent});

class PassportStore extends ChangeNotifier {
  PassportStore._(
    this._prefs,
    this.remote,
    this.auth, {
    Duration leaderboardDebounce = const Duration(seconds: 5),
  }) : _leaderboardDebounce = leaderboardDebounce {
    remote?.state.addListener(_onSyncState);
  }

  final SharedPreferences _prefs;

  /// Nơi lưu trực tuyến (Cloud Firestore). null: chỉ lưu cục bộ.
  final PassportRemote? remote;

  /// Tài khoản (Firebase Auth). null: chỉ có hồ sơ cục bộ, không đăng nhập.
  final AuthGateway? auth;

  final Duration _leaderboardDebounce;
  Timer? _leaderboardTimer;
  String? _lastLeaderboardDigest;

  /// Thông báo trong app, mới nhất trước.
  List<AppNotification> notifications = [];

  /// Gọi mỗi khi có thông báo mới (main.dart dùng để hiện lên thanh thông
  /// báo của điện thoại).
  void Function(AppNotification note)? onNotify;

  /// Câu báo lỗi khi lưu thất bại (null: đang ổn). Giao diện hiện SnackBar.
  final saveProblem = ValueNotifier<String?>(null);

  /// uid của tài khoản sở hữu dữ liệu đang giữ trên máy.
  String? _ownerUid;
  int _noteSeq = 0;

  /// Bài cảm nhận của người khác tải từ Firestore (phân trang + realtime).
  List<Reflection> communityReflections = [];
  Object? _communityCursor;
  bool hasMoreCommunity = false;
  bool isLoadingMoreCommunity = false;
  StreamSubscription<List<Reflection>>? _communitySub;
  final Map<String, Reflection> _pagedCommunity = {};
  final Map<String, Reflection> _realtimeCommunity = {};

  /// Bảng xếp hạng công khai tải từ collection `leaderboard_public`.
  List<LeaderEntry> get remoteLeaderboard => leaders ?? const [];

  /// Cho phép nút "Giả lập quét QR" (dùng khi trình diễn không có mã QR thật).
  /// Chạy không có Firebase thì luôn bật.
  bool get demoQrEnabled =>
      remote == null || (_prefs.getBool(_demoKey) ?? false);

  void setDemoQr(bool enabled) {
    _prefs.setBool(_demoKey, enabled);
    notifyListeners();
  }

  /// Check-in vẫn phải quét mã QR thật của di tích, nhưng không đo khoảng
  /// cách GPS. Dùng khi thử/báo cáo ở xa di tích. Chỉ áp dụng trên máy này.
  bool get skipLocationCheck => _prefs.getBool(_skipLocationKey) ?? false;

  void setSkipLocationCheck(bool enabled) {
    _prefs.setBool(_skipLocationKey, enabled);
    notifyListeners();
  }

  /// Bảng tin: bài của mình và của mọi người, mới nhất trước. Bài mẫu chỉ hiện
  /// khi chạy không có Firebase.
  List<Reflection> get feed => [
    ...reflections,
    ...communityReflections,
    if (remote == null) ...seedReflections,
  ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Bảng xếp hạng tải từ Firestore (null: chưa tải được lần nào).
  List<LeaderEntry>? leaders;

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
    Duration leaderboardDebounce = const Duration(seconds: 5),
  }) async {
    final store = PassportStore._(
      await SharedPreferences.getInstance(),
      remote,
      auth,
      leaderboardDebounce: leaderboardDebounce,
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
    leaders = null;
  }

  // ---- Tài khoản ----

  /// Có đăng ký/đăng nhập bằng email (bản web và Android đã cấu hình Firebase).
  bool get hasAccounts => auth != null;

  /// Đang dùng tài khoản khách: dữ liệu mất khi đăng xuất.
  bool get isGuest => auth?.isGuest ?? false;

  String? get accountEmail => auth?.email;

  bool get emailVerified => auth?.emailVerified ?? false;

  bool get hasPasswordProvider => auth?.hasPasswordProvider ?? false;

  bool get hasGoogleProvider => auth?.hasGoogleProvider ?? false;

  bool get hasAppleProvider => auth?.hasAppleProvider ?? false;

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
    // Gửi email xác minh tự động (không chặn luồng đăng ký nếu mạng yếu).
    try {
      await a.sendEmailVerification();
    } catch (_) {}
  }

  /// Đăng nhập hoặc liên kết bằng Google.
  Future<void> signInWithGoogle() =>
      _signInWithProvider(() => auth!.signInWithGoogle(), 'Google');

  /// Đăng nhập hoặc liên kết bằng Apple.
  Future<void> signInWithApple() =>
      _signInWithProvider(() => auth!.signInWithApple(), 'Apple');

  Future<void> _signInWithProvider(
    Future<void> Function() action,
    String providerLabel,
  ) async {
    final a = auth!;
    final current = user;
    final keepGuestData = a.isGuest && current != null;
    await action();
    if (keepGuestData) {
      _ownerUid = a.uid;
      _notify(
        NotificationType.account,
        'Đã liên kết tài khoản $providerLabel',
        'Hộ chiếu của bạn đã được bảo lưu bằng tài khoản $providerLabel.',
      );
      _commit();
      return;
    }
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
      final fallbackName = (a.displayName?.trim().isNotEmpty == true)
          ? a.displayName!.trim()
          : (a.email?.split('@').first ?? 'Lữ khách');
      user = _newProfile(fallbackName);
      _welcome();
      _commit();
    }
  }

  Future<void> sendEmailVerification() => auth!.sendEmailVerification();

  /// Đổi tên hiển thị trên hộ chiếu, bảng xếp hạng và các bài cảm nhận
  /// không ẩn danh. Trả về câu báo lỗi nếu tên không hợp lệ.
  String? rename(String name) {
    final error = validateName(name);
    if (error != null) return error;
    final u = user;
    if (u == null) return 'Chưa có hộ chiếu để đổi tên.';
    final newName = name.trim();
    if (newName == u.name) return null;
    user = UserProfile(
      name: newName,
      passportNo: u.passportNo,
      joinedAt: u.joinedAt,
    );
    reflections = [
      for (final r in reflections)
        r.isAnonymous ? r : r.copyWith(displayAuthor: newName),
    ];
    _commit();
    return null;
  }

  Future<bool> refreshEmailVerification() async {
    final verified = await auth!.reloadUser();
    notifyListeners();
    return verified;
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => auth!.changePassword(
    currentPassword: currentPassword,
    newPassword: newPassword,
  );

  /// Xóa vĩnh viễn tài khoản và toàn bộ dữ liệu liên quan theo thứ tự an toàn:
  /// (1) Re-authenticate; (2) Xóa toàn bộ dữ liệu Firestore của `uid` theo lô <= 450;
  /// (3) Xóa tài khoản Auth; (4) Dọn trạng thái cục bộ. Nếu bước (1) hoặc (2) lỗi,
  /// giữ nguyên phiên để người dùng có thể thử lại.
  Future<void> deleteAccount({String? password}) async {
    // Tạm dừng đồng bộ bảng xếp hạng để tránh ghi lại document trong lúc đang xóa.
    _leaderboardTimer?.cancel();
    _leaderboardTimer = null;
    final a = auth;
    if (a != null) {
      await a.deleteAccount(
        password: password,
        beforeDeleteUser: (uid) async {
          await remote?.deleteAllUserData(uid);
        },
      );
    } else if (remote?.uid != null) {
      await remote!.deleteAllUserData(remote!.uid!);
    }
    _cancelLeaderboardSync();
    stopWatchingCommunity();
    remote?.forget();
    _clearState();
    _ownerUid = null;
    saveProblem.value = null;
    _saveLocal();
    notifyListeners();
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
    _cancelLeaderboardSync();
    stopWatchingCommunity();
    await auth?.signOut();
    remote?.forget();
    _clearState();
    _ownerUid = null;
    saveProblem.value = null;
    _saveLocal();
    notifyListeners();
  }

  @override
  void dispose() {
    _cancelLeaderboardSync();
    stopWatchingCommunity();
    remote?.state.removeListener(_onSyncState);
    super.dispose();
  }

  // ---- Thông báo ----

  int get unreadCount => notifications.where((n) => !n.read).length;

  void _notify(
    NotificationType type,
    String title,
    String body, {
    String? locationId,
  }) {
    final note = AppNotification(
      id: 'n${DateTime.now().millisecondsSinceEpoch}_${_noteSeq++}',
      type: type,
      title: title,
      body: body,
      createdAt: DateTime.now(),
      locationId: locationId,
    );
    notifications.insert(0, note);
    onNotify?.call(note);
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
    _scheduleLeaderboardSync();
    await Future.wait([refreshCommunity(), refreshLeaderboard()]);
  }

  /// Tải lại bảng xếp hạng từ Firestore. Trả về false nếu không tải được.
  Future<bool> refreshLeaderboard() async {
    final r = remote;
    if (r == null) return false;
    try {
      leaders = await r.fetchLeaderboard();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Danh sách xếp hạng để hiện: người khác lấy từ server, bản thân lấy từ
  /// máy (luôn mới nhất). Không có Firebase thì dùng danh sách mẫu.
  List<LeaderEntry> rankedEntries() {
    final myId = remote?.uid ?? _ownerUid;
    final me = LeaderEntry(
      myId ?? 'me',
      user?.name ?? 'Bạn',
      xp,
      totalStamps,
      isMe: true,
    );
    final others = remote == null
        ? sampleLeaderboard
        : (leaders ?? const <LeaderEntry>[]).where((e) => e.id != myId);
    return [...others, me]..sort(
      (a, b) =>
          b.xp != a.xp ? b.xp.compareTo(a.xp) : b.stamps.compareTo(a.stamps),
    );
  }

  void _rebuildCommunityList() {
    final merged = <String, Reflection>{
      ..._pagedCommunity,
      ..._realtimeCommunity,
    };
    final myIds = {for (final r in reflections) r.id};
    communityReflections =
        merged.values.where((x) => !myIds.contains(x.id)).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    notifyListeners();
  }

  /// Bắt đầu lắng nghe realtime các bài cảm nhận mới nhất (`snapshots()`).
  void startWatchingCommunity({int limit = 20}) {
    final r = remote;
    if (r == null || _communitySub != null) return;
    _communitySub = r
        .watchLatestCommunity(limit: limit)
        .listen(
          (latest) {
            _realtimeCommunity
              ..clear()
              ..addEntries(latest.map((item) => MapEntry(item.id, item)));
            // Đồng bộ aiScore mới nhất từ server cho bài viết của chính người dùng nếu có.
            var mineUpdated = false;
            for (var i = 0; i < reflections.length; i++) {
              final fromServer = _realtimeCommunity[reflections[i].id];
              if (fromServer != null &&
                  fromServer.aiScore > 0 &&
                  fromServer.aiScore != reflections[i].aiScore) {
                reflections[i] = reflections[i].copyWith(
                  aiScore: fromServer.aiScore,
                );
                mineUpdated = true;
              }
            }
            if (mineUpdated) _saveLocal();
            _rebuildCommunityList();
          },
          onError: (_) {
            // Giữ danh sách hiện có khi mất kết nối realtime.
          },
        );
  }

  /// Dừng lắng nghe stream realtime cộng đồng.
  void stopWatchingCommunity() {
    _communitySub?.cancel();
    _communitySub = null;
    _realtimeCommunity.clear();
  }

  /// Tải lại trang đầu bảng tin cộng đồng từ Firestore và bật stream realtime.
  Future<void> refreshCommunity({int pageSize = 20}) async {
    final r = remote;
    if (r == null) return;
    startWatchingCommunity(limit: pageSize);
    try {
      final page = await r.fetchCommunityPage(limit: pageSize);
      _pagedCommunity
        ..clear()
        ..addEntries(page.items.map((item) => MapEntry(item.id, item)));
      _communityCursor = page.cursor;
      hasMoreCommunity = page.hasMore;
      _rebuildCommunityList();
    } catch (_) {}
  }

  /// Tải trang tiếp theo cho infinite scroll bằng `startAfterDocument`.
  Future<void> loadMoreCommunity({int pageSize = 20}) async {
    final r = remote;
    if (r == null ||
        isLoadingMoreCommunity ||
        !hasMoreCommunity ||
        _communityCursor == null) {
      return;
    }
    isLoadingMoreCommunity = true;
    notifyListeners();
    try {
      final page = await r.fetchCommunityPage(
        limit: pageSize,
        startAfter: _communityCursor,
      );
      for (final item in page.items) {
        _pagedCommunity[item.id] = item;
      }
      _communityCursor = page.cursor;
      hasMoreCommunity = page.hasMore;
    } catch (_) {
      // Giữ trạng thái trang cũ để người dùng có thể cuộn thử lại.
    } finally {
      isLoadingMoreCommunity = false;
      _rebuildCommunityList();
    }
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
    'stampCount': totalStamps,
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
    _scheduleLeaderboardSync();
  }

  void _cancelLeaderboardSync() {
    _leaderboardTimer?.cancel();
    _leaderboardTimer = null;
    _lastLeaderboardDigest = null;
  }

  /// Đẩy tóm tắt `{displayName, xp, stampCount, avatarUrl}` lên `leaderboard_public/{uid}`
  /// có debounce (mặc định 5 giây) để tránh ghi liên tục khi người dùng tích nhiều nhiệm vụ.
  void _scheduleLeaderboardSync() {
    final r = remote;
    final u = user;
    if (r == null || u == null) return;
    final digest = '${u.name}|$xp|$totalStamps';
    if (digest == _lastLeaderboardDigest) return;
    _leaderboardTimer?.cancel();
    _leaderboardTimer = Timer(_leaderboardDebounce, () {
      unawaited(flushLeaderboardNow());
    });
  }

  /// Ghi ngay tóm tắt bảng xếp hạng hiện tại nếu có thay đổi.
  Future<void> flushLeaderboardNow() async {
    _leaderboardTimer?.cancel();
    _leaderboardTimer = null;
    final r = remote;
    final u = user;
    if (r == null || u == null) return;
    final digest = '${u.name}|$xp|$totalStamps';
    if (digest == _lastLeaderboardDigest) return;
    _lastLeaderboardDigest = digest;
    try {
      await r.syncLeaderboardEntry(
        displayName: u.name,
        xp: xp,
        stampCount: totalStamps,
      );
    } catch (_) {
      // Cho phép thử lại ở lần đồng bộ tiếp theo.
      _lastLeaderboardDigest = null;
    }
  }

  int get totalStamps => stamps.keys
      .where((id) => publishedLocations.any((l) => l.id == id))
      .length;
  int get totalLocations => publishedLocations.length;

  bool isUnlocked(String id) => progress[id]?.unlocked ?? false;
  bool isTaskDone(String id, String taskId) =>
      progress[id]?.tasks.contains(taskId) ?? false;

  String? taskPhoto(String id, String taskId) =>
      progress[id]?.taskPhotos[taskId] ?? progress[id]?.taskPhotoUrls[taskId];

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

  /// Nén ảnh nhỏ (<= 80 KB, cạnh dài ~720px, lặp giảm chất lượng) rồi lưu Base64
  /// vào trạng thái nhiệm vụ. Giới hạn tối đa [maxTaskPhotosPerVisit] ảnh/visit
  /// và kiểm tra ước lượng dung lượng document không vượt [maxFirestoreDocBytes].
  /// Trả về true nếu vừa nhận dấu mộc mới.
  Future<bool> saveTaskPhotoBytes(
    String id,
    String taskId,
    Uint8List bytes,
  ) async {
    final p = progress[id];
    final location = locationById[id];
    final task = location?.tasks.where((t) => t.id == taskId).firstOrNull;
    if (p == null || !p.unlocked || task?.type != TaskType.photo) return false;

    final alreadyHasSlot = p.taskPhotos.containsKey(taskId);
    if (!alreadyHasSlot && p.taskPhotos.length >= maxTaskPhotosPerVisit) {
      throw const PhotoLimitException(
        'Mỗi địa điểm chỉ lưu tối đa $maxTaskPhotosPerVisit ảnh nhiệm vụ.',
      );
    }

    // Trừ dung lượng prefix "<taskId>:" để phần tử list luôn <= 120000 ký tự.
    final maxB64 = photoMaxBase64Length - taskId.length - 1;
    var encoded = await compressImageToBase64(bytes, maxBase64Length: maxB64);

    // Ước lượng dung lượng document visit trước khi ghi; nếu > 800 KB thì nén thêm.
    Map<String, dynamic> buildCandidateDoc(String value) => {
      'unlocked': p.unlocked,
      'unlockedAt': p.unlockedAt?.toIso8601String(),
      'tasks': {...p.tasks, taskId}.toList(),
      'taskPhotos': encodeTaskPhotosList({...p.taskPhotos, taskId: value}),
      'taskPhotoUrls': p.taskPhotoUrls,
    };
    if (estimateFirestoreDocBytes(buildCandidateDoc(encoded)) >
        maxFirestoreDocBytes) {
      encoded = await compressImageToBase64(
        bytes,
        targetBytes: 40 * 1024,
        maxBase64Length: maxB64,
      );
      if (estimateFirestoreDocBytes(buildCandidateDoc(encoded)) >
          maxFirestoreDocBytes) {
        throw const PhotoLimitException(
          'Dung lượng dữ liệu địa điểm vượt giới hạn an toàn 800 KB. Hãy xóa bớt ảnh cũ trước khi thêm.',
        );
      }
    }

    return setTaskPhoto(id, taskId, encoded);
  }

  bool setTaskPhoto(String id, String taskId, String? photoValue) {
    final p = progress[id];
    final location = locationById[id];
    final task = location?.tasks.where((t) => t.id == taskId).firstOrNull;
    if (p == null || !p.unlocked || task?.type != TaskType.photo) return false;
    if (photoValue == null) {
      p.taskPhotoUrls.remove(taskId);
      p.taskPhotos.remove(taskId);
      p.tasks.remove(taskId);
    } else if (isNetworkImageUrl(photoValue)) {
      p.taskPhotoUrls[taskId] = photoValue;
      p.taskPhotos.remove(taskId);
      p.tasks.add(taskId);
    } else {
      if (!p.taskPhotos.containsKey(taskId) &&
          p.taskPhotos.length >= maxTaskPhotosPerVisit) {
        throw const PhotoLimitException(
          'Mỗi địa điểm chỉ lưu tối đa $maxTaskPhotosPerVisit ảnh nhiệm vụ.',
        );
      }
      p.taskPhotos[taskId] = photoValue;
      p.taskPhotoUrls.remove(taskId);
      p.tasks.add(taskId);
    }
    final stamped = _checkStamp(id);
    _commit();
    return stamped;
  }

  void addReflection({
    String? id,
    required String locationId,
    required String content,
    required bool isAnonymous,
    required int aiScore,
    required int bonusXp,
    String? photoUrl,
    String? photoBase64,
  }) {
    reflections.insert(
      0,
      Reflection(
        id: id ?? 'r${DateTime.now().millisecondsSinceEpoch}',
        locationId: locationId,
        displayAuthor: _authorName(isAnonymous),
        isAnonymous: isAnonymous,
        content: content,
        aiScore: aiScore,
        createdAt: DateTime.now(),
        photoUrl: photoUrl,
        photoBase64: photoUrl != null ? null : photoBase64,
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

  /// Sửa nội dung và/hoặc ảnh bài cảm nhận của chính tác giả; cập nhật `aiScore`
  /// từ kết quả chấm lại (heuristic offline hoặc endpoint ngoài), không cộng trùng XP.
  bool updateReflection({
    required String id,
    required String content,
    String? photoUrl,
    String? photoBase64,
    bool clearPhoto = false,
    int? aiScore,
  }) {
    final i = reflections.indexWhere((r) => r.id == id);
    if (i < 0) return false;
    final current = reflections[i];
    final trimmed = content.trim();
    if (trimmed.isEmpty) return false;

    final nextPhotoUrl = clearPhoto ? null : (photoUrl ?? current.photoUrl);
    final nextPhotoBase64 = clearPhoto
        ? null
        : (photoBase64 ?? (photoUrl != null ? null : current.photoBase64));

    reflections[i] = Reflection(
      id: current.id,
      locationId: current.locationId,
      displayAuthor: current.displayAuthor,
      isAnonymous: current.isAnonymous,
      content: trimmed,
      aiScore: aiScore ?? current.aiScore,
      createdAt: current.createdAt,
      photoUrl: nextPhotoUrl,
      photoBase64: nextPhotoBase64,
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
