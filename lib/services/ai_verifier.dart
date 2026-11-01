import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../data/routes.dart';

// Có thể nối HTTPS Cloud Function qua --dart-define mà không đưa Gemini key
// vào ứng dụng. Khi chưa cấu hình endpoint, dùng bộ chấm offline cho demo.
const _verifierUrl = String.fromEnvironment('REFLECTION_VERIFIER_URL');
const hasRemoteReflectionVerifier = _verifierUrl != '';

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

Future<VerifyResult> verifyReflection({
  required String content,
  required bool hasPhoto,
  required Location location,
}) async {
  if (_verifierUrl.isNotEmpty) {
    final endpoint = Uri.parse(_verifierUrl);
    if (endpoint.scheme != 'https') {
      throw Exception('Endpoint thẩm định phải dùng HTTPS.');
    }
    final response = await http
        .post(
          endpoint,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'content': content.trim(),
            'hasPhoto': hasPhoto,
            'locationId': location.id,
            'locationName': location.name,
            'stories': location.stories
                .map((s) => {'title': s.title, 'body': s.body})
                .toList(),
          }),
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw Exception('Dịch vụ thẩm định đang bận (${response.statusCode}).');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return VerifyResult(
      score: (data['score'] as num).round().clamp(0, 100).toInt(),
      approved: data['approved'] as bool,
      soulmate: data['soulmate'] as bool? ?? false,
      bonusXp: (data['bonusXp'] as num?)?.round().clamp(0, 500).toInt() ?? 0,
      comment: data['comment'] as String,
      isAi: true,
    );
  }

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
