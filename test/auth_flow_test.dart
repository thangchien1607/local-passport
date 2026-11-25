import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_passport/data/community.dart';
import 'package:local_passport/data/notifications.dart';
import 'package:local_passport/data/routes.dart';
import 'package:local_passport/services/auth_service.dart';
import 'package:local_passport/services/passport_remote.dart';
import 'package:local_passport/state/passport_store.dart';
import 'package:local_passport/widgets/auth_form.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Firebase Auth giả: lưu tài khoản trong bộ nhớ.
class FakeAuth implements AuthGateway {
  final accounts = <String, ({String password, String uid})>{};
  String? _uid;
  String? _email;
  String? _displayName;
  bool _guest = false;
  bool _verified = false;
  bool _hasPassword = false;
  bool _hasGoogle = false;
  bool _hasApple = false;
  bool failNextReauthWithRecentLogin = false;
  final deleteEvents = <String>[];
  int verificationEmailsSent = 0;
  int accountsDeleted = 0;
  int _next = 1;

  @override
  String? get uid => _uid;
  @override
  String? get email => _email;
  @override
  String? get displayName => _displayName;
  @override
  bool get isGuest => _guest;
  @override
  bool get emailVerified => _verified;
  @override
  bool get hasPasswordProvider => _hasPassword;
  @override
  bool get hasGoogleProvider => _hasGoogle;
  @override
  bool get hasAppleProvider => _hasApple;

  @override
  Future<void> register(String email, String password) async {
    if (accounts.containsKey(email)) {
      throw AuthFailure(authErrorMessage('email-already-in-use'));
    }
    // Khách thì giữ nguyên uid (giống linkWithCredential).
    final uid = _guest ? _uid! : 'u${_next++}';
    accounts[email] = (password: password, uid: uid);
    _uid = uid;
    _email = email;
    _guest = false;
    _verified = false;
    _hasPassword = true;
    _hasGoogle = false;
    _hasApple = false;
  }

  @override
  Future<void> signIn(String email, String password) async {
    final a = accounts[email];
    if (a == null || a.password != password) {
      throw AuthFailure(authErrorMessage('invalid-credential'));
    }
    _uid = a.uid;
    _email = email;
    _guest = false;
    _hasPassword = true;
    _hasGoogle = false;
    _hasApple = false;
  }

  @override
  Future<void> signInWithGoogle() async {
    _uid = _guest ? _uid! : 'google-${_next++}';
    _email = 'traveler@gmail.com';
    _displayName = 'Lữ khách Google';
    _guest = false;
    _verified = true;
    _hasPassword = false;
    _hasGoogle = true;
    _hasApple = false;
  }

  @override
  Future<void> signInWithApple() async {
    _uid = _guest ? _uid! : 'apple-${_next++}';
    _email = 'traveler@icloud.com';
    _displayName = 'Lữ khách Apple';
    _guest = false;
    _verified = true;
    _hasPassword = false;
    _hasGoogle = false;
    _hasApple = true;
  }

  @override
  Future<void> signInGuest() async {
    _uid = 'g${_next++}';
    _email = null;
    _displayName = null;
    _guest = true;
    _verified = false;
    _hasPassword = false;
    _hasGoogle = false;
    _hasApple = false;
  }

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> sendEmailVerification() async {
    verificationEmailsSent++;
  }

  @override
  Future<bool> reloadUser() async {
    _verified = true;
    return _verified;
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final e = _email;
    if (e == null || !accounts.containsKey(e)) {
      throw const AuthFailure('Tài khoản hiện tại không dùng mật khẩu.');
    }
    final a = accounts[e]!;
    if (a.password != currentPassword) {
      throw AuthFailure(authErrorMessage('wrong-password'));
    }
    accounts[e] = (password: newPassword, uid: a.uid);
  }

