import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_passport/data/community.dart';
import 'package:local_passport/data/routes.dart';
import 'package:local_passport/state/passport_store.dart';
import 'package:local_passport/widgets/reflection_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _loc = 'bach-khoa';

/// Người dùng đã nhận dấu mộc tại [_loc] và viết một bài cảm nhận có tên.
Future<PassportStore> _storeWithReflection({String? photo = 'YWJj'}) async {
  SharedPreferences.setMockInitialValues({});
  final store = await PassportStore.load();
  store
    ..login('Gia Huy')
    ..unlock(_loc);
  for (final t in locationById[_loc]!.tasks) {
    store.setTask(_loc, t.id, true);
  }
  store.addReflection(
    locationId: _loc,
    content: 'Cổng trường buổi sáng rất đẹp.',
    isAnonymous: false,
    aiScore: 80,
    bonusXp: 20,
    photoBase64: photo,
  );
  return store;
}

void main() {
  test('Đổi ẩn danh giữ nguyên nội dung, điểm, ảnh, ngày tạo', () async {
    final store = await _storeWithReflection();
    final before = store.reflections.single;
    final xp = store.xp;

    expect(store.setReflectionAnonymous(before.id, true), isTrue);
    final after = store.reflections.single;
    expect(after.isAnonymous, isTrue);
    expect(after.displayAuthor, anonymousAuthor);
    expect(after.id, before.id);
    expect(after.content, before.content);
    expect(after.aiScore, before.aiScore);
    expect(after.photoBase64, before.photoBase64);
    expect(after.createdAt, before.createdAt);
    expect(store.xp, xp);

    expect(store.setReflectionAnonymous(before.id, false), isTrue);
    expect(store.reflections.single.displayAuthor, 'Gia Huy');

    // Bài mẫu chỉ đọc.
    expect(store.setReflectionAnonymous(seedReflections.first.id, true), false);
    expect(store.isMyReflection(seedReflections.first.id), isFalse);
  });

  test('Xóa bài vẫn giữ dấu mộc và XP', () async {
    final store = await _storeWithReflection();
    final id = store.reflections.single.id;
    final xp = store.xp;
    expect(store.stamps, contains(_loc));

    expect(store.deleteReflection(id), isTrue);
    expect(store.reflections, isEmpty);
    expect(store.xp, xp);
    expect(store.stamps, contains(_loc));
    expect(store.deleteReflection(id), isFalse);
    expect(store.deleteReflection(seedReflections.first.id), isFalse);
  });

  test('Tải lại vẫn đúng sau khi sửa và xóa', () async {
    final store = await _storeWithReflection();
    final first = store.reflections.single;
    // id bài viết lấy theo mili giây: chờ để không trùng.
    await Future<void>.delayed(const Duration(milliseconds: 2));
    store.addReflection(
      locationId: _loc,
      content: 'Bài thứ hai.',
      isAnonymous: true,
      aiScore: 70,
      bonusXp: 0,
    );
    final second = store.reflections.firstWhere((r) => r.id != first.id);
    store
      ..setReflectionAnonymous(first.id, true)
      ..deleteReflection(second.id);
    await Future<void>.delayed(Duration.zero);

    final reloaded = await PassportStore.load();
    final r = reloaded.reflections.single;
    expect(r.id, first.id);
    expect(r.isAnonymous, isTrue);
    expect(r.displayAuthor, anonymousAuthor);
    expect(r.content, first.content);
    expect(r.aiScore, first.aiScore);
    expect(reloaded.xp, store.xp);
    expect(reloaded.stamps.keys, store.stamps.keys);
  });

  testWidgets('Thẻ của mình có nút ẩn danh và xóa, xóa phải xác nhận', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final store = await tester.runAsync(
      () => _storeWithReflection(photo: null),
    );
    final s = store!;
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PassportScope(
            store: s,
            child: Builder(
              builder: (context) {
                final st = PassportScope.of(context);
                return ListView(
                  children: [
                    for (final r in [...st.reflections, seedReflections.first])
                      ReflectionCard(
                        reflection: r,
                        onToggleAnonymous: st.isMyReflection(r.id)
                            ? () => st.setReflectionAnonymous(
                                r.id,
                                !r.isAnonymous,
                              )
                            : null,
                        onDelete: st.isMyReflection(r.id)
                            ? () => st.deleteReflection(r.id)
                            : null,
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );

    // Chỉ bài của mình có nút; bài mẫu thì không.
    expect(find.text('Chuyển sang ẩn danh'), findsOneWidget);
    expect(find.text('Xóa'), findsOneWidget);

    await tester.tap(find.text('Chuyển sang ẩn danh'));
    await tester.pump();
    expect(find.text('Hiện tên của tôi'), findsOneWidget);
    expect(s.reflections.single.isAnonymous, isTrue);

    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();
    expect(find.text('Xóa bài cảm nhận?'), findsOneWidget);
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(s.reflections, hasLength(1));

    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
    await tester.pumpAndSettle();
    expect(s.reflections, isEmpty);
    expect(find.text('Hiện tên của tôi'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
