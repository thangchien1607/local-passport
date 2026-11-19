// Kiểm tra dữ liệu người dùng nhập. Trả về null nếu hợp lệ, ngược lại là
// câu báo lỗi tiếng Việt để hiện ngay dưới ô nhập.

const nameMaxLength = 30;
const passwordMinLength = 6;
const passwordMaxLength = 64;

final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
final _hasLetter = RegExp(r'\p{L}', unicode: true);
final _hasDigit = RegExp(r'\d');

String? validateName(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Nhập tên hiển thị trên hộ chiếu';
  if (v.length > nameMaxLength) return 'Tên tối đa $nameMaxLength ký tự';
  return null;
}

String? validateEmail(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Nhập email';
  if (!_emailPattern.hasMatch(v)) {
    return 'Email không hợp lệ (ví dụ: ban@gmail.com)';
  }
  return null;
}

String? validatePassword(String? value) {
  final v = value ?? '';
  if (v.isEmpty) return 'Nhập mật khẩu';
  if (v.length < passwordMinLength) {
    return 'Mật khẩu tối thiểu $passwordMinLength ký tự';
  }
  if (v.length > passwordMaxLength) {
    return 'Mật khẩu tối đa $passwordMaxLength ký tự';
  }
  if (!_hasLetter.hasMatch(v) || !_hasDigit.hasMatch(v)) {
    return 'Mật khẩu cần có cả chữ và số';
  }
  return null;
}

const reflectionMinLength = 20;
const reflectionMaxLength = 600;

/// Cảm nhận cần đủ dài để bộ chấm đánh giá được, không quá dài cho bảng tin.
String? validateReflection(String? value) {
  final n = (value ?? '').trim().length;
  if (n < reflectionMinLength) {
    return 'Viết thêm ít nhất ${reflectionMinLength - n} ký tự để gửi';
  }
  if (n > reflectionMaxLength) {
    return 'Cảm nhận tối đa $reflectionMaxLength ký tự';
  }
  return null;
}

String? validatePasswordConfirm(String? password, String? confirm) {
  if ((confirm ?? '').isEmpty) return 'Nhập lại mật khẩu';
  if (password != confirm) return 'Mật khẩu nhập lại không khớp';
  return null;
}
