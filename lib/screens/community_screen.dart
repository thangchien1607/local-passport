import 'package:flutter/material.dart';

import '../data/community.dart';
import '../data/routes.dart';
import '../state/passport_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/reflection_card.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final store = PassportScope.of(context);
    final all = [...store.reflections, ...seedReflections]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final list = all
        .where(
          (r) =>
              _filter == 'all' ||
              locationById[r.locationId]?.routeId == _filter,
        )
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      children: [
        Text('Bảng tin cộng đồng', style: displayStyle(30)),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(
              Icons.theater_comedy_outlined,
              size: 16,
              color: AppColors.inkSoft,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Cảm nhận thật, được AI kiểm duyệt, có thể ẩn danh.',
                style: bodyStyle(14, color: AppColors.inkSoft),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              FilterPill(
                label: 'Tất cả',
                selected: _filter == 'all',
                onTap: () => setState(() => _filter = 'all'),
              ),
              for (final r in routes) ...[
                const SizedBox(width: 8),
                FilterPill(
                  label: r.short,
                  selected: _filter == r.id,
                  onTap: () => setState(() => _filter = r.id),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (list.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.line),
            ),
            child: Text(
              'Chưa có cảm nhận nào ở tuyến này.',
              textAlign: TextAlign.center,
              style: bodyStyle(14, color: AppColors.inkSoft),
            ),
          )
        else
          for (final r in list) ...[
            ReflectionCard(reflection: r),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}
