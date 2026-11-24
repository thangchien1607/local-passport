import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

import '../data/routes.dart';

/// Base URL của Cloud Functions (vd `https://asia-southeast1-local-passport-danang.cloudfunctions.net`
/// hoặc `http://127.0.0.1:5001/local-passport-danang/asia-southeast1` khi chạy emulator).
const cloudFunctionsBaseUrl = String.fromEnvironment(
  'CLOUD_FUNCTIONS_BASE_URL',
);

/// Đường dẫn đầy đủ tới Cloud Function `verifyReflection` (tùy chọn ghi đè).
const _verifyFunctionOverride = String.fromEnvironment(
  'AI_VERIFY_FUNCTION_URL',
);

/// Endpoint Cloud Function đang cấu hình (rỗng = dùng bộ chấm offline cho demo/test).
String get verifyReflectionFunctionUrl {
  if (_verifyFunctionOverride.isNotEmpty) return _verifyFunctionOverride;
  if (cloudFunctionsBaseUrl.isNotEmpty) {
    final trimmed = cloudFunctionsBaseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$trimmed/verifyReflection';
  }
  return '';
}

bool get hasRemoteReflectionVerifier => verifyReflectionFunctionUrl.isNotEmpty;

typedef IdTokenProvider = Future<String?> Function();

Future<String?> _defaultIdTokenProvider() async {
  if (Firebase.apps.isEmpty) return null;
  return FirebaseAuth.instance.currentUser?.getIdToken();
}

bool _isAllowedEndpoint(Uri uri) {
  if (uri.scheme == 'https') return true;
  // Chỉ cho phép HTTP trên localhost/127.0.0.1 khi chạy Firebase Emulator.
  if (uri.scheme == 'http' &&
      (uri.host == 'localhost' ||
          uri.host == '127.0.0.1' ||
          uri.host == '10.0.2.2')) {
    return true;
  }
  return false;
}

class VerifyResult {
  const VerifyResult({
    required this.score,
    required this.approved,
    required this.soulmate,
    required this.bonusXp,
    required this.comment,
    this.isAi = false,
  });

  final int score;
  final bool approved;
  final bool soulmate;
  final int bonusXp;
  final String comment;
  final bool isAi;
}

final _splitter = RegExp(r'[^\p{L}\d]+', unicode: true);

/// Gọi Cloud Function `verifyReflection` kèm `Authorization: Bearer <ID Token>`
/// để server chấm điểm và tự ghi `aiScore` vào Firestore bằng Admin SDK.
/// Khi chưa cấu hình Cloud Function URL (demo cục bộ/test), dùng bộ chấm offline.
Future<VerifyResult> verifyReflection({
  required String content,
  required bool hasPhoto,
  required Location location,
  String? reflectionId,
  String? displayAuthor,
  bool isAnonymous = false,
  String? photoUrl,
  String? endpointOverride,
  IdTokenProvider? idTokenProvider,
  http.Client? httpClient,
}) async {
  final rawEndpoint = endpointOverride ?? verifyReflectionFunctionUrl;
  if (rawEndpoint.isNotEmpty) {
    final endpoint = Uri.parse(rawEndpoint);
    if (!_isAllowedEndpoint(endpoint)) {
      throw Exception('Endpoint Cloud Function phải dùng HTTPS.');
    }

    final token = await (idTokenProvider ?? _defaultIdTokenProvider)();
    if (token == null || token.isEmpty) {
      throw Exception('Vui lòng đăng nhập để sử dụng tính năng chấm điểm AI.');
    }

    final client = httpClient ?? http.Client();
    try {
      final response = await client
          .post(
            endpoint,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'content': content.trim(),
              'hasPhoto': hasPhoto || photoUrl != null,
              'locationId': location.id,
              'locationName': location.name,
              'stories': location.stories
                  .map((s) => {'title': s.title, 'body': s.body})
                  .toList(),
              'reflectionId': ?reflectionId,
              'displayAuthor': ?displayAuthor,
              'isAnonymous': isAnonymous,
              'photoUrl': photoUrl,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 401) {
        throw Exception('Phiên đăng nhập hết hạn. Hãy đăng nhập lại.');
      }
      if (response.statusCode == 429) {
        throw Exception('Bạn gửi quá nhanh. Vui lòng thử lại sau ít phút.');
      }
      if (response.statusCode == 403) {
        throw Exception('Bạn không có quyền chấm điểm bài cảm nhận này.');
      }
      if (response.statusCode != 200) {
        throw Exception('Dịch vụ thẩm định đang bận (${response.statusCode}).');
      }

      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return VerifyResult(
        score: (data['score'] as num).round().clamp(0, 100).toInt(),
        approved: data['approved'] as bool,
        soulmate: data['soulmate'] as bool? ?? false,
        bonusXp: (data['bonusXp'] as num?)?.round().clamp(0, 500).toInt() ?? 0,
        comment: data['comment'] as String,
        isAi: data['isAi'] as bool? ?? true,
      );
    } finally {
      if (httpClient == null) client.close();
    }
  }

  // Bộ chấm offline chỉ dùng khi chưa kết nối Cloud Function (chế độ demo/test).
  await Future<void>.delayed(const Duration(seconds: 2));
  final text = content.trim().toLowerCase();
  final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

  // Từ khóa lấy từ câu chuyện của địa điểm: cảm nhận có liên hệ nội dung → điểm cao hơn.
  final keywords = location.stories
      .expand((s) => '${s.title} ${s.body}'.toLowerCase().split(_splitter))
      .where((w) => w.length >= 4)
      .toSet();
  final hits = text.split(_splitter).where(keywords.contains).toSet().length;

  var score = 35 + min(words, 60) * 0.6 + min(hits, 6) * 4 + (hasPhoto ? 8 : 0);
  if (words < 5) score = min(score, 30);
  final s = min(score, 98).round();

  return VerifyResult(
    score: s,
    approved: s >= 30,
    soulmate: s >= 70,
    bonusXp: s >= 30 ? (s / 2).round() : 0,
    comment: s >= 70
        ? 'Cảm nhận sâu sắc, có liên hệ với câu chuyện của di tích.'
        : s >= 30
        ? 'Cảm ơn bạn đã chia sẻ! Thêm chi tiết về điều bạn học được để nhận huy hiệu Tri kỷ.'
        : 'Cảm nhận hơi ngắn, hãy kể thêm một chút nhé.',
  );
}
