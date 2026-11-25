import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Lỗi xác thực đã dịch sang câu dễ hiểu để hiện cho người dùng.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Tài khoản người dùng. PassportStore gọi qua lớp này để test dùng bản giả.
abstract class AuthGateway {
  String? get uid;
  String? get email;
  String? get displayName;

  /// Đang dùng tài khoản khách (ẩn danh).
  bool get isGuest;

  /// Email đã xác minh hay chưa.
  bool get emailVerified;

  /// Có đăng nhập bằng Email/Mật khẩu hay không (để hiển thị đổi mật khẩu / xác minh email).
  bool get hasPasswordProvider;

  /// Có liên kết đăng nhập bằng Google hay không.
  bool get hasGoogleProvider;

  /// Có liên kết đăng nhập bằng Apple hay không.
  bool get hasAppleProvider;

  /// Tạo tài khoản email. Nếu đang là khách thì nâng tài khoản khách lên,
  /// giữ nguyên uid và hộ chiếu đang có.
  Future<void> register(String email, String password);
  Future<void> signIn(String email, String password);
  Future<void> signInWithGoogle();
  Future<void> signInWithApple();
  Future<void> signInGuest();
  Future<void> sendPasswordReset(String email);
  Future<void> sendEmailVerification();
  Future<bool> reloadUser();
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Xóa vĩnh viễn tài khoản theo đúng thứ tự:
  /// (1) Xác thực lại (re-authenticate) tùy theo nhà cung cấp đăng nhập;
  /// (2) Gọi [beforeDeleteUser] để xóa toàn bộ dữ liệu Firestore của `uid`;
  /// (3) Chỉ gọi `user.delete()` khi bước (1) và (2) đều thành công.
  Future<void> deleteAccount({
    String? password,
    Future<void> Function(String uid)? beforeDeleteUser,
  });
  Future<void> signOut();
}

class FirebaseAuthGateway implements AuthGateway {
  FirebaseAuthGateway._(this._auth);

  final FirebaseAuth _auth;

  /// Chờ Firebase khôi phục phiên đăng nhập đã lưu rồi mới trả về.
  static Future<FirebaseAuthGateway> create([FirebaseAuth? auth]) async {
    final a = auth ?? FirebaseAuth.instance;
    await a.authStateChanges().first;
    return FirebaseAuthGateway._(a);
  }

  @override
  String? get uid => _auth.currentUser?.uid;

  @override
  String? get email => _auth.currentUser?.email;

  @override
  String? get displayName => _auth.currentUser?.displayName;

  @override
  bool get isGuest => _auth.currentUser?.isAnonymous ?? false;

  @override
  bool get emailVerified => _auth.currentUser?.emailVerified ?? false;

  @override
  bool get hasPasswordProvider {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return false;
    return user.providerData.any((p) => p.providerId == 'password');
  }

  @override
  bool get hasGoogleProvider {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return false;
    return user.providerData.any((p) => p.providerId == 'google.com');
  }

  @override
  bool get hasAppleProvider {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return false;
    return user.providerData.any((p) => p.providerId == 'apple.com');
  }

  @override
  Future<void> register(String email, String password) => _guard(() async {
    final current = _auth.currentUser;
    final cred = EmailAuthProvider.credential(
      email: email.trim(),
      password: password,
    );
    if (current != null && current.isAnonymous) {
      await current.linkWithCredential(cred);
    } else {
      await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    }
    return null;
  });

