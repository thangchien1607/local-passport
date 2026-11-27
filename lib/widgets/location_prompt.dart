import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../data/routes.dart';
import '../services/geo.dart';
import '../theme.dart';

/// Lần mở bản đồ đã hỏi chưa: hỏi tự động tối đa 1 lần mỗi lần mở app.
bool _askedQuietly = false;

@visibleForTesting
void resetLocationPrompt() => _askedQuietly = false;

/// Lấy vị trí hiện tại. Nếu định vị tắt hoặc quyền bị từ chối, hiện hộp thoại
/// hỏi người dùng có muốn chia sẻ vị trí không, rồi đưa họ tới đúng chỗ để bật.
///
/// Trả về null khi người dùng chọn "Để sau". Lỗi tạm thời (hết giờ...) vẫn ném ra.
///
/// [quiet]: gọi tự động khi mở bản đồ, chỉ hỏi khi định vị tắt và tối đa
/// 1 lần mỗi phiên, để không làm phiền người đã từ chối.
Future<LatLng?> requestLocation(
  BuildContext context, {
  bool quiet = false,
  Future<LatLng> Function() locate = currentPosition,
  Future<bool> Function(LocationIssue issue) openSettings = _openSettings,
  Future<void> Function() waitForReturn = _waitForResume,
  bool isWeb = kIsWeb,
}) async {
  try {
    return await locate();
  } on LocationException catch (e) {
    final issue = e.issue;
    if (issue == null) rethrow;
    if (quiet && (issue != LocationIssue.serviceOff || _askedQuietly)) {
      return null;
    }
    _askedQuietly = true;
    if (!context.mounted) return null;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => ShareLocationDialog(issue: issue, isWeb: isWeb),
    );
    if (ok != true || !context.mounted) return null;

    // Web không mở được Cài đặt máy: người dùng tự bật theo hướng dẫn.
    if (!isWeb && issue != LocationIssue.denied && await openSettings(issue)) {
      await waitForReturn();
    }
    if (!context.mounted) return null;
    try {
      return await locate();
    } on LocationException catch (e) {
      if (e.issue == null) rethrow;
      return null; // Vẫn chưa bật: không hỏi dồn dập thêm.
    }
  }
}

Future<bool> _openSettings(LocationIssue issue) async {
  if (kIsWeb) return false;
  try {
    return issue == LocationIssue.serviceOff
        ? await Geolocator.openLocationSettings()
        : await Geolocator.openAppSettings();
  } catch (_) {
    return false;
  }
}

/// Chờ người dùng bật xong trong Cài đặt và quay lại app.
Future<void> _waitForResume() async {
  final back = Completer<void>();
  final listener = AppLifecycleListener(
    onResume: () {
      if (!back.isCompleted) back.complete();
    },
  );
  try {
    await back.future.timeout(const Duration(minutes: 3), onTimeout: () {});
    // Cho hệ thống kịp cập nhật trạng thái định vị vừa bật.
    await Future<void>.delayed(const Duration(milliseconds: 400));
  } finally {
    listener.dispose();
  }
}

/// Hộp thoại "Chia sẻ vị trí của bạn?". Trả về true nếu người dùng đồng ý.
class ShareLocationDialog extends StatelessWidget {
  const ShareLocationDialog({
    super.key,
    required this.issue,
    this.isWeb = false,
  });

  final LocationIssue issue;

  /// Bản web không mở được Cài đặt máy: hướng dẫn tự bật rồi "Thử lại".
  final bool isWeb;

  @override
  Widget build(BuildContext context) {
    final (String how, String action) = switch (issue) {
      LocationIssue.serviceOff when isWeb => (
        'Định vị (GPS) của điện thoại đang tắt. Kéo thanh thông báo xuống, '
            'bật Vị trí rồi bấm "Thử lại".',
        'Thử lại',
      ),
      // Trình duyệt báo lỗi giống nhau khi người dùng chặn trang hay từ chối
      // bật GPS (Chrome Android), nên hướng dẫn kiểm tra cả hai.
      _ when isWeb => (
        'Hãy kiểm tra 2 điều rồi bấm "Thử lại":\n'
            '• Vị trí (GPS) của điện thoại đang bật.\n'
            '• Trang được phép dùng vị trí: bấm biểu tượng bên trái địa chỉ '
            'trang → Quyền → Vị trí → Cho phép.\n'
            'Nếu đang mở trong Zalo/Messenger, hãy mở bằng Chrome hoặc Safari.',
        'Thử lại',
      ),
      LocationIssue.serviceOff => (
        'Định vị trên máy đang tắt. Bấm "Bật định vị", gạt công tắc '
            'Vị trí sang Bật rồi quay lại app.',
        'Bật định vị',
      ),
      LocationIssue.denied => (
        'App cần bạn cho phép dùng vị trí. Bấm "Cho phép" rồi chọn '
            '"Khi dùng ứng dụng" trong hộp thoại tiếp theo.',
        'Cho phép',
      ),
      LocationIssue.deniedForever => (
        'Quyền vị trí của app đang bị tắt. Bấm "Mở cài đặt", vào Quyền → '
            'Vị trí, chọn "Chỉ cho phép khi dùng ứng dụng" rồi quay lại.',
        'Mở cài đặt',
      ),
    };
    return AlertDialog(
      icon: const Icon(
        Icons.location_on_rounded,
        size: 36,
        color: Color(0xFF2563EB),
      ),
      title: Text(
        'Chia sẻ vị trí của bạn?',
        style: displayStyle(22),
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vị trí giúp bạn thấy mình đang ở đâu trên bản đồ, biết di tích '
            'nào gần nhất và check-in khi đến nơi. Vị trí chỉ dùng trên máy, '
            'không lưu lên máy chủ.',
            style: bodyStyle(14),
          ),
          const SizedBox(height: 12),
          Text(how, style: bodyStyle(14, color: AppColors.inkSoft)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Để sau'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(action),
        ),
      ],
    );
  }
}
