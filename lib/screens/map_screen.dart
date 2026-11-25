import 'package:flutter/material.dart';

import '../data/routes.dart';
import '../services/maps_config.dart';
import '../services/text_search.dart';
import '../state/passport_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/google_discovery_map.dart';
import '../widgets/osm_discovery_map.dart';
import '../widgets/scene_art.dart';
import 'notifications_screen.dart';
import 'timelens_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.onOpenLocation});

  final ValueChanged<String> onOpenLocation;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  String _filter = 'all';
  String _query = '';
  String? _selectedId;

  void _changeFilter(String id) {
    setState(() {
      _filter = id;
      final sel = _selectedId == null ? null : locationById[_selectedId];
      if (sel != null && id != 'all' && sel.routeId != id) _selectedId = null;
    });
  }

  void _openTimeLens() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TimeLensScreen(onOpenLocation: widget.onOpenLocation),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = PassportScope.of(context);
    final visible = publishedLocations
        .where((l) => _filter == 'all' || l.routeId == _filter)
        .toList();
    final selected = _selectedId == null ? null : locationById[_selectedId];
    final searching = _query.trim().isNotEmpty;
    final results = searching
        ? visible.where((l) => locationMatches(l, _query)).toList()
        : const <Location>[];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Xin chào, ${store.user!.name}',
                    style: bodyStyle(13, color: AppColors.inkSoft),
                  ),
                  Text('Khám phá Đà Nẵng', style: displayStyle(28)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: NotificationBell(onOpenLocation: widget.onOpenLocation),
            ),
            Container(
              margin: const EdgeInsets.only(top: 22),
              padding: const EdgeInsets.fromLTRB(9, 7, 12, 7),
              decoration: BoxDecoration(
                color: AppColors.goldLight.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_fire_department_rounded,
                    size: 16,
                    color: AppColors.gold,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${store.xp} XP',
                    style: bodyStyle(
                      13,
                      weight: FontWeight.w700,
                      color: AppColors.gold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SearchField(
          hint: 'Tìm di tích, địa chỉ, câu chuyện…',
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 12),

        // Bộ lọc cảm hứng — xuống dòng thay vì cuộn ngang để thấy đủ mọi tuyến.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterPill(
              label: 'Tất cả',
              selected: _filter == 'all',
              onTap: () => _changeFilter('all'),
            ),
            for (final r in publishedRoutes)
              FilterPill(
                label: r.short,
                icon: r.icon,
                color: r.color,
                selected: _filter == r.id,
                onTap: () => _changeFilter(r.id),
              ),
          ],
        ),
        const SizedBox(height: 16),

        if (searching) ...[
          SectionTitle('Kết quả tìm kiếm (${results.length})'),
          const SizedBox(height: 12),
          if (results.isEmpty)
            EmptyState(
              icon: Icons.travel_explore_rounded,
              title: 'Không tìm thấy địa điểm cho “${_query.trim()}”',
              message: _filter == 'all'
                  ? 'Thử từ khóa khác, ví dụ “thành”, “chăm”, “làng nghề”.'
                  : 'Thử chọn “Tất cả” hoặc đổi từ khóa.',
            )
          else
            for (final loc in results) ...[
              LocationTile(
                location: loc,
                onTap: () => widget.onOpenLocation(loc.id),
              ),
              const SizedBox(height: 12),
            ],
        ] else ...[
          if (useGoogleMaps)
            GoogleDiscoveryMap(
              filter: _filter,
              selectedId: _selectedId,
              onSelect: (id) => setState(() => _selectedId = id),
              isUnlocked: store.isUnlocked,
              isStamped: store.stamps.containsKey,
            )
          else
            OsmDiscoveryMap(
              filter: _filter,
              selectedId: _selectedId,
              onSelect: (id) => setState(() => _selectedId = id),
              isUnlocked: store.isUnlocked,
              isStamped: store.stamps.containsKey,
            ),

          // Thẻ địa điểm đang chọn
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: selected == null
                ? const SizedBox.shrink()
                : Padding(
                    key: ValueKey(selected.id),
                    padding: const EdgeInsets.only(top: 12),
                    child: _SelectedCard(
                      location: selected,
                      onTap: () => widget.onOpenLocation(selected.id),
                    ),
                  ),
          ),

          const SizedBox(height: 16),
          _TimeLensBanner(onTap: _openTimeLens),

          const SizedBox(height: 24),
          const SectionTitle('Tiến độ tuyến'),
          const SizedBox(height: 12),
          for (final r in publishedRoutes.where(
            (r) => _filter == 'all' || r.id == _filter,
          )) ...[
            _RouteCard(
              route: r,
              progress: store.routeProgress(r.id),
              expanded: _filter == r.id,
            ),
            const SizedBox(height: 12),
          ],

          const SizedBox(height: 12),
          SectionTitle('Điểm đến (${visible.length})'),
          const SizedBox(height: 12),
          for (final loc in visible) ...[
            LocationTile(
              location: loc,
              onTap: () => widget.onOpenLocation(loc.id),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }
}