  @override
  Future<void> signIn(String email, String password) => _guard(
    () => _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    ),
  );

  @override
  Future<void> signInWithGoogle() => _guard(() async {
    final provider = GoogleAuthProvider()..addScope('email');
    await _signInOrLinkProvider(provider);
    return null;
  });

  @override
  Future<void> signInWithApple() => _guard(() async {
    final provider = AppleAuthProvider()
      ..addScope('email')
      ..addScope('name');
    await _signInOrLinkProvider(provider);
    return null;
  });

  Future<void> _signInOrLinkProvider(AuthProvider provider) async {
    final current = _auth.currentUser;
    if (current != null && current.isAnonymous) {
      if (kIsWeb) {
        await current.linkWithPopup(provider);
      } else {
        await current.linkWithProvider(provider);
      }
      return;
    }
    if (kIsWeb) {
      await _auth.signInWithPopup(provider);
    } else {
      await _auth.signInWithProvider(provider);
    }
  }

  @override
  Future<void> signInGuest() => _guard(_auth.signInAnonymously);

  @override
  Future<void> sendPasswordReset(String email) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  @override
  Future<void> sendEmailVerification() => _guard(() async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw const AuthFailure('Chỉ tài khoản có email mới xác minh được.');
    }
    await user.sendEmailVerification();
    return null;
  });

  @override
  Future<bool> reloadUser() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await _guard(() async {
      await user.reload();
      return null;
    });
    return _auth.currentUser?.emailVerified ?? false;
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => _guard(() async {
    final user = _auth.currentUser;
    final userEmail = user?.email;
    if (user == null || userEmail == null || user.isAnonymous) {
      throw const AuthFailure('Tài khoản hiện tại không dùng mật khẩu.');
    }
    final cred = EmailAuthProvider.credential(
      email: userEmail,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(cred);
    await user.updatePassword(newPassword);
    return null;
  });

  Future<void> _reauthenticateForDelete(User user, {String? password}) async {
    if (user.isAnonymous) return;
    if (hasPasswordProvider) {
      final userEmail = user.email;
      if (userEmail == null || userEmail.isEmpty) {
        throw const AuthFailure('Không xác định được email của tài khoản.');
      }
      if (password == null || password.isEmpty) {
        throw const AuthFailure(
          'Nhập mật khẩu hiện tại để xác nhận xóa tài khoản.',
        );
      }
      final cred = EmailAuthProvider.credential(
        email: userEmail,
        password: password,
      );
      await user.reauthenticateWithCredential(cred);
      return;
    }
    if (hasGoogleProvider) {
      final provider = GoogleAuthProvider()..addScope('email');
      if (kIsWeb) {
        await user.reauthenticateWithPopup(provider);
      } else {
        await user.reauthenticateWithProvider(provider);
      }
      return;
    }
    if (hasAppleProvider) {
      final provider = AppleAuthProvider()
        ..addScope('email')
        ..addScope('name');
      if (kIsWeb) {
        await user.reauthenticateWithPopup(provider);
      } else {
        await user.reauthenticateWithProvider(provider);
      }
    }
  }

  @override
  Future<void> deleteAccount({
    String? password,
    Future<void> Function(String uid)? beforeDeleteUser,
  }) => _guard(() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    // (1) Xác thực lại trước khi đụng vào dữ liệu trên máy chủ.
    await _reauthenticateForDelete(user, password: password);

    // (2) Xóa toàn bộ dữ liệu Firestore của người dùng. Nếu lỗi giữa chừng,
    // KHÔNG gọi user.delete() để người dùng còn phiên đăng nhập mà thử lại.
    if (beforeDeleteUser != null) {
      try {
        await beforeDeleteUser(user.uid);
      } on AuthFailure {
        rethrow;
      } catch (_) {
        throw const AuthFailure(
          'Không xóa được toàn bộ dữ liệu trên máy chủ. Tài khoản chưa bị xóa, vui lòng kiểm tra mạng rồi thử lại.',
        );
      }
    }

    // (3) Xóa tài khoản trên Firebase Auth.
    await user.delete();
    return null;
  });

  @override
  Future<void> signOut() => _guard(_auth.signOut);

  Future<void> _guard(Future<Object?> Function() action) async {
    try {
      await action();
    } on AuthFailure {
      rethrow;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(authErrorMessage(e.code));
    } catch (_) {
      throw const AuthFailure(
        'Có lỗi khi kết nối tới máy chủ. Kiểm tra mạng rồi thử lại.',
      );
    }
  }
}

/// Dịch mã lỗi của Firebase Auth sang câu tiếng Việt.
String authErrorMessage(String code) => switch (code) {
  'invalid-email' => 'Email không hợp lệ.',
  'user-disabled' => 'Tài khoản này đã bị khóa.',
  'user-not-found' ||
  'wrong-password' ||
  'invalid-credential' ||
  'invalid-login-credentials' => 'Email hoặc mật khẩu không đúng.',
  'email-already-in-use' ||
  'credential-already-in-use' => 'Email này đã có tài khoản. Hãy đăng nhập.',
  'account-exists-with-different-credential' =>
    'Email này đã liên kết với phương thức đăng nhập khác.',
  'provider-already-linked' => 'Tài khoản đã liên kết phương thức này rồi.',
  'popup-closed-by-user' ||
  'cancelled-popup-request' ||
  'web-context-cancelled' => 'Bạn đã hủy bước đăng nhập.',
  'requires-recent-login' =>
    'Phiên đăng nhập đã quá hạn. Vui lòng xác thực lại (hoặc đăng xuất rồi đăng nhập lại) trước khi thực hiện thao tác bảo mật này.',
  'weak-password' => 'Mật khẩu quá yếu, hãy chọn mật khẩu dài hơn.',
  'missing-password' => 'Nhập mật khẩu.',
  'network-request-failed' =>
    'Không có kết nối mạng. Kiểm tra mạng rồi thử lại.',
  'too-many-requests' => 'Thử sai quá nhiều lần. Đợi vài phút rồi thử lại.',
  'operation-not-allowed' =>
    'Máy chủ chưa bật kiểu đăng nhập này. Báo cho nhóm phát triển.',
  _ => 'Không thực hiện được ($code). Thử lại sau.',
};
