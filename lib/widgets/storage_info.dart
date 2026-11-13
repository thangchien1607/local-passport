import 'package:flutter/material.dart';

import '../services/passport_remote.dart';
import '../state/passport_store.dart';
import '../theme.dart';

/// Cho biết dữ liệu hộ chiếu đang được lưu ở đâu (Cloud Firestore hay chỉ trên máy).
class StorageInfoCard extends StatelessWidget {
  const StorageInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    final store = PassportScope.of(context);
    final remote = store.remote;
    if (remote == null) {
      return _card(
        icon: Icons.phone_android_outlined,
        title: 'Lưu trên thiết bị',
        lines: const ['shared_preferences · khóa local-passport/v1'],
      );
    }
    return ValueListenableBuilder(
      valueListenable: remote.state,
      builder: (context, state, _) {
        final uid = remote.uid ?? '…';
        final (status, color) = switch (state) {
          SyncState.synced => ('Đã đồng bộ', AppColors.progressInk),
          SyncState.syncing => ('Đang đồng bộ…', AppColors.gold),
          SyncState.error => (
            'Lỗi kết nối, đang lưu tạm trên máy',
            AppColors.primary,
          ),
          SyncState.offline => ('Đang kết nối…', AppColors.inkSoft),
        };
        return _card(
          icon: Icons.cloud_done_outlined,
          title: 'Cloud Firestore · local-passport-danang',
          status: status,
          statusColor: color,
          lines: [
            'user_passports/$uid',
            'user_passports/$uid/visits/{locationId}',
            'reflections/{reflectionId}',
          ],
        );
      },
    );
  }

  Widget _card({
    required IconData icon,
    required String title,
    required List<String> lines,
    String? status,
    Color? statusColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.progressInk),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Dữ liệu lưu tại',
                  style: bodyStyle(12, color: AppColors.inkSoft),
                ),
              ),
              if (status != null)
                Text(
                  status,
                  style: bodyStyle(
                    12,
                    weight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(title, style: bodyStyle(14, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          for (final l in lines)
            SelectableText(
              l,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: AppColors.inkSoft,
              ),
            ),
        ],
      ),
    );
  }
}
