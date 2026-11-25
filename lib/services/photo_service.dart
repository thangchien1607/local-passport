import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;

/// Cạnh dài khởi điểm (px) khi nén ảnh cho kiến trúc Spark (lưu Base64 trong Firestore).
const photoMaxDimension = 720;

/// Chất lượng JPEG khởi điểm (0–100).
const photoJpegQuality = 70;

/// Mục tiêu dung lượng nhị phân sau nén (<= 80 KB → Base64 <= ~109 KB).
const photoTargetBytes = 80 * 1024;

/// Ngưỡng từ chối tuyệt đối nếu giảm tới mức tối thiểu vẫn vượt quá (120 KB).
const photoHardMaxBytes = 120 * 1024;

/// Giới hạn độ dài chuỗi Base64 khớp `firestore.rules` (`size() <= 120000`).
const photoMaxBase64Length = 120000;

/// Số ảnh nhiệm vụ tối đa cho mỗi địa điểm (visit) để không chạm trần 1 MiB.
const maxTaskPhotosPerVisit = 3;

/// Ngưỡng ước lượng dung lượng document Firestore an toàn (~800 KB < 1 MiB).
const maxFirestoreDocBytes = 800 * 1024;

/// Ngoại lệ thân thiện khi ảnh sau nén tối đa vẫn vượt giới hạn lưu trữ.
class PhotoTooLargeException implements Exception {
  const PhotoTooLargeException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Ngoại lệ khi vượt số lượng ảnh cho phép trong một visit hoặc vượt ngưỡng document.
class PhotoLimitException implements Exception {
  const PhotoLimitException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Kiểm tra chuỗi có phải URL ảnh (HTTP/HTTPS) hay dữ liệu base64.
bool isNetworkImageUrl(String? value) =>
    value != null &&
    (value.startsWith('https://') || value.startsWith('http://'));

/// Các bước giảm dần (cạnh dài px, chất lượng JPEG) nhằm đưa ảnh về <= 80 KB
/// mà vẫn giữ chất lượng xem tốt nhất có thể.
const _compressionSteps = <(int dim, int quality)>[
  (720, 70),
  (720, 58),
  (720, 46),
  (600, 46),
  (600, 36),
  (480, 36),
  (480, 28),
  (360, 25),
  (280, 20),
];

/// Nén ảnh phía client bằng vòng lặp giảm dần kích thước/chất lượng cho tới khi
/// dung lượng <= [targetBytes] (mặc định 80 KB) và chuỗi Base64 <= [maxBase64Length].
/// Nếu đã giảm tới mức tối thiểu mà vẫn > [hardMaxBytes] (120 KB) hoặc Base64
/// vượt [maxBase64Length] thì ném [PhotoTooLargeException].
///
/// Chạy tương thích trên Android, iOS (`flutter_image_compress` có fallback thuần Dart)
/// và Web/Desktop (`package:image`).
Future<Uint8List> compressImageBytes(
  Uint8List bytes, {
  int maxDimension = photoMaxDimension,
  int quality = photoJpegQuality,
  int targetBytes = photoTargetBytes,
  int hardMaxBytes = photoHardMaxBytes,
  int maxBase64Length = photoMaxBase64Length,
}) async {
  if (bytes.isEmpty) {
    throw const FormatException('Dữ liệu ảnh trống.');
  }

  final steps = <(int, int)>[
    (maxDimension, quality),
    for (final s in _compressionSteps)
      if (s.$1 < maxDimension || s.$2 < quality) s,
  ];

  Uint8List? best;
  for (final (dim, q) in steps) {
    final candidate = await _compressOnce(bytes, maxDimension: dim, quality: q);
    if (best == null || candidate.lengthInBytes < best.lengthInBytes) {
      best = candidate;
    }
    final b64Len = _base64Length(candidate.lengthInBytes);
    if (candidate.lengthInBytes <= targetBytes && b64Len <= maxBase64Length) {
      return candidate;
    }
  }

  final result = best!;
  final b64Len = _base64Length(result.lengthInBytes);
  if (result.lengthInBytes > hardMaxBytes || b64Len > maxBase64Length) {
    throw const PhotoTooLargeException(
      'Ảnh quá lớn để lưu trực tiếp (vượt giới hạn 120 KB sau khi nén tối đa). '
      'Vui lòng chọn ảnh khác nhẹ hoặc đơn giản hơn.',
    );
  }
  return result;
}

/// Nén ảnh và trả về chuỗi Base64 đã đảm bảo <= [maxBase64Length].
Future<String> compressImageToBase64(
  Uint8List bytes, {
  int targetBytes = photoTargetBytes,
  int maxBase64Length = photoMaxBase64Length,
}) async {
  final compressed = await compressImageBytes(
    bytes,
    targetBytes: targetBytes,
    maxBase64Length: maxBase64Length,
  );
  final encoded = base64Encode(compressed);
  if (encoded.length > maxBase64Length) {
    throw const PhotoTooLargeException(
      'Ảnh sau khi mã hóa vượt giới hạn lưu trữ. Vui lòng chọn ảnh khác nhỏ hơn.',
    );
  }
  return encoded;
}

int _base64Length(int byteLength) => ((byteLength + 2) ~/ 3) * 4;

Future<Uint8List> _compressOnce(
  Uint8List bytes, {
  required int maxDimension,
  required int quality,
}) async {
  final useNative =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  if (useNative) {
    try {
      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: maxDimension,
        minHeight: maxDimension,
        quality: quality,
        format: CompressFormat.jpeg,
      );
      if (compressed.isNotEmpty) {
        return Uint8List.fromList(compressed);
      }
    } catch (_) {
      // Fallback sang bộ nén thuần Dart nếu plugin native không khả dụng (vd test).
    }
  }

