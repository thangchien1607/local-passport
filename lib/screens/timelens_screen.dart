import 'package:flutter/material.dart';

import '../data/routes.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/passport_cover.dart';
import '../widgets/scene_art.dart';
import '../widgets/time_lens.dart';

/// 4 di tích tiêu biểu trong đề cương, có TimeLens xem trước không cần quét QR.
const timeLensFeaturedIds = [
  'dien-hai',
  'cham-museum',
  'cau-rong',
  'ngu-hanh-son',
];

// Tên ngắn cho dải ảnh thu nhỏ để màn hình 360px vẫn đủ chỗ.
const _shortNames = {
  'dien-hai': 'Điện Hải',
  'cham-museum': 'Bảo tàng Chăm',
  'cau-rong': 'Cầu Rồng',
  'ngu-hanh-son': 'Ngũ Hành Sơn',
};

/// Lăng kính thời gian cho 4 di tích tiêu biểu.
/// - App đầy đủ: mở từ màn Khám phá để xem trước, kèm nút sang trang di tích.
/// - [standalone]: trang duy nhất của bản demo public (lib/main_timelens.dart).
class TimeLensScreen extends StatefulWidget {
  const TimeLensScreen({
    super.key,
    this.standalone = false,
    this.onOpenLocation,
  });

  final bool standalone;

  /// Mở trang di tích (quét QR, checklist…); null thì ẩn nút.
  final ValueChanged<String>? onOpenLocation;

  @override
  State<TimeLensScreen> createState() => _TimeLensScreenState();
}

class _TimeLensScreenState extends State<TimeLensScreen> {
  String _selectedId = timeLensFeaturedIds.first;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Nạp sẵn ảnh của 4 di tích để đổi điểm không bị nháy trắng.
    for (final id in timeLensFeaturedIds) {
      final lens = locationById[id]!.timeLens;
      for (final path in [lens.pastImageUrl, lens.presentImageUrl]) {
        if (path != null && path.startsWith('assets/')) {
          precacheImage(AssetImage(path), context);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = locationById[_selectedId]!;
    final lens = location.timeLens;
    final open = widget.onOpenLocation;
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Header(standalone: widget.standalone),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  // Key theo di tích: đổi điểm thì thanh trượt về giữa và gợi ý lại.
                  child: TimeLens(
                    key: ValueKey(location.id),
                    location: location,
                    onExplored: () => showToast(
                      context,
                      'Bạn vừa nhìn xuyên thời gian: ${lens.pastYear} → ${lens.presentYear}',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final id in timeLensFeaturedIds) ...[
                      if (id != timeLensFeaturedIds.first)
                        const SizedBox(width: 8),
                      Expanded(
                        child: _Thumb(
                          location: locationById[id]!,
                          selected: id == _selectedId,
                          onTap: () => setState(() => _selectedId = id),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _LocationCard(
                    key: ValueKey(location.id),
                    location: location,
                    onOpen: open == null ? null : () => open(location.id),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'LEARN BEYOND LIMITS',
                  textAlign: TextAlign.center,
                  style: bodyStyle(
                    11,
                    weight: FontWeight.w600,
                    color: AppColors.gold,
                    letterSpacing: 3.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.standalone});

  final bool standalone;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return PassportCover(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, canPop ? 12 : 28, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (canPop) ...[
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.card.withValues(alpha: 0.92),
                    foregroundColor: AppColors.ink,
                  ),
                  tooltip: 'Quay lại',
                  icon: const Icon(Icons.chevron_left_rounded, size: 26),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                standalone
                    ? 'LOCAL PASSPORT · BẢN DEMO'
                    : 'LOCAL PASSPORT · XEM TRƯỚC',
                style: bodyStyle(
                  11,
                  weight: FontWeight.w600,
                  color: AppColors.goldLight,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Lăng kính thời gian',
                style: displayStyle(
                  32,
                  color: AppColors.goldLight,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Kéo thanh trượt để nhìn xuyên từ hiện tại về quá khứ của di tích Đà Nẵng.',
                style: bodyStyle(
                  14,
                  color: AppColors.paper.withValues(alpha: 0.8),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.location,
    required this.selected,
    required this.onTap,
  });

  final Location location;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: location.name,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.line,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: SceneArt(
                    scene: location.scene,
                    imageUrl: location.timeLens.presentImageUrl,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _shortNames[location.id] ?? location.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: bodyStyle(
                12,
                weight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.primary : AppColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({super.key, required this.location, this.onOpen});

  final Location location;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final route = routeById[location.routeId]!;
    final lens = location.timeLens;
    final story = location.stories.first;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: route.color,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(route.icon, size: 13, color: Colors.white),
                    const SizedBox(width: 5),
                    Text(
                      route.short,
                      style: bodyStyle(
                        12,
                        weight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '${lens.pastYear} → ${lens.presentYear}',
                style: bodyStyle(
                  13,
                  weight: FontWeight.w600,
                  color: AppColors.gold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(location.name, style: displayStyle(22)),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.place_outlined,
                size: 14,
                color: AppColors.inkSoft,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  location.address,
                  style: bodyStyle(13, color: AppColors.inkSoft),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: AppColors.line),
          ),
          Text(story.title, style: displayStyle(18)),
          const SizedBox(height: 6),
          Text(story.body, style: bodyStyle(15, height: 1.55)),
          if (onOpen != null) ...[
            const SizedBox(height: 16),
            SecondaryButton(
              label: 'Xem di tích & check-in',
              icon: Icons.qr_code_scanner_rounded,
              color: AppColors.primary,
              onPressed: onOpen,
            ),
          ],
        ],
      ),
    );
  }
}
