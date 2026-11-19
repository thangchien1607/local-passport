import '../data/community.dart';
import '../data/routes.dart';

const _from =
    'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
const _to =
    'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';

/// Chữ thường, bỏ dấu tiếng Việt, gom khoảng trắng: "Điện  Hải" → "dien hai".
String foldVietnamese(String input) {
  final lower = input.toLowerCase();
  final out = StringBuffer();
  for (final ch in lower.split('')) {
    final i = _from.indexOf(ch);
    out.write(i < 0 ? ch : _to[i]);
  }
  return out
      .toString()
      // Dấu tổ hợp rời (một số bàn phím gõ dạng NFD).
      .replaceAll(RegExp('[̀-ͯ]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Mọi từ trong [query] đều xuất hiện trong [text] (không phân biệt hoa thường, dấu).
/// Từ khóa rỗng thì luôn khớp.
bool matchesQuery(String text, String query) {
  final words = foldVietnamese(query).split(' ').where((w) => w.isNotEmpty);
  if (words.isEmpty) return true;
  final haystack = foldVietnamese(text);
  return words.every(haystack.contains);
}

/// Tìm theo tên, địa chỉ, tuyến, câu chuyện và nhiệm vụ của địa điểm.
bool locationMatches(Location l, String query) => matchesQuery(
  [
    l.name,
    l.address,
    routeById[l.routeId]?.title ?? '',
    for (final s in l.stories) '${s.title} ${s.body}',
    for (final t in l.tasks) t.title,
  ].join(' '),
  query,
);

/// Tìm theo nội dung, tên tác giả và địa điểm của bài cảm nhận.
bool reflectionMatches(Reflection r, String query) => matchesQuery(
  '${r.content} ${r.displayAuthor} ${locationById[r.locationId]?.name ?? ''}',
  query,
);
