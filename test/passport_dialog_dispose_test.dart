import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_passport/screens/passport_screen.dart';
import 'package:local_passport/services/auth_service.dart';
import 'package:local_passport/state/passport_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthGateway implements AuthGateway {
  @override
  String? get uid => 'u-bug16';
  @override
  String? get email => 'bug16@example.com';
  @override
  String? get displayName => 'QA Trước Đổi';
  @override
  bool get isGuest => false;
  @override
  bool get emailVerified => false;
  @override
  bool get hasPasswordProvider => true;
  @override
  bool get hasGoogleProvider => false;
  @override
  bool get hasAppleProvider => false;

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}
  @override
  Future<void> deleteAccount({
    String? password,
    Future<void> Function(String uid)? beforeDeleteUser,
  }) async {}
  @override
  Future<void> register(String email, String password) async {}
  @override
  Future<bool> reloadUser() async => false;
  @override
  Future<void> sendEmailVerification() async {}
  @override
  Future<void> sendPasswordReset(String email) async {}
  @override
  Future<void> signIn(String email, String password) async {}
  @override
  Future<void> signInGuest() async {}
  @override
  Future<void> signInWithApple() async {}
  @override
  Future<void> signInWithGoogle() async {}
  @override
  Future<void> signOut() async {}
}

void main() {
  testWidgets(
    'Đóng hộp thoại Đổi tên không hủy TextEditingController trong khi hoạt ảnh còn chạy (BUG-16)',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      SharedPreferences.setMockInitialValues({});
      final store = (await tester.runAsync(
        () => PassportStore.load(auth: _FakeAuthGateway()),
      ))!;
      store.login('QA Trước Đổi');

      tester.view.physicalSize = const Size(430, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassportScope(
              store: store,
              child: PassportScreen(onOpenLocation: (_) {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Đổi tên'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Đổi tên'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đổi tên'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'QA Sau Đổi');
      await tester.tap(find.text('Lưu'));
      // Bơm khung giữa hoạt ảnh đóng AlertDialog để kích hoạt lỗi hủy controller sớm.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(store.user?.name, 'QA Sau Đổi');
    },
  );
}
