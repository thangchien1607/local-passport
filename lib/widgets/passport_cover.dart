import 'package:flutter/material.dart';

import '../theme.dart';

/// Nền bìa hộ chiếu burgundy với hoa văn guilloche mảnh màu vàng.
class PassportCover extends StatelessWidget {
  const PassportCover({super.key, required this.child, this.radius = 0});

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CustomPaint(painter: const _GuillochePainter(), child: child),
    );
  }
}

class _GuillochePainter extends CustomPainter {
  const _GuillochePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.primary);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final bottom = Offset(size.width / 2, size.height * 1.2);
    final top = Offset(size.width / 2, -size.height * 0.2);
    final maxR = size.longestSide * 1.5;
    p.color = AppColors.goldLight.withValues(alpha: 0.10);
    for (var r = 9.0; r < maxR; r += 9) {
      canvas.drawCircle(bottom, r, p);
    }
    p.color = AppColors.goldLight.withValues(alpha: 0.07);
    for (var r = 11.0; r < maxR; r += 11) {
      canvas.drawCircle(top, r, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
