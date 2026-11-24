import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;

/// Cạnh dài mục tiêu (px) khi nén ảnh trước khi tải lên Storage.
const photoMaxDimension = 1280;

/// Chất lượng JPEG mục tiêu (0–100).
const photoJpegQuality = 80;

/// Giới hạn dung lượng tối đa cho mỗi ảnh sau nén (5 MB, khớp storage.rules).
const photoMaxUploadBytes = 5 * 1024 * 1024;

/// Kiểm tra chuỗi có phải URL ảnh (HTTP/HTTPS) hay dữ liệu base64 cũ.
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

/// Giao diện lưu trữ ảnh. Tách abstract để test dùng bản giả không cần Firebase.
abstract class PhotoStorageGateway {
  Future<String> uploadTaskPhoto({
    required String uid,
    required String locationId,
    required String taskId,
    required Uint8List bytes,
  });

  Future<String> uploadReflectionPhoto({
    required String uid,
    required String reflectionId,
    required Uint8List bytes,
  });

  Future<void> deleteByUrl(String url);
}

/// Triển khai Firebase Storage: nén ảnh rồi tải lên thư mục theo `uid`.
class FirebasePhotoStorageGateway implements PhotoStorageGateway {
  FirebasePhotoStorageGateway({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  @override
  Future<String> uploadTaskPhoto({
    required String uid,
    required String locationId,
    required String taskId,
    required Uint8List bytes,
  }) async {
    final safeLoc = _sanitizeSegment(locationId);
    final safeTask = _sanitizeSegment(taskId);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = 'users/$uid/tasks/$safeLoc/${safeTask}_$ts.jpg';
    return _compressAndUpload(path, bytes);
  }

  @override
  Future<String> uploadReflectionPhoto({
    required String uid,
    required String reflectionId,
    required Uint8List bytes,
  }) async {
    final safeId = _sanitizeSegment(reflectionId);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = 'users/$uid/reflections/${safeId}_$ts.jpg';
    return _compressAndUpload(path, bytes);
  }

  @override
  Future<void> deleteByUrl(String url) async {
    if (!isNetworkImageUrl(url)) return;
    try {
      await _storage.refFromURL(url).delete();
    } catch (e) {
      debugPrint('Không xóa được ảnh trên Storage: $e');
    }
  }

  Future<String> _compressAndUpload(String path, Uint8List rawBytes) async {
    final compressed = await compressImageBytes(rawBytes);
    if (compressed.lengthInBytes > photoMaxUploadBytes) {
      throw Exception('Ảnh sau nén vẫn vượt quá 5 MB.');
    }
    final ref = _storage.ref().child(path);
    await ref.putData(
      compressed,
      SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'public, max-age=31536000',
      ),
    );
    return ref.getDownloadURL();
  }

  static String _sanitizeSegment(String input) =>
      input.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
}
