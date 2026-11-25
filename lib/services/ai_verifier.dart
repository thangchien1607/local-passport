import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../data/routes.dart';

/// Endpoint thẩm định ngoài (tùy chọn), truyền lúc build qua
/// `--dart-define=REFLECTION_VERIFIER_URL=https://...`.
/// Mặc định để trống → chạy hoàn toàn bằng bộ chấm heuristic offline trên Spark.
const reflectionVerifierUrl = String.fromEnvironment('REFLECTION_VERIFIER_URL');

bool get hasRemoteReflectionVerifier => reflectionVerifierUrl.isNotEmpty;

typedef IdTokenProvider = Future<String?> Function();

Future<String?> _defaultIdTokenProvider() async {
  if (Firebase.apps.isEmpty) return null;
  return FirebaseAuth.instance.currentUser?.getIdToken();
}

bool _isAllowedEndpoint(Uri uri) {
  if (uri.scheme == 'https') return true;
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

/// Bộ chấm điểm heuristic offline dựa trên độ dài, từ khóa liên hệ câu chuyện
/// của di tích và việc có ảnh đính kèm. Dùng mặc định cho kiến trúc Spark và
/// làm fallback khi endpoint ngoài lỗi hoặc hết thời gian chờ.
VerifyResult scoreReflectionHeuristic({
  required String content,
  required bool hasPhoto,
  required Location location,
}) {
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

/// Thẩm định cảm nhận:
/// - Mặc định chạy bộ chấm heuristic offline (không cần backend/Blaze).
/// - Nếu truyền `REFLECTION_VERIFIER_URL` (hoặc [endpointOverride]): gửi yêu cầu
///   kèm `Authorization: Bearer <Firebase ID Token>`. Nếu lỗi mạng, HTTP lỗi,
///   thiếu token hoặc timeout thì tự động fallback về heuristic offline.
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
  Duration timeout = const Duration(seconds: 12),
  Duration offlineDelay = const Duration(milliseconds: 600),
}) async {
  final rawEndpoint = endpointOverride ?? reflectionVerifierUrl;
  if (rawEndpoint.isNotEmpty) {
    try {
      final endpoint = Uri.parse(rawEndpoint);
      if (!_isAllowedEndpoint(endpoint)) {
        throw const FormatException('Endpoint thẩm định phải dùng HTTPS.');
      }

      final token = await (idTokenProvider ?? _defaultIdTokenProvider)();
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final client = httpClient ?? http.Client();
      try {
        final response = await client
            .post(
              endpoint,
              headers: headers,
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
              }),
            )
            .timeout(timeout);

        if (response.statusCode != 200) {
          throw Exception('HTTP ${response.statusCode}');
        }

        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return VerifyResult(
          score: (data['score'] as num).round().clamp(0, 100).toInt(),
          approved: data['approved'] as bool,
          soulmate: data['soulmate'] as bool? ?? false,
          bonusXp:
              (data['bonusXp'] as num?)?.round().clamp(0, 500).toInt() ?? 0,
          comment: data['comment'] as String,
          isAi: data['isAi'] as bool? ?? true,
        );
      } finally {
        if (httpClient == null) client.close();
      }
    } catch (e) {
      // Endpoint ngoài gặp lỗi/timeout → tự động fallback về bộ chấm heuristic offline.
      debugPrint('Endpoint thẩm định ngoài lỗi ($e), chuyển sang heuristic.');
      return scoreReflectionHeuristic(
        content: content,
        hasPhoto: hasPhoto || photoUrl != null,
        location: location,
      );
    }
  }

  if (offlineDelay > Duration.zero) {
    await Future<void>.delayed(offlineDelay);
  }
  return scoreReflectionHeuristic(
    content: content,
    hasPhoto: hasPhoto || photoUrl != null,
    location: location,
  );
}
