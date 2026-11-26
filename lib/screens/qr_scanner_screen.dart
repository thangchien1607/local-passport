import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../data/routes.dart';
import '../services/geo.dart';
import '../state/passport_store.dart';
import '../theme.dart';
import '../widgets/location_prompt.dart';

enum ScanResult {
  /// Mã QR đúng và đang ở gần di tích.
  real,

  /// Mã QR đúng, bỏ qua đo vị trí (bật trong tab Hộ chiếu).
  skippedLocation,

  /// Không quét gì cả (nút giả lập).
  demo,
}

enum _Status { idle, camera, verifying, demo, error }

/// Quét QR tại di tích + xác thực GPS. Nút Demo bỏ qua cả hai để ban giám khảo
/// trải nghiệm luồng mở khóa ngay trong phòng thuyết trình.
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key, required this.location, this.presetCode});

  final Location location;

  /// Mã đọc sẵn từ link QR (khi du khách quét bằng camera thường) — bỏ qua bước bật camera.
  final String? presetCode;

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen>
    with SingleTickerProviderStateMixin {
  _Status _status = _Status.idle;
  String _error = '';
  MobileScannerController? _controller;
  bool _handling = false;
  late final AnimationController _line = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    final preset = widget.presetCode;
    if (preset != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleCode(preset));
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _line.dispose();
    super.dispose();
  }

  void _startCamera() {
    _controller?.dispose();
    setState(() {
      _error = '';
      _handling = false;
      _controller = MobileScannerController(
        formats: const [BarcodeFormat.qrCode],
      );
      _status = _Status.camera;
    });
  }

  Future<void> _stopCamera() async {
    final c = _controller;
    _controller = null;
    await c?.dispose();
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _status = _Status.error;
      _error = message;
    });
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .firstOrNull;
    if (raw == null || _handling) return;
    await _handleCode(raw);
  }

  Future<void> _handleCode(String raw) async {
    _handling = true;
    await _stopCamera();

    final qr = parseQr(raw);
    final loc = widget.location;
    if (qr == null) return _fail('Mã QR này không thuộc Local Passport.');
    if (qr.locationId != loc.id || qr.secret != loc.qrCodeSecret) {
      final other = locationById[qr.locationId];
      return _fail(
        other != null
            ? 'Mã này thuộc "${other.name}", không phải điểm bạn đang mở.'
            : 'Mã QR không hợp lệ.',
      );
    }

    if (!mounted) return;
    if (PassportScope.read(context).skipLocationCheck) {
      Navigator.of(context).pop(ScanResult.skippedLocation);
      return;
    }
    setState(() => _status = _Status.verifying);
    try {
      final here = await requestLocation(context);
      if (here == null) {
        return _fail('Cần chia sẻ vị trí để xác nhận bạn đang ở ${loc.name}.');
      }
      final d = distanceMeters(here, loc.coordinates);
      if (d > checkinRadiusM) {
        return _fail(
          'Bạn đang cách ${loc.name} khoảng ${formatDistance(d)}. Hãy đến gần hơn để check-in.\n'
          'Vị trí của bạn: ${here.lat.toStringAsFixed(5)}, ${here.lng.toStringAsFixed(5)}',
        );
      }
      if (mounted) Navigator.of(context).pop(ScanResult.real);
    } catch (e) {
      _fail(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _simulate() async {
    await _stopCamera();
    setState(() {
      _error = '';
      _status = _Status.demo;
    });
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (mounted) Navigator.of(context).pop(ScanResult.demo);
  }

  @override
  Widget build(BuildContext context) {
    final busy = _status == _Status.verifying || _status == _Status.demo;
    final skipLocation = PassportScope.of(context).skipLocationCheck;
    final controller = _controller;

    return Scaffold(
      backgroundColor: AppColors.night,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CHECK-IN THỰC ĐỊA',
                          style: bodyStyle(
                            12,
                            weight: FontWeight.w600,
                            color: AppColors.goldLight,
                            letterSpacing: 2.5,
                          ),
                        ),
                        Text(
                          widget.location.name,
                          style: displayStyle(22, color: AppColors.paper),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white12,
                      minimumSize: const Size(44, 44),
                    ),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.paper,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 300),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black38,
                                border: Border.all(color: Colors.white24),
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (_status == _Status.camera &&
                                      controller != null)
                                    MobileScanner(
                                      controller: controller,
                                      onDetect: _onDetect,
                                      errorBuilder: (context, error) {
                                        WidgetsBinding.instance
                                            .addPostFrameCallback(
                                              (_) => _fail(
                                                'Không mở được camera. Hãy cho phép quyền camera (web cần HTTPS hoặc localhost).',
                                              ),
                                            );
                                        return const SizedBox.shrink();
                                      },
                                    )
                                  else
                                    Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(24),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: busy
                                              ? [
                                                  const SizedBox.square(
                                                    dimension: 36,
                                                    child:
                                                        CircularProgressIndicator(
                                                          color: AppColors
                                                              .goldLight,
                                                          strokeWidth: 3,
                                                        ),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Text(
                                                    _status == _Status.demo
                                                        ? 'Đang giả lập quét mã…'
                                                        : 'Đang xác thực vị trí GPS…',
                                                    style: bodyStyle(
                                                      14,
                                                      color: AppColors.paper
                                                          .withValues(
                                                            alpha: 0.8,
                                                          ),
                                                    ),
                                                  ),
                                                ]
                                              : [
                                                  const Icon(
                                                    Icons
                                                        .qr_code_scanner_rounded,
                                                    size: 56,
                                                    color: AppColors.goldLight,
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Text(
                                                    'Hướng camera vào mã QR gắn tại cổng di tích.',
                                                    textAlign: TextAlign.center,
                                                    style: bodyStyle(
                                                      14,
                                                      color: AppColors.paper
                                                          .withValues(
                                                            alpha: 0.8,
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                        ),
                                      ),
                                    ),
                                  const IgnorePointer(
                                    child: CustomPaint(
                                      painter: _CornersPainter(),
                                    ),
                                  ),
                                  if (_status == _Status.camera ||
                                      _status == _Status.demo)
                                    IgnorePointer(
                                      child: AnimatedBuilder(
                                        animation: _line,
                                        builder: (context, _) => Align(
                                          alignment: Alignment(
                                            0,
                                            -0.76 + 1.52 * _line.value,
                                          ),
                                          child: Container(
                                            height: 2,
                                            margin: const EdgeInsets.symmetric(
                                              horizontal: 24,
                                            ),
                                            decoration: const BoxDecoration(
                                              color: AppColors.goldLight,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: AppColors.goldLight,
                                                  blurRadius: 12,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_error.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Container(
                          constraints: const BoxConstraints(maxWidth: 300),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              _error,
                              textAlign: TextAlign.center,
                              style: bodyStyle(
                                14,
                                color: const Color(0xFFFECACA),
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            skipLocation
                                ? Icons.location_off_outlined
                                : Icons.place_outlined,
                            size: 14,
                            color: skipLocation
                                ? AppColors.goldLight
                                : AppColors.paper.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              skipLocation
                                  ? 'Đang bỏ qua kiểm tra vị trí (tắt ở tab Hộ chiếu)'
                                  : 'Cần ở trong bán kính ${checkinRadiusM.round()} m quanh di tích',
                              textAlign: TextAlign.center,
                              style: bodyStyle(
                                12,
                                color: skipLocation
                                    ? AppColors.goldLight
                                    : AppColors.paper.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  if (_status != _Status.camera) ...[
                    // Đến từ link QR: mã đã có sẵn, "thử lại" nghĩa là xác thực vị trí lại.
                    if (widget.presetCode != null && _status == _Status.error)
                      PrimaryButton(
                        label: 'Thử xác thực vị trí lại',
                        icon: Icons.my_location_rounded,
                        background: AppColors.goldLight,
                        foreground: AppColors.ink,
                        onPressed: () => _handleCode(widget.presetCode!),
                      )
                    else
                      PrimaryButton(
                        label: _status == _Status.error
                            ? 'Thử quét lại'
                            : 'Bật camera quét QR',
                        icon: Icons.photo_camera_outlined,
                        background: AppColors.goldLight,
                        foreground: AppColors.ink,
                        onPressed: busy ? null : _startCamera,
                      ),
                    const SizedBox(height: 12),
                  ],
                  // Chỉ hiện khi bật "Chế độ trình diễn" ở tab Hộ chiếu.
                  if (PassportScope.of(context).demoQrEnabled)
                    SecondaryButton(
                      label: 'Giả lập quét QR (Demo)',
                      icon: Icons.auto_awesome,
                      color: AppColors.paper,
                      onPressed: busy ? null : _simulate,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CornersPainter extends CustomPainter {
  const _CornersPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.goldLight
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const m = 14.0, l = 30.0;
    final w = size.width, h = size.height;
    for (final (o, dx, dy) in [
      (const Offset(m, m), 1.0, 1.0),
      (Offset(w - m, m), -1.0, 1.0),
      (Offset(m, h - m), 1.0, -1.0),
      (Offset(w - m, h - m), -1.0, -1.0),
    ]) {
      canvas.drawLine(o, o + Offset(l * dx, 0), p);
      canvas.drawLine(o, o + Offset(0, l * dy), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
