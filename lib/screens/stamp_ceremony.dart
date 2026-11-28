import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/community.dart';
import '../data/routes.dart';
import '../services/ai_verifier.dart';
import '../services/photo_service.dart';
import '../services/validators.dart';
import '../state/passport_store.dart';
import '../theme.dart';

/// Hiệu ứng "Đóng dấu cái cộp" + hộp thoại cảm nhận tùy chọn (có chế độ ẩn danh).
Future<void> showStampCeremony(
  BuildContext context,
  String locationId, {
  bool startAtFeedback = false,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Nhận dấu mộc',
    barrierColor: const Color(0xB3120B07),
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, _, _) =>
        _Ceremony(locationId: locationId, startAtFeedback: startAtFeedback),
    transitionBuilder: (context, anim, _, child) =>
        FadeTransition(opacity: anim, child: child),
  );
}

enum _Step { stamp, ask, form, verifying, result }

class _Ceremony extends StatefulWidget {
  const _Ceremony({required this.locationId, required this.startAtFeedback});

  final String locationId;
  final bool startAtFeedback;

  @override
  State<_Ceremony> createState() => _CeremonyState();
}

class _CeremonyState extends State<_Ceremony> {
  late _Step _step = widget.startAtFeedback ? _Step.form : _Step.stamp;
  final _text = TextEditingController();
  bool _anonymous = false;
  Uint8List? _photo;
  String? _error;
  VerifyResult? _result;

  String _formatError(Object e) {
    if (e is FormatException) return e.message;
    return e.toString().replaceFirst('Exception: ', '');
  }

