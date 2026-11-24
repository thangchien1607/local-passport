import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_passport/data/community.dart';
import 'package:local_passport/screens/community_screen.dart';
import 'package:local_passport/services/passport_remote.dart';
import 'package:local_passport/state/passport_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PagedCommunityRemote implements PassportRemote {
  _PagedCommunityRemote(this.allItems);

  final List<Reflection> allItems;
  final realtimeController = StreamController<List<Reflection>>.broadcast();
  final requestedCursors = <Object?>[];

  @override
  final state = ValueNotifier(SyncState.synced);
  @override
  String? get uid => 'u-comm';
  @override
  Future<Map<String, dynamic>?> fetch() async => null;

  @override
  Future<List<Reflection>> fetchCommunity() async =>
      (await fetchCommunityPage(limit: 20)).items;

  @override
  Future<CommunityPage> fetchCommunityPage({
    int limit = 20,
    Object? startAfter,
  }) async {
    requestedCursors.add(startAfter);
    final startIndex = startAfter is int ? startAfter : 0;
    final slice = allItems.skip(startIndex).take(limit).toList();
    final nextIndex = startIndex + slice.length;
    return CommunityPage(
      items: slice,
      hasMore: nextIndex < allItems.length,
      cursor: nextIndex,
    );
  }

  @override
  Stream<List<Reflection>> watchLatestCommunity({int limit = 20}) =>
      realtimeController.stream;

  @override
  Future<List<LeaderEntry>> fetchLeaderboard({int limit = 50}) async =>
      const [];
  @override
  Future<void> sync(Map<String, dynamic> data) async {}
  @override
  void forget() {}
}

Reflection _makeReflection(int index, {DateTime? createdAt}) => Reflection(
  id: 'comm-$index',
  locationId: 'dien-hai',
  displayAuthor: 'Tác giả $index',
  isAnonymous: false,
  content: 'Cảm nhận cộng đồng số $index về Thành Điện Hải Đà Nẵng.',
  aiScore: 80,
  createdAt:
      createdAt ?? DateTime.utc(2026, 11, 20).subtract(Duration(hours: index)),
);

void main() {
  test(
    'Phân trang fetchCommunityPage + loadMoreCommunity và nhận bài mới realtime',
    () async {
      SharedPreferences.setMockInitialValues({});
      final items = List.generate(25, _makeReflection);
      final remote = _PagedCommunityRemote(items);
      final store = await PassportStore.load(remote: remote);
      store.login('Minh Anh');

      await store.refreshCommunity(pageSize: 10);
      expect(store.communityReflections, hasLength(10));
      expect(store.hasMoreCommunity, isTrue);

      await store.loadMoreCommunity(pageSize: 10);
      expect(store.communityReflections, hasLength(20));
      expect(store.hasMoreCommunity, isTrue);

      await store.loadMoreCommunity(pageSize: 10);
      expect(store.communityReflections, hasLength(25));
      expect(store.hasMoreCommunity, isFalse);

      // Phát sinh bài mới qua stream snapshots() realtime.
      final livePost = _makeReflection(
        999,
        createdAt: DateTime.utc(2026, 11, 25, 12),
      );
      remote.realtimeController.add([livePost]);
      await Future<void>.delayed(Duration.zero);

      expect(store.communityReflections.first.id, 'comm-999');
      expect(store.communityReflections, hasLength(26));

      await remote.realtimeController.close();
      store.dispose();
    },
  );

  testWidgets(
    'CommunityScreen hỗ trợ tải thêm trang tiếp theo và hiển thị bài realtime',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      SharedPreferences.setMockInitialValues({});
      final items = List.generate(25, _makeReflection);
      final remote = _PagedCommunityRemote(items);
      final store = await tester.runAsync(
        () => PassportStore.load(remote: remote),
      );
      store!.login('Minh Anh');

      tester.view.physicalSize = const Size(430, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassportScope(store: store, child: const CommunityScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Cảm nhận cộng đồng số 0'), findsOneWidget);
      expect(store.hasMoreCommunity, isTrue);

      // Kéo xuống cuối để kích hoạt infinite scroll tải trang 2.
      await tester.drag(find.byType(ListView).first, const Offset(0, -6000));
      await tester.pumpAndSettle();
      expect(store.communityReflections.length, 25);
      expect(store.hasMoreCommunity, isFalse);

      // Đẩy bài mới realtime từ server -> hiện ngay ở đầu danh sách.
      remote.realtimeController.add([
        _makeReflection(1000, createdAt: DateTime.utc(2026, 11, 25, 13)),
      ]);
      await tester.pumpAndSettle();
      expect(store.communityReflections.first.id, 'comm-1000');

      await remote.realtimeController.close();
      store.dispose();
    },
  );
}