  return _compressWithDartImage(
    bytes,
    maxDimension: maxDimension,
    quality: quality,
  );
}

Uint8List _compressWithDartImage(
  Uint8List bytes, {
  required int maxDimension,
  required int quality,
}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('Không giải mã được định dạng ảnh.');
  }
  final img.Image target;
  if (decoded.width > maxDimension || decoded.height > maxDimension) {
    if (decoded.width >= decoded.height) {
      target = img.copyResize(decoded, width: maxDimension);
    } else {
      target = img.copyResize(decoded, height: maxDimension);
    }
  } else {
    target = decoded;
  }
  return Uint8List.fromList(img.encodeJpg(target, quality: quality));
}

/// Ước lượng dung lượng (byte) của một document Firestore trước khi ghi
/// để đảm bảo luôn thấp hơn ngưỡng an toàn [maxFirestoreDocBytes] (~800 KB < 1 MiB).
int estimateFirestoreDocBytes(Map<String, dynamic> doc) =>
    _estimateValue(doc) + 64;

int _estimateValue(Object? value) {
  if (value == null) return 1;
  if (value is bool) return 1;
  if (value is num) return 8;
  if (value is String) return utf8.encode(value).length + 1;
  if (value is List) {
    var total = 4;
    for (final item in value) {
      total += _estimateValue(item);
    }
    return total;
  }
  if (value is Map) {
    var total = 32;
    for (final entry in value.entries) {
      total += utf8.encode(entry.key.toString()).length + 1;
      total += _estimateValue(entry.value);
    }
    return total;
  }
  // Timestamp hoặc đối tượng nhỏ khác (~16 byte).
  return 16;
}

/// Mã hóa map ảnh nhiệm vụ (`taskId -> base64`) thành danh sách chuỗi
/// (`"<taskId>:<base64>"`, tối đa [maxTaskPhotosPerVisit]) lưu trên Firestore.
List<String> encodeTaskPhotosList(Map<String, String> taskPhotos) {
  final list = <String>[];
  for (final entry in taskPhotos.entries) {
    if (list.length >= maxTaskPhotosPerVisit) break;
    if (entry.value.isEmpty) continue;
    list.add('${entry.key}:${entry.value}');
  }
  return list;
}

/// Giải mã trường `taskPhotos` từ Firestore (hỗ trợ cả dạng `List<String>` mới
/// lẫn dạng `Map<String, dynamic>` cũ để tương thích ngược).
Map<String, String> decodeTaskPhotosField(Object? raw) {
  if (raw is Map) {
    return {
      for (final e in raw.entries)
        if (e.value is String && (e.value as String).isNotEmpty)
          e.key.toString(): e.value as String,
    };
  }
  if (raw is List) {
    final result = <String, String>{};
    for (var i = 0; i < raw.length; i++) {
      final item = raw[i];
      if (item is! String || item.isEmpty) continue;
      final sep = item.indexOf(':');
      if (sep > 0 && sep < 40 && !item.startsWith('http')) {
        result[item.substring(0, sep)] = item.substring(sep + 1);
      } else {
        result['photo_$i'] = item;
      }
    }
    return result;
  }
  return {};
}
