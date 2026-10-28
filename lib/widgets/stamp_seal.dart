import 'dart:math';

import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';

import '../data/routes.dart';

/// Con dấu mộc tròn: viền kép, tên địa điểm chạy theo vòng, icon tuyến ở giữa, ngày đóng.
class StampSeal extends StatelessWidget {
  const StampSeal({
    super.key,
    required this.location,
    required this.route,
    this.date,
    this.size = 120,
    this.rotation = -8,
  });

  final Location location;
  final RouteInfo route;
  final DateTime? date;
  final double size;

  /// Độ xoay (độ) để trông như đóng tay.
  final double rotation;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Dấu mộc ${location.name}',
      image: true,
      child: Transform.rotate(
        angle: rotation * pi / 180,
        child: CustomPaint(
          size: Size.square(size),
          painter: _SealPainter(
            name: location.name.toUpperCase(),
            color: route.color,
            icon: route.icon,
            date: date,
          ),
        ),
      ),
    );
  }
}

class _SealPainter extends CustomPainter {
  _SealPainter({
    required this.name,
    required this.color,
    required this.icon,
    this.date,
  });

  final String name;
  final Color color;
  final IconData icon;
  final DateTime? date;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 200; // vẽ trên hệ tọa độ 200x200
    canvas.save();
    canvas.scale(s);
    const c = Offset(100, 100);
    final ink = color.withValues(alpha: 0.9);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..color = ink;
    canvas.drawCircle(c, 92, stroke..strokeWidth = 5);
    canvas.drawCircle(c, 82, stroke..strokeWidth = 1.5);
    canvas.drawCircle(c, 44, stroke..strokeWidth = 2);

    _arcText(
      canvas,
      c,
      66,
      name,
      fontSize: name.length > 20 ? 12 : 14,
      top: true,
      spacing: 1.5,
    );
    _arcText(
      canvas,
      c,
      60,
      '★ ĐÀ NẴNG ★',
      fontSize: 12,
      top: false,
      spacing: 3,
    );

    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: 34,
          color: ink,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    iconPainter.paint(
      canvas,
      Offset(
        100 - iconPainter.width / 2,
        date == null ? 100 - iconPainter.height / 2 : 66,
      ),
    );

    final d = date;
    if (d != null) {
      final dateText =
          '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
      final tp = TextPainter(
        text: TextSpan(
          text: dateText,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(100 - tp.width / 2, 116));
    }

    // Vài đốm "mực loang" cho cảm giác đóng tay.
    final rnd = Random(name.hashCode);
    final speck = Paint()..color = Colors.white.withValues(alpha: 0.55);
    for (var i = 0; i < 26; i++) {
      final a = rnd.nextDouble() * 2 * pi;
      final r = 80 + rnd.nextDouble() * 14;
      canvas.drawCircle(
        c + Offset(cos(a) * r, sin(a) * r),
        rnd.nextDouble() * 1.4 + 0.4,
        speck,
      );
    }
    canvas.restore();
  }

  void _arcText(
    Canvas canvas,
    Offset c,
    double r,
    String text, {
    required double fontSize,
    required bool top,
    double spacing = 0,
  }) {
    final style = GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      color: color.withValues(alpha: 0.9),
    );
    final glyphs = [
      for (final ch in text.characters)
        TextPainter(
          text: TextSpan(text: ch, style: style),
          textDirection: TextDirection.ltr,
        )..layout(),
    ];
    final total =
        glyphs.fold<double>(0, (sum, g) => sum + g.width + spacing) - spacing;
    final span = total / r;
    var acc = 0.0;
    for (final g in glyphs) {
      final mid = (acc + g.width / 2) / r;
      canvas.save();
      if (top) {
        final a = -pi / 2 - span / 2 + mid;
        canvas.translate(c.dx + cos(a) * r, c.dy + sin(a) * r);
        canvas.rotate(a + pi / 2);
        g.paint(canvas, Offset(-g.width / 2, -g.height * 0.8));
      } else {
        final a = pi / 2 + span / 2 - mid;
        canvas.translate(c.dx + cos(a) * r, c.dy + sin(a) * r);
        canvas.rotate(a - pi / 2);
        g.paint(canvas, Offset(-g.width / 2, -g.height * 0.2));
      }
      canvas.restore();
      acc += g.width + spacing;
    }
  }

  @override
  bool shouldRepaint(_SealPainter old) =>
      old.name != name || old.color != color || old.date != date;
}
