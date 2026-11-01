import 'package:flutter/material.dart';

import '../data/routes.dart';
import '../state/passport_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/passport_cover.dart';
import '../widgets/stamp_seal.dart';

class PassportScreen extends StatelessWidget {
  const PassportScreen({super.key, required this.onOpenLocation});

  final ValueChanged<String> onOpenLocation;

  Future<void> _confirmReset(BuildContext context) async {
    final store = PassportScope.read(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Làm lại từ đầu?', style: displayStyle(22)),
        content: Text(
          'Xóa toàn bộ tiến độ, dấu mộc và cảm nhận để demo lại.',
          style: bodyStyle(14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok == true) store.reset();
  }

  @override
  Widget build(BuildContext context) {
    final store = PassportScope.of(context);
    final user = store.user!;
    final rank = rankForXp(store.xp);
    final next = rank.next;
    final toNext = next == null
        ? 100
        : ((store.xp - rank.current.minXp) /
                  (next.minXp - rank.current.minXp) *
                  100)
              .round();
    final words = user.name.split(' ').where((w) => w.isNotEmpty).toList();
    final initials = words
        .skip(words.length > 2 ? words.length - 2 : 0)
        .map((w) => w[0])
        .join()
        .toUpperCase();
    final d = user.joinedAt;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      children: [
        Text('Hộ chiếu số', style: displayStyle(30)),
        const SizedBox(height: 16),

        // Trang thông tin chủ hộ chiếu
        PassportCover(
          radius: 24,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'LOCAL PASSPORT',
                      style: bodyStyle(
                        11,
                        weight: FontWeight.w600,
                        color: AppColors.goldLight,
                        letterSpacing: 2.5,
                      ),
                    ),
                    Text(
                      'ĐÀ NẴNG · VN',
                      style: bodyStyle(
                        11,
                        weight: FontWeight.w600,
                        color: AppColors.goldLight,
                        letterSpacing: 2.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.goldLight.withValues(alpha: 0.6),
                          width: 2,
                        ),
                      ),
                      child: Text(
                        initials,
                        style: displayStyle(26, color: AppColors.goldLight),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Field('HỌ TÊN', user.name, big: true),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _Field('SỐ HỘ CHIẾU', user.passportNo),
                              ),
                              Expanded(
                                child: _Field(
                                  'CẤP NGÀY',
                                  '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            rank.current.title,
                            style: displayStyle(20, color: AppColors.goldLight),
                          ),
                          Text(
                            '${store.xp} XP',
                            style: bodyStyle(
                              14,
                              weight: FontWeight.w600,
                              color: AppColors.paper,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      AppProgressBar(
                        value: toNext,
                        color: AppColors.goldLight,
                        label: 'Tiến độ lên hạng',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        next == null
                            ? 'Bạn đã đạt danh hiệu cao nhất!'
                            : 'Còn ${next.minXp - store.xp} XP để lên ${next.title}',
                        style: bodyStyle(
                          12,
                          color: AppColors.paper.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Stat('${store.totalStamps}/${store.totalLocations}', 'Dấu mộc'),
              const SizedBox(width: 12),
              _Stat(
                '${publishedRoutes.where((r) => store.routeProgress(r.id).percent == 100).length}',
                'Tuyến xong',
              ),
              const SizedBox(width: 12),
              _Stat('${store.reflections.length}', 'Cảm nhận'),
            ],
          ),
        ),

        // Các trang đóng dấu theo tuyến
        for (final route in publishedRoutes) ...[
          const SizedBox(height: 24),
          Row(
            children: [
              Icon(route.icon, size: 18, color: route.color),
              const SizedBox(width: 8),
              Expanded(child: Text(route.title, style: displayStyle(18))),
              Text(
                '${store.routeProgress(route.id).stamped}/${store.routeProgress(route.id).total}',
                style: bodyStyle(
                  14,
                  weight: FontWeight.w600,
                  color: route.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.line),
            ),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 8,
              childAspectRatio: 1.08,
              children: [
                for (final (i, loc) in locationsOfRoute(route.id).indexed)
                  _StampSlot(
                    location: loc,
                    route: route,
                    date: store.stamps[loc.id],
                    rotation: i.isOdd ? 7 : -9,
                    onTap: () => onOpenLocation(loc.id),
                  ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: 'Làm lại từ đầu',
                icon: Icons.restart_alt_rounded,
                onPressed: () => _confirmReset(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SecondaryButton(
                label: 'Đăng xuất',
                icon: Icons.logout_rounded,
                onPressed: store.logout,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.value, {this.big = false});

  final String label;
  final String value;
  final bool big;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: bodyStyle(
          10,
          color: AppColors.paper.withValues(alpha: 0.6),
          letterSpacing: 1,
        ),
      ),
      Text(
        value,
        overflow: TextOverflow.ellipsis,
        style: big
            ? displayStyle(18, weight: FontWeight.w500, color: AppColors.paper)
            : bodyStyle(14, color: AppColors.paper),
      ),
    ],
  );
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: cardDecoration(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: bodyStyle(20, weight: FontWeight.w700)),
          Text(
            label,
            textAlign: TextAlign.center,
            style: bodyStyle(12, color: AppColors.inkSoft),
          ),
        ],
      ),
    ),
  );
}

class _StampSlot extends StatelessWidget {
  const _StampSlot({
    required this.location,
    required this.route,
    required this.date,
    required this.rotation,
    required this.onTap,
  });

  final Location location;
  final RouteInfo route;
  final DateTime? date;
  final double rotation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stamped = date != null;
    return Semantics(
      button: true,
      label: '${location.name}${stamped ? ' — đã đóng mộc' : ' — chưa có dấu'}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: stamped
                    ? StampSeal(
                        location: location,
                        route: route,
                        date: date,
                        size: 104,
                        rotation: rotation,
                      )
                    : Container(
                        width: 104,
                        height: 104,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.line, width: 2),
                        ),
                        child: Icon(
                          Icons.lock_outline,
                          color: AppColors.inkSoft.withValues(alpha: 0.6),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              location.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: bodyStyle(
                12,
                weight: FontWeight.w500,
                color: stamped ? AppColors.ink : AppColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
