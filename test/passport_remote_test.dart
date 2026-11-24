import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_passport/data/community.dart';
import 'package:local_passport/services/passport_remote.dart';
import 'package:local_passport/state/passport_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bản giả của Firestore: giữ dữ liệu trong bộ nhớ.
class _FakeRemote implements PassportRemote {
  _FakeRemote([this.server]);

  Map<String, dynamic>? server;
  final synced = <Map<String, dynamic>>[];

  @override
  final state = ValueNotifier(SyncState.synced);

  @override
  String? get uid => 'u-test';

  @override
  Future<Map<String, dynamic>?> fetch() async => server;

  @override
  Future<List<Reflection>> fetchCommunity() async => [seedReflections.first];

  @override
  Future<CommunityPage> fetchCommunityPage({
    int limit = 20,
    Object? startAfter,
  }) async => CommunityPage(items: [seedReflections.first], hasMore: false);

  @override
  Stream<List<Reflection>> watchLatestCommunity({int limit = 20}) =>
      const Stream.empty();

  @override
  Future<List<LeaderEntry>> fetchLeaderboard({int limit = 50}) async =>
      const [];

  @override
  Future<void> sync(Map<String, dynamic> data) async {
    synced.add(data);
    server = data;
  }

  @override
  void forget() {}
}

void main() {
  test('Mỗi thao tác thêm/sửa/xóa đều ghi lên server', () async {
    SharedPreferences.setMockInitialValues({});
    final remote = _FakeRemote();
    final store = await PassportStore.load(remote: remote);
    await Future<void>.delayed(Duration.zero);

    store.login('Gia Huy');
    store.addReflection(
      locationId: 'dien-hai',
      content: 'Đẹp',
      isAnonymous: false,
      aiScore: 70,
      bonusXp: 10,
    );
    final id = store.reflections.single.id;
    store.setReflectionAnonymous(id, true);
    expect(
      (remote.server!['reflections'] as List).single['isAnonymous'],
      isTrue,
    );
    store.deleteReflection(id);
    expect(remote.server!['reflections'], isEmpty);
    expect(remote.server!['xp'], 10);
    expect(remote.synced, hasLength(4));
  });

  test('Mở app lấy dữ liệu trên server và bài của cộng đồng', () async {
    SharedPreferences.setMockInitialValues({});
    final remote = _FakeRemote({
      'user': {
        'name': 'Từ server',
        'passportNo': 'DN123456',
        'joinedAt': DateTime(2026, 11, 1).toIso8601String(),
      },
      'progress': <String, dynamic>{},
      'stamps': <String, dynamic>{},
      'xp': 42,
      'reflections': <dynamic>[],
    });
    final store = await PassportStore.load(remote: remote);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(store.user?.name, 'Từ server');
    expect(store.xp, 42);
    expect(store.communityReflections, hasLength(1));
  });
}
