import 'package:flutter/material.dart';

import '../data/notifications.dart';
import '../state/passport_store.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Icon chuông có số thông báo chưa đọc; bấm để mở trung tâm thông báo.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key, required this.onOpenLocation});

  final ValueChanged<String> onOpenLocation;

  @override
  Widget build(BuildContext context) {
    final unread = PassportScope.of(context).unreadCount;
    return IconButton(
      tooltip: unread == 0 ? 'Thông báo' : 'Thông báo, $unread chưa đọc',
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => NotificationsScreen(onOpenLocation: onOpenLocation),
        ),
      ),
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 9 ? '9+' : '$unread'),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.notifications_none_rounded, size: 26),
      ),
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key, required this.onOpenLocation});

  final ValueChanged<String> onOpenLocation;

  static IconData _icon(NotificationType t) => switch (t) {
    NotificationType.welcome => Icons.waving_hand_outlined,
    NotificationType.stamp => Icons.verified_outlined,
    NotificationType.reflection => Icons.forum_outlined,
    NotificationType.rank => Icons.emoji_events_outlined,
    NotificationType.account => Icons.person_outline_rounded,
  };

  static String _time(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'Vừa xong';
    if (d.inHours < 1) return '${d.inMinutes} phút trước';
    if (d.inDays < 1) return '${d.inHours} giờ trước';
    if (d.inDays < 7) return '${d.inDays} ngày trước';
    final l = t.toLocal();
    return '${l.day}/${l.month}/${l.year}';
  }

  @override
  Widget build(BuildContext context) {
    final store = PassportScope.of(context);
    final items = store.notifications;
    return Scaffold(
      appBar: AppBar(
        title: Text('Thông báo', style: displayStyle(22)),
        actions: [
          if (store.unreadCount > 0)
            TextButton(
              onPressed: store.markAllNotificationsRead,
              child: const Text('Đọc tất cả'),
            ),
        ],
      ),
      body: items.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: EmptyState(
                icon: Icons.notifications_off_outlined,
                title: 'Chưa có thông báo',
                message:
                    'Nhận dấu mộc, đăng cảm nhận hay lên hạng sẽ có thông báo ở đây.',
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final n = items[i];
                return Dismissible(
                  key: ValueKey(n.id),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) => store.deleteNotification(n.id),
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.delete_outline,
                      color: AppColors.primary,
                    ),
                  ),
                  child: Material(
                    color: n.read
                        ? AppColors.card
                        : AppColors.goldLight.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        store.markNotificationRead(n.id);
                        final id = n.locationId;
                        if (id != null) {
                          Navigator.of(context).pop();
                          onOpenLocation(id);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.paper2,
                              child: Icon(
                                _icon(n.type),
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    n.title,
                                    style: bodyStyle(
                                      14,
                                      weight: n.read
                                          ? FontWeight.w500
                                          : FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    n.body,
                                    style: bodyStyle(
                                      13,
                                      color: AppColors.inkSoft,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _time(n.createdAt),
                                    style: bodyStyle(
                                      11.5,
                                      color: AppColors.inkSoft,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!n.read)
                              Container(
                                margin: const EdgeInsets.only(top: 6),
                                width: 9,
                                height: 9,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
