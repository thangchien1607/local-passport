import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:local_passport/data/routes.dart';
import 'package:local_passport/services/ai_verifier.dart';

void main() {
  final dienHai = locationById['dien-hai']!;

  test('Đính kèm Authorization Bearer ID token khi gọi Cloud Function', () async {
    http.Request? captured;
    final mockClient = MockClient((request) async {
      captured = request;
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'score': 88,
            'approved': true,
            'soulmate': true,
            'bonusXp': 44,
            'comment': 'Cảm nhận chân thực về Thành Điện Hải.',
            'isAi': true,
          }),
        ),
        200,
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final result = await verifyReflection(
      content: 'Đứng trên tường thành Điện Hải nhìn ra sông Hàn rất xúc động.',
      hasPhoto: true,
      location: dienHai,
      reflectionId: 'r-100',
      displayAuthor: 'Minh Anh',
      isAnonymous: false,
      photoUrl: 'https://firebasestorage.googleapis.com/v0/b/test/o/a.jpg',
      endpointOverride:
          'https://asia-southeast1-local-passport-danang.cloudfunctions.net/verifyReflection',
      idTokenProvider: () async => 'fake-id-token-123',
      httpClient: mockClient,
    );

    expect(captured, isNotNull);
    expect(captured!.headers['Authorization'], 'Bearer fake-id-token-123');
    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(body['reflectionId'], 'r-100');
    expect(body['locationId'], 'dien-hai');
    expect(result.score, 88);
    expect(result.approved, isTrue);
    expect(result.soulmate, isTrue);
    expect(result.isAi, isTrue);
  });

  test('Từ chối gọi Cloud Function khi không có ID token', () async {
    await expectLater(
      verifyReflection(
        content: 'Cảm nhận thử nghiệm khi chưa đăng nhập.',
        hasPhoto: false,
        location: dienHai,
        endpointOverride:
            'https://asia-southeast1-local-passport-danang.cloudfunctions.net/verifyReflection',
        idTokenProvider: () async => null,
      ),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('đăng nhập'),
        ),
      ),
    );
  });

  test('Báo lỗi rõ ràng khi Cloud Function trả 401 hoặc 429', () async {
    final client401 = MockClient((_) async => http.Response('{}', 401));
    await expectLater(
      verifyReflection(
        content: 'Cảm nhận thử nghiệm token hết hạn.',
        hasPhoto: false,
        location: dienHai,
        endpointOverride: 'http://127.0.0.1:5001/test/verifyReflection',
        idTokenProvider: () async => 'expired',
        httpClient: client401,
      ),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('hết hạn'),
        ),
      ),
    );

    final client429 = MockClient((_) async => http.Response('{}', 429));
    await expectLater(
      verifyReflection(
        content: 'Cảm nhận thử nghiệm vượt giới hạn tần suất.',
        hasPhoto: false,
        location: dienHai,
        endpointOverride: 'http://127.0.0.1:5001/test/verifyReflection',
        idTokenProvider: () async => 'valid',
        httpClient: client429,
      ),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('quá nhanh'),
        ),
      ),
    );
  });
}
