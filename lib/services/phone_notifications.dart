import 'dart:async';
import 'dart:ui' show Color;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/notifications.dart';

/// Thông báo trên thanh thông báo của điện thoại (chỉ bản app Android):
/// - Mỗi thông báo mới trong chuông (nhận dấu, lên hạng...) hiện thêm lên máy.
/// - Nhận push gửi từ Firebase Console tới chủ đề [topic].
///
/// Bản web và khi chạy test: không làm gì.
class PhoneNotifications {
  PhoneNotifications._();

  /// Chủ đề mọi máy cài app đều nhận: Firebase Console → Messaging →
  /// chiến dịch mới → Mục tiêu "Chủ đề" → `all`.
  static const topic = 'all';

  /// Kênh thông báo trên Android. FCM cũng dùng kênh này (AndroidManifest).
  static const channel = AndroidNotificationChannel(
    'local_passport',
    'Hành trình',
    description: 'Dấu mộc, lên hạng, bài cảm nhận và tin từ Local Passport',
    importance: Importance.high,
  );

  /// Icon nhỏ màu trắng trong `android/app/src/main/res/drawable-*`.
  static const _smallIcon = 'ic_stat_passport';

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Tạo kênh, xin quyền (Android 13+) và đăng ký nhận push.
  static Future<void> init() async {
    if (!supported) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings(_smallIcon),
        ),
      );
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.createNotificationChannel(channel);
      _ready = true;
      await android?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('Không bật được thông báo trên máy: $e');
    }
    unawaited(_initPush());
  }

  static Future<void> _initPush() async {
    if (Firebase.apps.isEmpty) return;
    try {
      // Khi app đang mở, Android không tự hiện push: tự hiện bằng kênh trên.
      FirebaseMessaging.onMessage.listen((message) {
        final n = message.notification;
        if (n == null) return;
        _show(message.messageId.hashCode, n.title, n.body);
      });
      await FirebaseMessaging.instance.subscribeToTopic(topic);
    } catch (e) {
      debugPrint('Không đăng ký được push: $e');
    }
  }

  /// Hiện một thông báo trong chuông lên thanh thông báo của máy.
  static void show(AppNotification n) => _show(n.id.hashCode, n.title, n.body);

  static void _show(int id, String? title, String? body) {
    if (!_ready) return;
    unawaited(
      _plugin
          .show(
            id: id & 0x7fffffff,
            title: title,
            body: body,
            notificationDetails: NotificationDetails(
              android: AndroidNotificationDetails(
                channel.id,
                channel.name,
                channelDescription: channel.description,
                importance: Importance.high,
                priority: Priority.high,
                color: const Color(0xFF7C2D12),
                styleInformation: BigTextStyleInformation(body ?? ''),
              ),
            ),
          )
          .catchError((Object e) => debugPrint('Không hiện được: $e')),
    );
  }
}