  @override
  Future<void> deleteAccount({
    String? password,
    Future<void> Function(String uid)? beforeDeleteUser,
  }) async {
    final currentUid = _uid;
    if (currentUid == null) return;
    if (failNextReauthWithRecentLogin) {
      failNextReauthWithRecentLogin = false;
      throw AuthFailure(authErrorMessage('requires-recent-login'));
    }
    // (1) Re-auth theo nhà cung cấp.
    if (!_guest) {
      if (_hasPassword) {
        final e = _email;
        final a = e == null ? null : accounts[e];
        if (password == null || password.isEmpty) {
          throw const AuthFailure(
            'Nhập mật khẩu hiện tại để xác nhận xóa tài khoản.',
          );
        }
        if (a == null || a.password != password) {
          throw AuthFailure(authErrorMessage('wrong-password'));
        }
        deleteEvents.add('reauth:password');
      } else if (_hasGoogle) {
        deleteEvents.add('reauth:google');
      } else if (_hasApple) {
        deleteEvents.add('reauth:apple');
      }
    }
    // (2) Xóa dữ liệu Firestore; lỗi giữa chừng -> không xóa Auth user.
    if (beforeDeleteUser != null) {
      try {
        await beforeDeleteUser(currentUid);
        deleteEvents.add('firestore:deleted:$currentUid');
      } on AuthFailure {
        rethrow;
      } catch (_) {
        throw const AuthFailure(
          'Không xóa được toàn bộ dữ liệu trên máy chủ. Tài khoản chưa bị xóa, vui lòng kiểm tra mạng rồi thử lại.',
        );
      }
    }
    // (3) Xóa Auth user.
    if (_email != null) accounts.remove(_email);
    accountsDeleted++;
    deleteEvents.add('auth:deleted:$currentUid');
    await signOut();
  }

  @override
  Future<void> signOut() async {
    _uid = null;
    _email = null;
    _displayName = null;
    _guest = false;
    _verified = false;
    _hasPassword = false;
    _hasGoogle = false;
    _hasApple = false;
  }
}

/// Firestore giả: mỗi uid một bản dữ liệu.
class FakeRemote implements PassportRemote {
  FakeRemote(this.auth);

  final FakeAuth auth;
  final servers = <String, Map<String, dynamic>>{};
  bool failFetch = false;
  bool failDeleteData = false;
  int deleteDataCalls = 0;

  @override
  final state = ValueNotifier(SyncState.synced);

  @override
  String? get uid => auth.uid;

  @override
  Future<Map<String, dynamic>?> fetch() async {
    if (failFetch) throw Exception('mất mạng');
    final u = uid;
    return u == null ? null : servers[u];
  }

  @override
  Future<List<Reflection>> fetchCommunity() async => [];

  @override
  Future<CommunityPage> fetchCommunityPage({
    int limit = 20,
    Object? startAfter,
  }) async => const CommunityPage(items: [], hasMore: false);

  @override
  Stream<List<Reflection>> watchLatestCommunity({int limit = 20}) =>
      const Stream.empty();

  @override
  Future<List<LeaderEntry>> fetchLeaderboard({int limit = 50}) async => [
    ...leaders,
  ];

  @override
  Future<void> syncLeaderboardEntry({
    required String displayName,
    required int xp,
    required int stampCount,
    String? avatarUrl,
  }) async {}

  @override
  Future<void> sync(Map<String, dynamic> data) async {
    final u = uid;
    if (u != null) servers[u] = data;
  }

  final leaders = <LeaderEntry>[];

  @override
  Future<void> deleteAllUserData(String uid) async {
    deleteDataCalls++;
    if (failDeleteData) {
      throw Exception('mất mạng giữa chừng khi xóa Firestore');
    }
    servers.remove(uid);
  }

  @override
  void forget() {}
}

Future<(PassportStore, FakeAuth, FakeRemote)> _setup() async {
  SharedPreferences.setMockInitialValues({});
  final auth = FakeAuth();
  final remote = FakeRemote(auth);
  final store = await PassportStore.load(remote: remote, auth: auth);
  return (store, auth, remote);
}

