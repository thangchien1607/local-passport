import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum Era { past, present }

// Bộ lọc sepia (cùng ma trận với bản web).
const _sepia = ColorFilter.matrix(<double>[
  0.393, 0.769, 0.189, 0, 0, //
  0.349, 0.686, 0.168, 0, 0,
  0.272, 0.534, 0.131, 0, 0,
  0, 0, 0, 1, 0,
]);

/// Tranh minh họa giữ chỗ cho TimeLens khi chưa có ảnh tư liệu thật.
/// Era.past: phủ sepia + hạt phim + vết xước + vignette (Vintage Analog).
/// Nếu truyền [imageUrl] (URL hoặc asset `assets/...`), hiển thị ảnh thật thay cho tranh.
class SceneArt extends StatelessWidget {
  const SceneArt({
    super.key,
    required this.scene,
    this.era = Era.present,
    this.imageUrl,
    this.semanticLabel,
  });

  final String scene;
  final Era era;
  final String? imageUrl;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final Widget base = url == null
        ? SvgPicture.asset(
            'assets/scenes/${scene}_${era == Era.past ? 'past' : 'present'}.svg',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          )
        : url.startsWith('assets/')
        ? Image.asset(
            url,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          )
        : Image.network(
            url,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          );

    return Semantics(
      label: semanticLabel,
      image: true,
      child: era == Era.present
          ? base
          : Stack(
              fit: StackFit.expand,
              children: [
                ColorFiltered(colorFilter: _sepia, child: base),
                const IgnorePointer(
                  child: CustomPaint(painter: _FilmPainter()),
                ),
                const IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        radius: 0.9,
                        colors: [
                          Color(0x00000000),
                          Color(0x00000000),
                          Color(0x8C2B1608),
                        ],
                        stops: [0, 0.55, 1],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Hạt phim + vài vết xước, sinh ngẫu nhiên với seed cố định để không nhấp nháy.
class _FilmPainter extends CustomPainter {
  const _FilmPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(7);
    final dark = Paint()..color = const Color(0x22301A08);
    final light = Paint()..color = const Color(0x18FFF8E6);
    final count = (size.width * size.height / 90).clamp(200, 5000).toInt();
    for (var i = 0; i < count; i++) {
      final o = Offset(
        rnd.nextDouble() * size.width,
        rnd.nextDouble() * size.height,
      );
      canvas.drawCircle(
        o,
        rnd.nextDouble() * 0.9 + 0.3,
        i.isEven ? dark : light,
      );
    }
    final scratch = Paint()
      ..color = const Color(0x80FFF8E6)
      ..strokeWidth = 0.8;
    canvas.drawLine(
      Offset(size.width * 0.18, 0),
      Offset(size.width * 0.19, size.height),
      scratch,
    );
    canvas.drawLine(
      Offset(size.width * 0.72, 0),
      Offset(size.width * 0.715, size.height * 0.46),
      scratch,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
