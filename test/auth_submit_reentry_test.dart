import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_passport/services/auth_service.dart';
import 'package:local_passport/state/passport_store.dart';
import 'package:local_passport/widgets/auth_form.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_flow_test.dart' show FakeAuth;

class _PendingAuth extends FakeAuth {
  final response = Completer<void>();
  int signInCalls = 0;

  @override
  Future<void> signIn(String email, String password) async {
    signInCalls++;
    await response.future;
    throw const AuthFailure('Thử lại.');
  }
}

void main() {
  testWidgets('Gửi từ bàn phím khi đang đăng nhập chỉ gọi Auth một lần', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    final auth = _PendingAuth();
    final store = (await tester.runAsync(
      () => PassportStore.load(auth: auth),
    ))!;
    addTearDown(store.dispose);
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PassportScope(
            store: store,
            child: const SingleChildScrollView(child: AuthForm()),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField).first, 'qa@example.test');
    await tester.enterText(find.byType(TextField).last, 'abc12345');
    final submit = tester
        .widget<TextField>(find.byType(TextField).last)
        .onSubmitted!;
    submit('abc12345');
    await tester.pump();
    submit('abc12345');
    await tester.pump();
    auth.response.complete();
    await tester.pump();

    expect(auth.signInCalls, 1);
  });
}
