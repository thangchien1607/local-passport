import 'package:flutter/material.dart';

import '../data/routes.dart';
import '../theme.dart';
import 'scene_art.dart';

/// Lăng kính thời gian: kéo thanh trượt để so sánh ảnh xưa (trái) & nay (phải).
/// [onExplored] được gọi một lần khi người dùng kéo gần hết về một phía.
class TimeLens extends StatefulWidget {
  const TimeLens({super.key, required this.location, this.onExplored});

  final Location location;
  final VoidCallback? onExplored;

  @override
  State<TimeLens> createState() => _TimeLensState();
}

class _TimeLensState extends State<TimeLens>
    with SingleTickerProviderStateMixin {
  double _pos = 0.5;
  bool _explored = false;
  bool _touched = false;
  late final AnimationController _hint;

  @override
  void initState() {
    super.initState();
    // Gợi ý "kéo được": tay nắm lắc nhẹ 1 lần khi xuất hiện.
    _hint =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1400),
        )..addListener(() {
          if (_touched) return;
          final t = _hint.value;
          setState(() => _pos = 0.5 + 0.12 * _wiggle(t));
        });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || MediaQuery.of(context).disableAnimations) return;
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_touched) _hint.forward();
      });
    });
  }

  double _wiggle(double t) {
    // 0 → -1 → +1 → 0
    if (t < 0.25) return -t / 0.25;
    if (t < 0.75) return -1 + (t - 0.25) / 0.5 * 2;
    return 1 - (t - 0.75) / 0.25;
  }

  @override
  void dispose() {
    _hint.dispose();
    super.dispose();
  }

  void _setPos(double p) {
    _touched = true;
    _hint.stop();
    setState(() => _pos = p.clamp(0.0, 1.0));
    if (!_explored && (_pos < 0.2 || _pos > 0.8)) {
      _explored = true;
      widget.onExplored?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lens = widget.location.timeLens;
    final slider = Semantics(
      slider: true,
      label: 'Lăng kính thời gian ${widget.location.name}',
      value: '${(_pos * 100).round()}% ảnh xưa',
      increasedValue: '${((_pos + 0.1).clamp(0, 1) * 100).round()}%',
      decreasedValue: '${((_pos - 0.1).clamp(0, 1) * 100).round()}%',
      onIncrease: () => _setPos(_pos + 0.1),
      onDecrease: () => _setPos(_pos - 0.1),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AspectRatio(
          aspectRatio: 20 / 13,
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (d) => _setPos(d.localPosition.dx / w),
                onHorizontalDragUpdate: (d) => _setPos(d.localPosition.dx / w),
                onTapDown: (d) => _setPos(d.localPosition.dx / w),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    SceneArt(
                      scene: widget.location.scene,
                      era: Era.present,
                      imageUrl: lens.presentImageUrl,
                    ),
                    ClipRect(
                      clipper: _LeftClipper(_pos),
                      child: SceneArt(
                        scene: widget.location.scene,
                        era: Era.past,
                        imageUrl: lens.pastImageUrl,
                      ),
                    ),
                    // Đường chia + tay nắm
                    Positioned(
                      left: _pos * w - 1.5,
                      top: 0,
                      bottom: 0,
                      child: Container(width: 3, color: AppColors.goldLight),
                    ),
                    Positioned(
                      left: _pos * w - 22,
                      top: c.maxHeight / 2 - 22,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.goldLight,
                            width: 2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x4D000000),
                              blurRadius: 10,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.compare_arrows_rounded,
                          color: AppColors.goldLight,
                          size: 22,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      top: 10,
                      child: _Label(text: 'Xưa · ${lens.pastYear}', dark: true),
                    ),
                    Positioned(
                      right: 10,
                      top: 10,
                      child: _Label(
                        text: 'Nay · ${lens.presentYear}',
                        dark: false,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
    // Con trỏ kéo ngang khi dùng chuột (web/desktop).
    final lensView = MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: slider,
    );
    final caption = lens.caption;
    final credit = lens.credit;
    if (caption == null && credit == null) return lensView;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        lensView,
        if (caption != null) ...[
          const SizedBox(height: 8),
          Text(
            caption,
            style: bodyStyle(13, color: AppColors.inkSoft, height: 1.4),
          ),
        ],
        if (credit != null) ...[
          const SizedBox(height: 4),
          Text(
            credit,
            style: bodyStyle(
              11,
              color: AppColors.inkSoft.withValues(alpha: 0.8),
            ),
          ),
        ],
      ],
    );
  }
}

class _LeftClipper extends CustomClipper<Rect> {
  _LeftClipper(this.fraction);
  final double fraction;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(_LeftClipper old) => old.fraction != fraction;
}

class _Label extends StatelessWidget {
  const _Label({required this.text, required this.dark});
  final String text;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: dark ? const Color(0xCC3B2414) : const Color(0xD9FFFFFF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: dark
            ? displayStyle(
                13,
                weight: FontWeight.w500,
                color: const Color(0xFFF3E2B3),
                fontStyle: FontStyle.italic,
              )
            : bodyStyle(13, weight: FontWeight.w600),
      ),
    );
  }
}
