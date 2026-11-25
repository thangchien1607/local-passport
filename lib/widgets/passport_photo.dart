import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/photo_service.dart';
import '../theme.dart';

/// Hiển thị ảnh từ dữ liệu nén `photoBase64` trong Firestore hoặc URL ảnh cũ
/// (`photoUrl`) để đảm bảo tương thích ngược không làm mất dữ liệu.
class PassportPhoto extends StatelessWidget {
  const PassportPhoto({
    super.key,
    this.photoUrl,
    this.photoBase64,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.semanticLabel,
  });

  /// Tạo widget từ một chuỗi ảnh (tự nhận diện URL hay base64 cũ).
  factory PassportPhoto.fromValue(
    String value, {
    Key? key,
    double? height,
    double? width,
    BoxFit fit = BoxFit.cover,
    String? semanticLabel,
  }) => isNetworkImageUrl(value)
      ? PassportPhoto(
          key: key,
          photoUrl: value,
          height: height,
          width: width,
          fit: fit,
          semanticLabel: semanticLabel,
        )
      : PassportPhoto(
          key: key,
          photoBase64: value,
          height: height,
          width: width,
          fit: fit,
          semanticLabel: semanticLabel,
        );

  final String? photoUrl;
  final String? photoBase64;
  final double? height;
  final double? width;
  final BoxFit fit;
  final String? semanticLabel;

  Widget _placeholder(IconData icon) => Container(
    height: height ?? 134,
    width: width ?? double.infinity,
    color: AppColors.paper2,
    alignment: Alignment.center,
    child: Icon(icon, color: AppColors.inkSoft, size: 28),
  );

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;
    if (isNetworkImageUrl(url)) {
      return Image.network(
        url!,
        height: height,
        width: width,
        fit: fit,
        semanticLabel: semanticLabel,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _placeholder(Icons.photo_outlined);
        },
        errorBuilder: (context, _, _) =>
            _placeholder(Icons.broken_image_outlined),
      );
    }
    final b64 = photoBase64;
    if (b64 != null && b64.isNotEmpty) {
      try {
        return Image.memory(
          base64Decode(b64),
          height: height,
          width: width,
          fit: fit,
          semanticLabel: semanticLabel,
          errorBuilder: (context, _, _) =>
              _placeholder(Icons.broken_image_outlined),
        );
      } catch (_) {
        return _placeholder(Icons.broken_image_outlined);
      }
    }
    return const SizedBox.shrink();
  }
}