void main() {
  test('Đăng ký tạo hộ chiếu trên server và thông báo chào mừng', () async {
    final (store, auth, remote) = await _setup();
    expect(store.user, isNull);
    await store.register(
      name: 'Gia Huy',
      email: 'huy@gmail.com',
      password: 'danang2026',
    );
    expect(store.user?.name, 'Gia Huy');
    expect(store.accountEmail, 'huy@gmail.com');
    expect(remote.servers[auth.uid]!['user']['name'], 'Gia Huy');
    expect(store.notifications.single.type, NotificationType.welcome);
    expect(store.unreadCount, 1);
  });

  test(
    'Đăng xuất không xóa dữ liệu trên server; đăng nhập lại có đủ',
    () async {
      final (store, auth, remote) = await _setup();
      await store.register(
        name: 'Gia Huy',
        email: 'huy@gmail.com',
        password: 'danang2026',
      );
      store.unlock('dien-hai');
      final uid = auth.uid!;

      await store.logout();
      expect(store.user, isNull);
      expect(store.isUnlocked('dien-hai'), isFalse);
      expect(remote.servers[uid]!['user'], isNotNull);

      await expectLater(
        store.signIn(email: 'huy@gmail.com', password: 'sai-mat-khau1'),
        throwsA(
          isA<AuthFailure>().having(
            (e) => e.message,
            'message',
            'Email hoặc mật khẩu không đúng.',
          ),
        ),
      );
      await store.signIn(email: 'huy@gmail.com', password: 'danang2026');
      expect(store.user?.name, 'Gia Huy');
      expect(store.isUnlocked('dien-hai'), isTrue);
    },
  );

  test(
    'Đăng nhập nhưng không tải được hộ chiếu thì báo lỗi, không ghi đè',
    () async {
      final (store, auth, remote) = await _setup();
      await store.register(
        name: 'Gia Huy',
        email: 'huy@gmail.com',
        password: 'danang2026',
      );
      final uid = auth.uid!;
      await store.logout();
      remote.failFetch = true;

      await expectLater(
        store.signIn(email: 'huy@gmail.com', password: 'danang2026'),
        throwsA(isA<AuthFailure>()),
      );
      expect(auth.uid, isNull);
      expect(store.user, isNull);
      expect(remote.servers[uid]!['user']['name'], 'Gia Huy');
    },
  );

  test('Email đã dùng thì báo lỗi dễ hiểu', () async {
    final (store, _, _) = await _setup();
    await store.register(name: 'A', email: 'a@gmail.com', password: 'abc12345');
    await store.logout();
    await expectLater(
      store.register(name: 'B', email: 'a@gmail.com', password: 'abc12345'),
      throwsA(
        isA<AuthFailure>().having(
          (e) => e.message,
          'message',
          contains('đã có tài khoản'),
        ),
      ),
    );
  });

  test('Khách lưu vào tài khoản thì giữ nguyên tiến độ và dấu mộc', () async {
    final (store, auth, remote) = await _setup();
    await store.enterAsGuest('Khách');
    expect(store.isGuest, isTrue);
    final guestUid = auth.uid;
    store.unlock('dien-hai');

    await store.register(
      name: 'Minh Khoa',
      email: 'khoa@gmail.com',
      password: 'danang2026',
    );
    expect(store.isGuest, isFalse);
    expect(auth.uid, guestUid);
    expect(store.user?.name, 'Minh Khoa');
    expect(store.isUnlocked('dien-hai'), isTrue);
    expect(remote.servers[guestUid]!['user']['name'], 'Minh Khoa');
  });

  test('Dữ liệu trên máy của tài khoản khác không được dùng', () async {
    SharedPreferences.setMockInitialValues({});
    final auth = FakeAuth();
    final remote = FakeRemote(auth);
    final first = await PassportStore.load(remote: remote, auth: auth);
    await first.register(name: 'A', email: 'a@gmail.com', password: 'abc12345');
    first.unlock('dien-hai');

    // Mở lại app nhưng phiên đăng nhập đã hết.
    await auth.signOut();
    final again = await PassportStore.load(remote: remote, auth: auth);
    expect(again.user, isNull);
    expect(again.isUnlocked('dien-hai'), isFalse);
  });

  test('Nhận dấu mộc và lên hạng sinh thông báo; đọc và xóa được', () async {
    final (store, _, _) = await _setup();
    await store.register(name: 'A', email: 'a@gmail.com', password: 'abc12345');
    store.markAllNotificationsRead();
    expect(store.unreadCount, 0);

    store.unlock('dien-hai');
    for (final t in locationById['dien-hai']!.tasks) {
      store.setTask('dien-hai', t.id, true);
    }
    final stamp = store.notifications.firstWhere(
      (n) => n.type == NotificationType.stamp,
    );
    expect(stamp.locationId, 'dien-hai');
    expect(stamp.title, contains('Thành Điện Hải'));

    store.addReflection(
      locationId: 'dien-hai',
      content: 'Đứng trên tường thành nhìn ra cửa sông Hàn.',
      isAnonymous: false,
      aiScore: 90,
      bonusXp: 250,
    );
    // 100 + 250 = 350 XP: vượt mốc hạng tiếp theo.
    expect(
      store.notifications.where((n) => n.type == NotificationType.rank),
      isNotEmpty,
    );
    expect(store.unreadCount, greaterThanOrEqualTo(3));

    store.markNotificationRead(stamp.id);
    expect(
      store.notifications.firstWhere((n) => n.id == stamp.id).read,
      isTrue,
    );
    store.deleteNotification(stamp.id);
    expect(store.notifications.any((n) => n.id == stamp.id), isFalse);
  });

  testWidgets('Form đăng ký báo lỗi đầu vào và lỗi từ máy chủ', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final (store, _, _) =
        await tester.runAsync(_setup) ?? (throw StateError(''));
    await tester.runAsync(
      () =>
          store.register(name: 'A', email: 'a@gmail.com', password: 'abc12345'),
    );
    await tester.runAsync(store.logout);
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PassportScope(
            store: store,
            child: const SingleChildScrollView(
              child: AuthForm(initialMode: AuthMode.register),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Tạo tài khoản'));
    await tester.pump();
    expect(find.text('Nhập tên hiển thị trên hộ chiếu'), findsOneWidget);
    expect(find.text('Nhập email'), findsOneWidget);
    expect(find.text('Nhập mật khẩu'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'B');
    await tester.enterText(fields.at(1), 'a@gmail.com');
    await tester.enterText(fields.at(2), 'abc12345');
    await tester.enterText(fields.at(3), 'abc12346');
    await tester.pump();
    expect(find.text('Mật khẩu nhập lại không khớp'), findsOneWidget);

    await tester.enterText(fields.at(3), 'abc12345');
    await tester.tap(find.text('Tạo tài khoản'));
    await tester.pumpAndSettle();
    expect(
      find.text('Email này đã có tài khoản. Hãy đăng nhập.'),
      findsOneWidget,
    );
    expect(store.user, isNull);
    expect(find.text('Google'), findsOneWidget);
    expect(find.text('Apple'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'Google/Apple Sign-In, xác minh email, đổi mật khẩu và xóa tài khoản hoạt động đúng',
    () async {
      final (store, auth, _) = await _setup();

      // Đăng ký email -> tự động gửi email xác minh.
      await store.register(
        name: 'Lan Anh',
        email: 'lan@gmail.com',
        password: 'danang2026',
      );
      expect(auth.verificationEmailsSent, 1);
      expect(store.emailVerified, isFalse);

      await store.refreshEmailVerification();
      expect(store.emailVerified, isTrue);

      // Đổi mật khẩu: sai mật khẩu cũ bị từ chối, đúng thì đổi được.
      await expectLater(
        store.changePassword(
          currentPassword: 'sai-password1',
          newPassword: 'danang2027',
        ),
        throwsA(isA<AuthFailure>()),
      );
      await store.changePassword(
        currentPassword: 'danang2026',
        newPassword: 'danang2027',
      );
      await store.logout();
      await store.signIn(email: 'lan@gmail.com', password: 'danang2027');
      expect(store.user?.name, 'Lan Anh');

      // Xóa tài khoản -> xác thực lại mật khẩu, xóa dữ liệu Firestore rồi xóa tài khoản Auth.
      await store.deleteAccount(password: 'danang2027');
      expect(auth.accountsDeleted, 1);
      expect(store.user, isNull);
      expect(auth.uid, isNull);

      // Đăng nhập Google tạo hộ chiếu mới; nâng khách lên Apple giữ nguyên tiến độ.
      await store.signInWithGoogle();
      expect(store.user?.name, 'Lữ khách Google');
      await store.logout();

      await store.enterAsGuest('Khách tạm');
      store.unlock('dien-hai');
      await store.signInWithApple();
      expect(store.isGuest, isFalse);
      expect(store.isUnlocked('dien-hai'), isTrue);
    },
  );

  test(
    'S5 Xóa tài khoản theo thứ tự re-auth -> xóa Firestore -> xóa Auth; lỗi giữa chừng giữ phiên để thử lại',
    () async {
      final (store, auth, remote) = await _setup();
      await store.register(
        name: 'Minh Thư',
        email: 'thu@gmail.com',
        password: 'danang2026',
      );
      final uid = auth.uid!;
      expect(remote.servers.containsKey(uid), isTrue);

      // 1. Sai mật khẩu: dừng ngay ở bước re-auth, không xóa Firestore và không xóa Auth.
      await expectLater(
        store.deleteAccount(password: 'sai-mat-khau'),
        throwsA(isA<AuthFailure>()),
      );
      expect(remote.deleteDataCalls, 0);
      expect(remote.servers.containsKey(uid), isTrue);
      expect(auth.uid, uid);
      expect(store.user?.name, 'Minh Thư');

      // 2. Lỗi requires-recent-login: thông báo rõ ràng, không xóa dữ liệu/tài khoản.
      auth.failNextReauthWithRecentLogin = true;
      await expectLater(
        store.deleteAccount(password: 'danang2026'),
        throwsA(
          isA<AuthFailure>().having(
            (e) => e.message,
            'message',
            contains('xác thực lại'),
          ),
        ),
      );
      expect(remote.deleteDataCalls, 0);
      expect(auth.accountsDeleted, 0);

      // 3. Lỗi xóa Firestore giữa chừng: KHÔNG xóa Auth user để người dùng thử lại.
      remote.failDeleteData = true;
      await expectLater(
        store.deleteAccount(password: 'danang2026'),
        throwsA(
          isA<AuthFailure>().having(
            (e) => e.message,
            'message',
            contains('Tài khoản chưa bị xóa'),
          ),
        ),
      );
      expect(remote.deleteDataCalls, 1);
      expect(auth.accountsDeleted, 0);
      expect(auth.uid, uid);
      expect(store.user?.name, 'Minh Thư');

      // 4. Thử lại khi mạng ổn: chạy đúng thứ tự re-auth -> xóa Firestore -> xóa Auth -> dọn cục bộ.
      auth.deleteEvents.clear();
      remote.failDeleteData = false;
      await store.deleteAccount(password: 'danang2026');
      expect(auth.deleteEvents, [
        'reauth:password',
        'firestore:deleted:$uid',
        'auth:deleted:$uid',
      ]);
      expect(remote.servers.containsKey(uid), isFalse);
      expect(auth.accountsDeleted, 1);
      expect(auth.uid, isNull);
      expect(store.user, isNull);

      // 5. Tài khoản Google tự re-auth qua Google provider mà không cần mật khẩu.
      auth.deleteEvents.clear();
      await store.signInWithGoogle();
      final googleUid = auth.uid!;
      await store.deleteAccount();
      expect(auth.deleteEvents, [
        'reauth:google',
        'firestore:deleted:$googleUid',
        'auth:deleted:$googleUid',
      ]);
      expect(store.user, isNull);
    },
  );
}
