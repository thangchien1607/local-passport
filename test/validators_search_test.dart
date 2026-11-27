import 'package:flutter_test/flutter_test.dart';
import 'package:local_passport/data/routes.dart';
import 'package:local_passport/services/text_search.dart';
import 'package:local_passport/services/validators.dart';

void main() {
  group('Kiểm tra đầu vào', () {
    test('Tên hiển thị', () {
      expect(validateName(''), isNotNull);
      expect(validateName('   '), isNotNull);
      expect(validateName('a' * 31), contains('30'));
      expect(validateName('  Gia Huy '), isNull);
    });

    test('Email', () {
      expect(validateEmail(''), 'Nhập email');
      for (final bad in ['abc', 'abc@', 'a@b', 'a b@c.com', '@gmail.com']) {
        expect(validateEmail(bad), isNotNull, reason: bad);
      }
      expect(validateEmail(' sv01@gmail.com '), isNull);
    });

    test('Mật khẩu và nhập lại', () {
      expect(validatePassword(''), 'Nhập mật khẩu');
      expect(validatePassword('a1b2'), contains('tối thiểu'));
      expect(validatePassword('abcdefgh'), contains('chữ và số'));
      expect(validatePassword('12345678'), contains('chữ và số'));
      expect(validatePassword('x' * 64 + '1'), contains('tối đa'));
      expect(validatePassword('danang2026'), isNull);
      expect(validatePasswordConfirm('danang2026', ''), isNotNull);
      expect(validatePasswordConfirm('danang2026', 'danang2025'), isNotNull);
      expect(validatePasswordConfirm('danang2026', 'danang2026'), isNull);
    });

    test('Nội dung cảm nhận 20–600 ký tự', () {
      expect(validateReflection('Đẹp'), contains('17'));
      expect(validateReflection('   ${'a' * 19}   '), isNotNull);
      expect(validateReflection('a' * 20), isNull);
      expect(validateReflection('a' * 601), contains('600'));
    });
  });

  group('Tìm kiếm không dấu', () {
    test('Bỏ dấu, chữ thường, gom khoảng trắng', () {
      expect(foldVietnamese('  Thành   ĐIỆN Hải '), 'thanh dien hai');
      // Dấu tổ hợp rời (NFD).
      expect(foldVietnamese('Hàn'), 'han');
    });

    test('Mọi từ khóa phải có mặt', () {
      expect(matchesQuery('Thành Điện Hải', 'dien hai'), isTrue);
      expect(matchesQuery('Thành Điện Hải', 'hai dien'), isTrue);
      expect(matchesQuery('Thành Điện Hải', 'dien rong'), isFalse);
      expect(matchesQuery('bất kỳ', '   '), isTrue);
    });

    test('Tìm địa điểm theo tên, địa chỉ và nội dung câu chuyện', () {
      final dienHai = locationById['dien-hai']!;
      expect(locationMatches(dienHai, 'dien hai'), isTrue);
      expect(locationMatches(dienHai, 'tran phu'), isTrue);
      expect(locationMatches(dienHai, '1813'), isTrue);
      expect(
        publishedLocations.where((l) => locationMatches(l, 'zzzz')),
        isEmpty,
      );
    });

    test('Tìm kiếm khớp đầu từ, không dính chuỗi con giữa từ (BUG-13)', () {
      expect(matchesQuery('Bức tường trong thành', 'rong'), isFalse);
      expect(matchesQuery('Thành Điện Hải', 'die'), isTrue);
      final cauRongMatches = publishedLocations
          .where((l) => locationMatches(l, 'Cầu Rồng'))
          .map((l) => l.id)
          .toList();
      expect(cauRongMatches, ['cau-rong']);
    });
  });
}
