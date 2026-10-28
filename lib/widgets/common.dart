import 'package:flutter/material.dart';

import '../theme.dart';

class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.value,
    this.color = AppColors.progress,
    this.height = 8,
    this.label,
  });

  /// 0–100
  final int value;
  final Color color;
  final double height;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      value: '$value%',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: Container(
          height: height,
          color: AppColors.paper2,
          alignment: Alignment.centerLeft,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: value / 100),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => FractionallySizedBox(
              widthFactor: v.clamp(0, 1),
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(height),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.unlocked, required this.stamped});

  final bool unlocked;
  final bool stamped;

  @override
  Widget build(BuildContext context) {
    final (label, icon, fg, bg) = stamped
        ? (
            'Đã đóng mộc',
            Icons.verified_outlined,
            AppColors.progressInk,
            AppColors.progress.withValues(alpha: 0.1),
          )
        : unlocked
        ? (
            'Đang khám phá',
            null,
            AppColors.gold,
            AppColors.gold.withValues(alpha: 0.1),
          )
        : (
            'Chưa mở khóa',
            Icons.lock_outline,
            AppColors.inkSoft,
            AppColors.paper2,
          );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: bodyStyle(11, weight: FontWeight.w600, color: fg),
          ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: AppColors.gold),
            const SizedBox(width: 8),
          ],
          Flexible(child: Text(text, style: displayStyle(20))),
        ],
      ),
    );
  }
}

/// Chip lọc dạng viên thuốc, cao 44px.
class FilterPill extends StatelessWidget {
  const FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final active = color ?? AppColors.ink;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? active : AppColors.card,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? Colors.transparent : AppColors.line,
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 16,
                    color: selected ? Colors.white : AppColors.ink,
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: bodyStyle(
                    14,
                    weight: FontWeight.w600,
                    color: selected
                        ? (color == null ? AppColors.paper : Colors.white)
                        : AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void showToast(
  BuildContext context,
  String message, {
  Duration duration = const Duration(milliseconds: 2600),
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: bodyStyle(14, weight: FontWeight.w500, color: AppColors.paper),
        ),
        backgroundColor: AppColors.ink,
        behavior: SnackBarBehavior.floating,
        shape: const StadiumBorder(),
        duration: duration,
      ),
    );
}
