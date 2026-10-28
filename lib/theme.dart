import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Design system — tổng hợp từ dữ liệu UI UX Pro Max
// (Travel/Tourism + Museum + E-learning + Heritage):
//   Pattern: Storytelling + Feature-Rich, progress tracking & achievement unlocks
//   Style:   Vintage Analog (ảnh xưa) + Micro-interactions + Motion-Driven (đóng mộc)
//   Màu:     Burgundy #7C2D12 + Craft gold #A16207, progress teal #0D9488
//   Font:    Playfair Display (tiêu đề) + Inter (nội dung) — "Classic Elegant"
class AppColors {
  static const paper = Color(0xFFFBF6EC);
  static const paper2 = Color(0xFFF3E9D7);
  static const card = Color(0xFFFFFDF8);
  static const ink = Color(0xFF2B1810);
  static const inkSoft = Color(0xFF6B5547);
  static const line = Color(0xFFE8DCC8);
  static const outside = Color(0xFFE9DFCD);

  static const primary = Color(0xFF7C2D12);
  static const primaryDark = Color(0xFF5A1F0B);
  static const gold = Color(0xFFA16207);
  static const goldLight = Color(0xFFE9C46A);
  static const progress = Color(0xFF0D9488);
  static const progressInk = Color(0xFF0F766E);
  static const night = Color(0xFF120B07);

  static const mapSea = Color(0xFFCFE3E6);
}

TextStyle displayStyle(
  double size, {
  FontWeight weight = FontWeight.w600,
  Color? color,
  FontStyle? fontStyle,
  double? height,
}) {
  return GoogleFonts.playfairDisplay(
    fontSize: size,
    fontWeight: weight,
    color: color ?? AppColors.ink,
    fontStyle: fontStyle,
    height: height ?? 1.2,
  );
}

TextStyle bodyStyle(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color? color,
  double? height,
  double? letterSpacing,
}) {
  return GoogleFonts.inter(
    fontSize: size,
    fontWeight: weight,
    color: color ?? AppColors.ink,
    height: height,
    letterSpacing: letterSpacing,
  );
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      surface: AppColors.paper,
    ),
    scaffoldBackgroundColor: AppColors.paper,
  );
  return base.copyWith(
    textTheme: GoogleFonts.interTextTheme(
      base.textTheme,
    ).apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
    splashFactory: InkSparkle.splashFactory,
  );
}

/// Nút chính: nền burgundy, cao ≥ 52px (vùng chạm ≥ 44px theo UX guideline).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.background,
    this.foreground,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final fg = foreground ?? Colors.white;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: background ?? AppColors.primary,
          foregroundColor: fg,
          disabledBackgroundColor: (background ?? AppColors.primary).withValues(
            alpha: 0.5,
          ),
          disabledForegroundColor: fg.withValues(alpha: 0.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: fg),
              )
            else if (icon != null)
              Icon(icon, size: 20),
            if (loading || icon != null) const SizedBox(width: 8),
            Text(
              label,
              style: bodyStyle(16, weight: FontWeight.w600, color: fg),
            ),
          ],
        ),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.inkSoft;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: c,
          side: BorderSide(
            color: color?.withValues(alpha: 0.3) ?? AppColors.line,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                style: bodyStyle(15, weight: FontWeight.w600, color: c),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

BoxDecoration cardDecoration({Color? borderColor, double radius = 18}) =>
    BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? AppColors.line),
    );
