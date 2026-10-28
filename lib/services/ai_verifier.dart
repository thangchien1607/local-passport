import 'dart:math';

import '../data/routes.dart';

// Bộ thẩm định cảm nhận — bản MÔ PHỎNG chạy offline.
// TODO: thay bằng Gemini (gemini-2.5-flash) gọi qua Cloud Function
// để không lộ API key trong app/web.

class VerifyResult {
  const VerifyResult({
    required this.score,
    required this.approved,
    required this.soulmate,
    required this.bonusXp,
    required this.comment,
  });

  final int score;
  final bool approved;
  final bool soulmate;
  final int bonusXp;
  final String comment;
}

final _splitter = RegExp(r'[^\p{L}\d]+', unicode: true);

Future<VerifyResult> verifyReflection({
  required String content,
  required bool hasPhoto,
  required Location location,
}) async {
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
