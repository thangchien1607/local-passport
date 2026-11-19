import 'package:firebase_auth/firebase_auth.dart';

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

  /// Đang dùng tài khoản khách (ẩn danh).
  bool get isGuest;

  /// Tạo tài khoản email. Nếu đang là khách thì nâng tài khoản khách lên,
  /// giữ nguyên uid và hộ chiếu đang có.
  Future<void> register(String email, String password);
  Future<void> signIn(String email, String password);
  Future<void> signInGuest();
  Future<void> sendPasswordReset(String email);
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
  bool get isGuest => _auth.currentUser?.isAnonymous ?? false;

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
  Future<void> signInGuest() => _guard(_auth.signInAnonymously);

  @override
  Future<void> sendPasswordReset(String email) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  @override
  Future<void> signOut() => _guard(_auth.signOut);

  Future<void> _guard(Future<Object?> Function() action) async {
    try {
      await action();
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
  'weak-password' => 'Mật khẩu quá yếu, hãy chọn mật khẩu dài hơn.',
  'missing-password' => 'Nhập mật khẩu.',
  'network-request-failed' =>
    'Không có kết nối mạng. Kiểm tra mạng rồi thử lại.',
  'too-many-requests' => 'Thử sai quá nhiều lần. Đợi vài phút rồi thử lại.',
  'operation-not-allowed' =>
    'Máy chủ chưa bật kiểu đăng nhập này. Báo cho nhóm phát triển.',
  _ => 'Không thực hiện được ($code). Thử lại sau.',
};