  Location get _location => locationById[widget.locationId]!;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 90,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _photo = bytes;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không đọc được ảnh.');
      }
    }
  }

  Future<void> _submit() async {
    final store = PassportScope.read(context);
    setState(() {
      _step = _Step.verifying;
      _error = null;
    });
    final reflectionId = 'r${DateTime.now().millisecondsSinceEpoch}';
    final displayAuthor = _anonymous
        ? anonymousAuthor
        : (store.user?.name ?? 'Lữ khách');

    late final VerifyResult r;
    try {
      r = await verifyReflection(
        content: _text.text,
        hasPhoto: _photo != null,
        location: _location,
        reflectionId: reflectionId,
        displayAuthor: displayAuthor,
        isAnonymous: _anonymous,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _step = _Step.form;
        _error = _formatError(e);
      });
      return;
    }
    if (!mounted) return;
    if (r.approved) {
      String? photoBase64;
      if (_photo != null) {
        try {
          photoBase64 = await compressImageToBase64(_photo!);
        } catch (e) {
          if (!mounted) return;
          setState(() {
            _step = _Step.form;
            _error = _formatError(e);
          });
          return;
        }
      }
      if (!mounted) return;
      store.addReflection(
        id: reflectionId,
        locationId: widget.locationId,
        content: _text.text.trim(),
        isAnonymous: _anonymous,
        aiScore: r.score,
        bonusXp: r.bonusXp,
        photoBase64: photoBase64,
      );
    }
    setState(() {
      _result = r;
      _step = _Step.result;
    });
  }

  void _close() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    if (_step == _Step.stamp) {
      return _StampScreen(
        location: _location,
        route: routeById[_location.routeId]!,
        date: PassportScope.of(context).stamps[widget.locationId],
        onContinue: () => setState(() => _step = _Step.ask),
      );
    }
    final isSheet = _step == _Step.form || _step == _Step.verifying;
    return SafeArea(
      child: Align(
        alignment: isSheet ? Alignment.bottomCenter : Alignment.center,
        child: Material(
          color: Colors.transparent,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.06),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: KeyedSubtree(
              key: ValueKey(_step == _Step.verifying ? _Step.form : _step),
              child: _buildStep(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _panel({required Widget child, bool sheet = false}) => Container(
    margin: sheet ? EdgeInsets.zero : const EdgeInsets.all(16),
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: sheet
          ? const BorderRadius.vertical(top: Radius.circular(26))
          : BorderRadius.circular(26),
      boxShadow: const [
        BoxShadow(
          color: Color(0x40000000),
          blurRadius: 30,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: child,
  );

  Widget _buildStep() {
    final route = routeById[_location.routeId]!;

    switch (_step) {
      case _Step.stamp:
        return const SizedBox.shrink();

      case _Step.ask:
        return _panel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bạn có muốn lưu lại cảm nhận tại đây không?',
                style: displayStyle(24),
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: hasRemoteReflectionVerifier
                          ? 'Không bắt buộc. Cảm nhận được AI thẩm định trên máy chủ để nhận thêm XP và huy hiệu '
                          : 'Không bắt buộc. Bộ chấm demo sẽ đánh giá cảm nhận để nhận thêm XP và huy hiệu ',
                    ),
                    TextSpan(
                      text: 'Tri kỷ Văn hóa',
                      style: bodyStyle(
                        14,
                        weight: FontWeight.w700,
                        color: AppColors.gold,
                      ),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
                style: bodyStyle(14, color: AppColors.inkSoft, height: 1.5),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(label: 'Bỏ qua', onPressed: _close),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PrimaryButton(
                      label: 'Viết cảm nhận',
                      onPressed: () => setState(() => _step = _Step.form),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

      case _Step.form:
      case _Step.verifying:
        final verifying = _step == _Step.verifying;
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.92,
          ),
          child: _panel(
            sheet: true,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _location.name.toUpperCase(),
                              style: bodyStyle(
                                12,
                                weight: FontWeight.w600,
                                color: route.color,
                                letterSpacing: 2,
                              ),
                            ),
                            Text('Cảm nhận của bạn', style: displayStyle(24)),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Đóng',
                        onPressed: verifying ? null : _close,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Điều gì khiến bạn ấn tượng nhất?',
                    style: bodyStyle(14, weight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _text,
                    enabled: !verifying,
                    minLines: 4,
                    maxLines: 6,
                    maxLength: reflectionMaxLength,
                    style: bodyStyle(15, height: 1.5),
                    decoration: InputDecoration(
                      helperText: validateReflection(_text.text),
                      helperStyle: bodyStyle(12, color: AppColors.inkSoft),
                      hintText:
                          'Ví dụ: Kéo TimeLens mới thấy cổng thành xưa nhìn thẳng ra cửa sông…',
                      hintStyle: bodyStyle(
                        15,
                        color: AppColors.inkSoft.withValues(alpha: 0.7),
                      ),
                      filled: true,
                      fillColor: AppColors.paper,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.gold),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.line),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (_photo != null)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.memory(
                            _photo!,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              height: 180,
                              width: double.infinity,
                              color: AppColors.paper2,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.broken_image_outlined,
                                    size: 36,
                                    color: Color(0xFFB91C1C),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Không xem trước được tệp ảnh này.',
                                    style: bodyStyle(
                                      13,
                                      color: const Color(0xFFB91C1C),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: IconButton.filled(
                            tooltip: 'Bỏ ảnh',
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black54,
                            ),
                            onPressed: verifying
                                ? null
                                : () => setState(() {
                                    _photo = null;
                                    _error = null;
                                  }),
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    SecondaryButton(
                      label: 'Thêm ảnh thực tế',
                      icon: Icons.add_photo_alternate_outlined,
                      onPressed: verifying ? null : _pickPhoto,
                    ),
                  const SizedBox(height: 14),
                  Material(
                    color: AppColors.paper2,
                    borderRadius: BorderRadius.circular(16),
                    child: SwitchListTile(
                      value: _anonymous,
                      onChanged: verifying
                          ? null
                          : (v) => setState(() => _anonymous = v),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      activeThumbColor: Colors.white,
                      activeTrackColor: AppColors.primary,
                      secondary: const Icon(
                        Icons.theater_comedy_outlined,
                        color: AppColors.ink,
                      ),
                      title: Text(
                        'Chia sẻ ẩn danh',
                        style: bodyStyle(14, weight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'Hiển thị là "Một Lữ khách Ẩn danh"',
                        style: bodyStyle(12, color: AppColors.inkSoft),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _error!,
                        style: bodyStyle(13, color: const Color(0xFFB91C1C)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  PrimaryButton(
                    label: verifying ? 'AI đang thẩm định…' : 'Gửi cảm nhận',
                    loading: verifying,
                    onPressed: validateReflection(_text.text) == null
                        ? _submit
                        : null,
                  ),
                ],
              ),
            ),
          ),
        );

      case _Step.result:
        final r = _result!;
        return _panel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: r.soulmate
                    ? AppColors.gold.withValues(alpha: 0.15)
                    : AppColors.progress.withValues(alpha: 0.1),
                child: Icon(
                  r.soulmate ? Icons.auto_awesome : Icons.check_rounded,
                  size: 30,
                  color: r.soulmate ? AppColors.gold : AppColors.progressInk,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                r.soulmate
                    ? 'Tri kỷ Văn hóa!'
                    : r.approved
                    ? 'Đã đăng cảm nhận'
                    : 'Chưa đủ để đăng',
                style: displayStyle(24),
              ),
              const SizedBox(height: 8),
              Text(
                r.comment,
                textAlign: TextAlign.center,
                style: bodyStyle(14, color: AppColors.inkSoft),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                children: [
                  _Pill(
                    '${r.isAi ? 'Gemini' : 'Điểm demo'}: ${r.score}/100',
                    color: AppColors.ink,
                    background: AppColors.paper2,
                  ),
                  if (r.bonusXp > 0)
                    _Pill(
                      '+${r.bonusXp} XP',
                      color: AppColors.progressInk,
                      background: AppColors.progress.withValues(alpha: 0.1),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              if (!r.approved) ...[
                PrimaryButton(
                  label: 'Viết thêm',
                  onPressed: () => setState(() => _step = _Step.form),
                ),
                const SizedBox(height: 10),
                SecondaryButton(label: 'Xong', onPressed: _close),
              ] else
                PrimaryButton(label: 'Xong', onPressed: _close),
            ],
          ),
        );
    }
  }
}

/// Màn "Cộp!" toàn màn hình nền tối: con dấu rơi xuống (scale 2.8 → 1),
/// rung nhẹ khi chạm, rồi chữ "Cộp!" bật ra.
class _StampScreen extends StatefulWidget {
  const _StampScreen({
    required this.location,
    required this.route,
    required this.date,
    required this.onContinue,
  });

  final Location location;
  final RouteInfo route;
  final DateTime? date;
  final VoidCallback onContinue;

  @override
  State<_StampScreen> createState() => _StampScreenState();
}

class _StampScreenState extends State<_StampScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.value = 1;
    } else if (_c.value == 0) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final year = (widget.date ?? DateTime.now()).year;
    return Material(
      color: AppColors.night,
      child: CustomPaint(
        painter: const _RingsPainter(),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                const SizedBox(height: 52),
                Text(
                  'HOÀN THÀNH 100%',
                  style: bodyStyle(
                    12,
                    weight: FontWeight.w700,
                    color: AppColors.goldLight,
                    letterSpacing: 3,
                  ),
                ),
                const Spacer(flex: 2),
                AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) {
                    final t = _c.value;
                    final drop = Curves.easeOutBack.transform(
                      ((t - 0.2) / 0.3).clamp(0.0, 1.0),
                    );
                    final shakeT = ((t - 0.45) / 0.3).clamp(0.0, 1.0);
                    final shake = sin(shakeT * pi * 5) * 7 * (1 - shakeT);
                    final pop = ((t - 0.5) / 0.25).clamp(0.0, 1.0);
                    return Column(
                      children: [
                        Transform.translate(
                          offset: Offset(shake, 0),
                          child: Opacity(
                            opacity: ((t - 0.2) / 0.12).clamp(0.0, 1.0),
                            child: Transform.rotate(
                              angle: (-30 + 20 * drop) * pi / 180,
                              child: Transform.scale(
                                scale: 2.8 - 1.8 * drop,
                                child: _CeremonySeal(
                                  name: widget.location.name,
                                  footer:
                                      '$year · ${widget.route.short.toUpperCase()}',
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 26),
                        Opacity(
                          opacity: pop,
                          child: Transform.scale(
                            scale: pop < 1
                                ? Curves.elasticOut.transform(pop) * 1.1
                                : 1,
                            child: Text(
                              'Cộp!',
                              style: displayStyle(
                                44,
                                weight: FontWeight.w700,
                                color: AppColors.goldLight,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
                Text(
                  'Dấu mộc mới!',
                  style: displayStyle(28, color: Colors.white),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    '${widget.location.name} đã được đóng dấu vào hộ chiếu của bạn.',
                    textAlign: TextAlign.center,
                    style: bodyStyle(
                      14,
                      height: 1.5,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 8, 16, 8),
                  decoration: BoxDecoration(
                    color: AppColors.goldLight.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.goldLight.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.local_fire_department_rounded,
                        size: 18,
                        color: AppColors.goldLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '+$stampXp XP',
                        style: bodyStyle(
                          14,
                          weight: FontWeight.w700,
                          color: AppColors.goldLight,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 3),
                PrimaryButton(
                  label: 'Tiếp tục',
                  background: AppColors.goldLight,
                  foreground: AppColors.night,
                  onPressed: widget.onContinue,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Con dấu mộc màu son: vòng ngoài đậm, vòng trong nét đứt.
class _CeremonySeal extends StatelessWidget {
  const _CeremonySeal({required this.name, required this.footer});

  final String name;
  final String footer;

  static const _rim = Color(0xFFC2410C);
  static const _text = Color(0xFFF97316);

  @override
  Widget build(BuildContext context) {
    final small = bodyStyle(
      12,
      weight: FontWeight.w700,
      color: _text,
      letterSpacing: 2.5,
    );
    return Semantics(
      label: 'Dấu mộc $name',
      image: true,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: 200,
        child: CustomPaint(
          painter: const _SealRimPainter(_rim),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('ĐÀ NẴNG · VN', style: small),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    style: displayStyle(
                      32,
                      weight: FontWeight.w700,
                      color: const Color(0xFFFDBA74),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(footer, style: small),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SealRimPainter extends CustomPainter {
  const _SealRimPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(
      c,
      r,
      Paint()..color = AppColors.primary.withValues(alpha: 0.25),
    );
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..color = color;
    canvas.drawCircle(c, r - 2.5, stroke..strokeWidth = 5);
    // Vòng trong nét đứt 6/4.
    final inner = r - 16;
    final rect = Rect.fromCircle(center: c, radius: inner);
    const dash = 6.0, gap = 4.0;
    stroke.strokeWidth = 2;
    for (var d = 0.0; d < 2 * pi * inner; d += dash + gap) {
      canvas.drawArc(rect, d / inner, dash / inner, false, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _SealRimPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Các vòng tròn đồng tâm mờ dần quanh con dấu.
class _RingsPainter extends CustomPainter {
  const _RingsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.4);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < 10; i++) {
      p.color = AppColors.goldLight.withValues(alpha: 0.12 - i * 0.01);
      canvas.drawCircle(c, 30 + i * 26.0, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, {required this.color, required this.background});

  final String text;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: bodyStyle(14, weight: FontWeight.w600, color: color),
    ),
  );
}
