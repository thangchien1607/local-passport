import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;

/// Cạnh dài mục tiêu (px) khi nén ảnh ở client.
const photoMaxDimension = 1280;

/// Chất lượng JPEG mục tiêu (0–100).
const photoJpegQuality = 80;

/// Kiểm tra chuỗi có phải URL ảnh (HTTP/HTTPS) hay dữ liệu base64.
bool isNetworkImageUrl(String? value) =>
    value != null &&
    (value.startsWith('https://') || value.startsWith('http://'));

/// Nén ảnh phía client về JPEG với cạnh dài tối đa [maxDimension] và chất lượng
/// [quality]. Dùng native `flutter_image_compress` trên Android/iOS và fallback
/// thuần Dart (`package:image`) trên Web, desktop hoặc môi trường test.
Future<Uint8List> compressImageBytes(
  Uint8List bytes, {
  int maxDimension = photoMaxDimension,
  int quality = photoJpegQuality,
}) async {
  if (bytes.isEmpty) {
    throw const FormatException('Dữ liệu ảnh trống.');
  }

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
