import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:local_passport/data/routes.dart';
import 'package:local_passport/services/ai_verifier.dart';

void main() {
  final dienHai = locationById['dien-hai']!;

  test(
    'Mặc định dùng heuristic offline khi không truyền REFLECTION_VERIFIER_URL',
    () async {
      final result = await verifyReflection(
        content:
            'Đứng trên tường thành Điện Hải nhìn ra sông Hàn rất xúc động và nhớ lịch sử Đà Nẵng.',
        hasPhoto: true,
        location: dienHai,
        offlineDelay: Duration.zero,
      );
      expect(result.isAi, isFalse);
      expect(result.approved, isTrue);
      expect(result.score, inInclusiveRange(30, 100));
    },
  );

  test(
    'Đính kèm Authorization Bearer ID token khi gọi REFLECTION_VERIFIER_URL',
    () async {
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
        content:
            'Đứng trên tường thành Điện Hải nhìn ra sông Hàn rất xúc động.',
        hasPhoto: true,
        location: dienHai,
        reflectionId: 'r-100',
        displayAuthor: 'Minh Anh',
        isAnonymous: false,
        endpointOverride: 'https://verifier.example.com/verifyReflection',
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
    },
  );

  test(
    'Tự động fallback về heuristic offline khi endpoint ngoài lỗi HTTP hoặc timeout',
    () async {
      final client500 = MockClient((_) async => http.Response('error', 500));
      final fallback500 = await verifyReflection(
        content:
            'Đứng trên tường thành Điện Hải nhìn ra cửa sông Hàn rất ấn tượng.',
        hasPhoto: false,
        location: dienHai,
        endpointOverride: 'https://verifier.example.com/verifyReflection',
        idTokenProvider: () async => 'valid-token',
        httpClient: client500,
      );
      expect(fallback500.isAi, isFalse);
      expect(fallback500.approved, isTrue);
      expect(fallback500.score, inInclusiveRange(30, 100));

      final slowClient = MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return http.Response('{}', 200);
      });
      final fallbackTimeout = await verifyReflection(
        content:
            'Đứng trên tường thành Điện Hải nhìn ra cửa sông Hàn rất ấn tượng.',
        hasPhoto: false,
        location: dienHai,
        endpointOverride: 'https://verifier.example.com/verifyReflection',
        idTokenProvider: () async => 'valid-token',
        httpClient: slowClient,
        timeout: const Duration(milliseconds: 20),
      );
      expect(fallbackTimeout.isAi, isFalse);
      expect(fallbackTimeout.approved, isTrue);
      expect(fallbackTimeout.score, inInclusiveRange(30, 100));
    },
  );
}
