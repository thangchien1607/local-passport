import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/routes.dart';
import '../services/ai_verifier.dart';
import '../state/passport_store.dart';
import '../theme.dart';
import '../widgets/stamp_seal.dart';

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
  VerifyResult? _result;

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
        maxWidth: 720,
        maxHeight: 720,
        imageQuality: 72,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() => _photo = bytes);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(const SnackBar(content: Text('Không đọc được ảnh.')));
      }
    }
  }

  Future<void> _submit() async {
    final store = PassportScope.read(context);
    setState(() => _step = _Step.verifying);
    late final VerifyResult r;
    try {
      r = await verifyReflection(
        content: _text.text,
        hasPhoto: _photo != null,
        location: _location,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _step = _Step.form);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
      return;
    }
    if (!mounted) return;
    if (r.approved) {
      store.addReflection(
        locationId: widget.locationId,
        content: _text.text.trim(),
        isAnonymous: _anonymous,
        aiScore: r.score,
        bonusXp: r.bonusXp,
        photoBase64: _photo == null ? null : base64Encode(_photo!),
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
    final store = PassportScope.of(context);
    final route = routeById[_location.routeId]!;

    switch (_step) {
      case _Step.stamp:
        return _panel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'HOÀN THÀNH 100%',
                style: bodyStyle(
                  12,
                  weight: FontWeight.w600,
                  color: AppColors.gold,
                  letterSpacing: 2.5,
                ),
              ),
              const SizedBox(height: 4),
              Text('Dấu mộc mới!', style: displayStyle(26)),
              const SizedBox(height: 18),
              _StampDrop(
                color: route.color,
                child: StampSeal(
                  location: _location,
                  route: route,
                  date: store.stamps[widget.locationId],
                  size: 170,
                  rotation: 0,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '${_location.name} đã được đóng dấu vào hộ chiếu của bạn.',
                textAlign: TextAlign.center,
                style: bodyStyle(14, color: AppColors.inkSoft),
              ),
              const SizedBox(height: 8),
              _Pill(
                '+$stampXp XP',
                color: AppColors.progressInk,
                background: AppColors.progress.withValues(alpha: 0.1),
              ),
              const SizedBox(height: 18),
              PrimaryButton(
                label: 'Tiếp tục',
                onPressed: () => setState(() => _step = _Step.ask),
              ),
            ],
          ),
        );

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
                    const TextSpan(
                      text: hasRemoteReflectionVerifier
                          ? 'Không bắt buộc. Cảm nhận được Gemini thẩm định để nhận thêm XP và huy hiệu '
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
                    maxLength: 600,
                    style: bodyStyle(15, height: 1.5),
                    decoration: InputDecoration(
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
                                : () => setState(() => _photo = null),
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
                  const SizedBox(height: 18),
                  PrimaryButton(
                    label: verifying ? 'AI đang thẩm định…' : 'Gửi cảm nhận',
                    loading: verifying,
                    onPressed: _text.text.trim().isEmpty ? null : _submit,
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

/// Con dấu rơi từ trên xuống (scale 2.8 → 1) rồi trang giấy rung nhẹ khi "cộp".
class _StampDrop extends StatefulWidget {
  const _StampDrop({required this.child, required this.color});

  final Widget child;
  final Color color;

  @override
  State<_StampDrop> createState() => _StampDropState();
}

class _StampDropState extends State<_StampDrop>
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
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        // 0.2–0.5: rơi xuống (elasticOut nhẹ); 0.45–0.75: rung trang; 0.5–0.75: chữ "Cộp!"
        final drop = Curves.easeOutBack.transform(
          ((t - 0.2) / 0.3).clamp(0.0, 1.0),
        );
        final scale = 2.8 - 1.8 * drop;
        final opacity = ((t - 0.2) / 0.12).clamp(0.0, 1.0);
        final shakeT = ((t - 0.45) / 0.3).clamp(0.0, 1.0);
        final shake = sin(shakeT * pi * 5) * 7 * (1 - shakeT);
        final pop = ((t - 0.5) / 0.25).clamp(0.0, 1.0);

        return Transform.translate(
          offset: Offset(shake, 0),
          child: Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.line),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    child: Column(
                      children: [
                        for (var i = 0; i < 6; i++) ...[
                          const Divider(height: 1, color: AppColors.line),
                          const SizedBox(height: 20),
                        ],
                      ],
                    ),
                  ),
                ),
                Opacity(
                  opacity: opacity,
                  child: Transform.rotate(
                    angle: (-30 + 22 * drop) * pi / 180,
                    child: Transform.scale(scale: scale, child: widget.child),
                  ),
                ),
                Positioned(
                  right: 18,
                  top: 12,
                  child: Opacity(
                    opacity: pop,
                    child: Transform.scale(
                      scale: pop < 1
                          ? Curves.elasticOut.transform(pop) * 1.1
                          : 1,
                      child: Text(
                        'Cộp!',
                        style: displayStyle(
                          30,
                          weight: FontWeight.w700,
                          color: widget.color,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
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