class _SelectedCard extends StatelessWidget {
  const _SelectedCard({required this.location, required this.onTap});

  final Location location;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final route = routeById[location.routeId]!;
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(18),
      elevation: 1,
      shadowColor: const Color(0x22000000),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border(left: BorderSide(color: route.color, width: 4)),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      route.title,
                      style: bodyStyle(
                        12,
                        weight: FontWeight.w600,
                        color: route.color,
                      ),
                    ),
                    Text(
                      location.name,
                      style: displayStyle(18),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 13,
                          color: AppColors.inkSoft,
                        ),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            location.address,
                            style: bodyStyle(12, color: AppColors.inkSoft),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                'Xem',
                style: bodyStyle(
                  14,
                  weight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lối vào Lăng kính thời gian xem trước (cùng màn với bản demo public).
class _TimeLensBanner extends StatelessWidget {
  const _TimeLensBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final preview = locationById[timeLensFeaturedIds.first]!;
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 72,
                  height: 56,
                  child: SceneArt(
                    scene: preview.scene,
                    era: Era.past,
                    imageUrl: preview.timeLens.pastImageUrl,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lăng kính thời gian',
                      style: displayStyle(17, color: AppColors.goldLight),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Xem trước Đà Nẵng xưa & nay ở ${timeLensFeaturedIds.length} di tích',
                      style: bodyStyle(
                        13,
                        color: AppColors.paper.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.goldLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.route,
    required this.progress,
    required this.expanded,
  });

  final RouteInfo route;
  final RouteProgress progress;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: route.color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(route.icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      route.title,
                      style: bodyStyle(15, weight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${progress.stamped}/${progress.total} dấu mộc',
                      style: bodyStyle(12, color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
              Text(
                '${progress.percent}%',
                style: bodyStyle(
                  18,
                  weight: FontWeight.w700,
                  color: route.color,
                ),
              ),
            ],
          ),
          if (expanded) ...[
            const SizedBox(height: 8),
            Text(
              route.description,
              style: bodyStyle(14, color: AppColors.inkSoft, height: 1.45),
            ),
          ],
          const SizedBox(height: 12),
          AppProgressBar(
            value: progress.percent,
            color: route.color,
            label: 'Tiến độ ${route.title}',
          ),
        ],
      ),
    );
  }
}

class LocationTile extends StatelessWidget {
  const LocationTile({super.key, required this.location, required this.onTap});

  final Location location;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final store = PassportScope.of(context);
    final route = routeById[location.routeId]!;
    final pct = store.locationProgress(location.id);
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: route.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          location.name,
                          style: bodyStyle(15, weight: FontWeight.w600),
                        ),
                        Text(
                          location.address,
                          style: bodyStyle(12, color: AppColors.inkSoft),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusChip(
                    unlocked: store.isUnlocked(location.id),
                    stamped: store.stamps.containsKey(location.id),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: AppProgressBar(
                      value: pct,
                      height: 6,
                      label: 'Tiến độ ${location.name}',
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(
                      '$pct%',
                      textAlign: TextAlign.right,
                      style: bodyStyle(
                        12,
                        weight: FontWeight.w600,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
