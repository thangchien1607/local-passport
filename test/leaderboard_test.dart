import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_passport/data/community.dart';
import 'package:local_passport/screens/leaderboard_screen.dart';
import 'package:local_passport/services/passport_remote.dart';
import 'package:local_passport/state/passport_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _LeaderboardFakeRemote implements PassportRemote {
  _LeaderboardFakeRemote(this.entries);

  final List<LeaderEntry> entries;
  final pushedEntries =
      <({String displayName, int xp, int stampCount, String? avatarUrl})>[];

  @override
  final state = ValueNotifier(SyncState.synced);
  @override
  String? get uid => 'u-me';
  @override
  Future<Map<String, dynamic>?> fetch() async => null;
  @override
  Future<List<Reflection>> fetchCommunity() async => const [];
  @override
  Future<CommunityPage> fetchCommunityPage({
    int limit = 20,
    Object? startAfter,
  }) async => const CommunityPage(items: [], hasMore: false);
  @override
  Stream<List<Reflection>> watchLatestCommunity({int limit = 20}) =>
      const Stream.empty();
  @override
  Future<List<LeaderEntry>> fetchLeaderboard({int limit = 50}) async => entries;
  @override
  Future<void> syncLeaderboardEntry({
    required String displayName,
    required int xp,
    required int stampCount,
    String? avatarUrl,
  }) async {
    pushedEntries.add((
      displayName: displayName,
      xp: xp,
      stampCount: stampCount,
      avatarUrl: avatarUrl,
    ));
  }

  @override
  Future<void> sync(Map<String, dynamic> data) async {}
  @override
  Future<void> deleteAllUserData(String uid) async {}
  @override
  void forget() {}
}

void main() {
  testWidgets('Bảng xếp hạng có bục top 3, vị trí của bạn và các bậc', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    final store = await PassportStore.load();
    store.login('Gia Huy');
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PassportScope(store: store, child: const LeaderboardScreen()),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('VỊ TRÍ CỦA BẠN'), findsOneWidget);
    expect(find.text('#8'), findsOneWidget);
    // Bục top 3: hạng 1 có 1180 XP; danh sách bên dưới bắt đầu từ hạng 4.
    expect(find.text('1180 XP'), findsOneWidget);
    expect(find.text('560 XP'), findsOneWidget);
    expect(find.text('5 dấu mộc'), findsOneWidget);
    expect(find.text('10 dấu mộc'), findsNothing);
    expect(find.text('Gia Huy (Bạn)'), findsNWidgets(2));
    expect(find.text('Tân binh'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Hiển thị dữ liệu bảng xếp hạng công khai từ leaderboard_public',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      SharedPreferences.setMockInitialValues({});
      final remote = _LeaderboardFakeRemote(const [
        LeaderEntry('u1', 'An Nhiên', 950, 9),
        LeaderEntry('u-me', 'Gia Huy', 0, 0, isMe: true),
      ]);
      final store = await PassportStore.load(remote: remote);
      store.login('Gia Huy');
      await store.refreshLeaderboard();

      tester.view.physicalSize = const Size(430, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassportScope(store: store, child: const LeaderboardScreen()),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('An Nhiên'), findsOneWidget);
      expect(find.text('950 XP'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);
      expect(tester.takeException(), isNull);
      store.dispose();
    },
  );

  test(
    'Đẩy leaderboard_public từ client có debounce gộp nhiều thay đổi liên tiếp',
    () async {
      SharedPreferences.setMockInitialValues({});
      final remote = _LeaderboardFakeRemote(const []);
      final store = await PassportStore.load(
        remote: remote,
        leaderboardDebounce: const Duration(milliseconds: 60),
      );

      store.login('Gia Huy');
      store.addReflection(
        locationId: 'dien-hai',
        content: 'Cảm nhận thứ nhất khá dài về Thành Điện Hải.',
        isAnonymous: false,
        aiScore: 80,
        bonusXp: 40,
      );
      store.addReflection(
        locationId: 'cau-rong',
        content: 'Cảm nhận thứ hai khá dài về Cầu Rồng.',
        isAnonymous: false,
        aiScore: 90,
        bonusXp: 45,
      );

      // Chưa hết thời gian debounce: chưa gửi lên Firestore.
      expect(remote.pushedEntries, isEmpty);

      await Future<void>.delayed(const Duration(milliseconds: 120));
      // Chỉ gửi đúng 1 lần với tổng XP mới nhất (40 + 45 = 85).
      expect(remote.pushedEntries, hasLength(1));
      expect(remote.pushedEntries.single.displayName, 'Gia Huy');
      expect(remote.pushedEntries.single.xp, 85);
      expect(remote.pushedEntries.single.stampCount, 0);

      store.dispose();
    },
  );
}
