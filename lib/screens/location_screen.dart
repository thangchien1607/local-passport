import 'dart:ui';

import 'package:flutter/material.dart';

import '../data/community.dart';
import '../data/routes.dart';
import '../state/passport_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/reflection_card.dart';
import '../widgets/scene_art.dart';
import '../widgets/stamp_seal.dart';
import '../widgets/time_lens.dart';
import 'qr_scanner_screen.dart';
import 'stamp_ceremony.dart';

class LocationScreen extends StatelessWidget {
  const LocationScreen({
    super.key,
    required this.locationId,
    this.autoCheckinCode,
  });

  final String locationId;

  /// Mã QR đọc từ link (du khách quét bằng camera thường) — tự mở bước check-in.
  final String? autoCheckinCode;

  Future<void> _scan(BuildContext context, {String? presetCode}) async {
    final store = PassportScope.read(context);
    final location = locationById[locationId]!;
    final result = await Navigator.of(context).push<ScanResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            QrScannerScreen(location: location, presetCode: presetCode),
      ),
    );
    if (result == null || !context.mounted) return;
    final stamped = store.unlock(locationId);
    showToast(
      context,
      result == ScanResult.demo
          ? 'Đã mở khóa (chế độ Demo)'
          : 'Check-in thành công tại ${location.name}!',
    );
    if (stamped) await showStampCeremony(context, locationId);
  }

  Future<void> _setTask(BuildContext context, String taskId, bool done) async {
    final stamped = PassportScope.read(
      context,
    ).setTask(locationId, taskId, done);
    if (stamped && context.mounted) {
      await showStampCeremony(context, locationId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = PassportScope.of(context);
    final location = locationById[locationId]!;
    final route = routeById[location.routeId]!;
    final unlocked = store.isUnlocked(locationId);
    final stampedAt = store.stamps[locationId];
    final pct = store.locationProgress(locationId);
    final doneCount =
        location.tasks.where((t) => store.isTaskDone(locationId, t.id)).length +
        (unlocked ? 1 : 0);
    final hasMyReflection = store.reflections.any(
      (r) => r.locationId == locationId,
    );
    final feed = [
      ...store.reflections,
      ...seedReflections,
    ].where((r) => r.locationId == locationId).toList();

    final code = autoCheckinCode;
    return _OnFirstFrame(
      onFirstFrame: code == null || unlocked
          ? null
          : () => _scan(context, presetCode: code),
      child: Scaffold(
        body: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 260,
                  pinned: true,
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  leading: Padding(
                    padding: const EdgeInsets.all(6),
                    child: IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.card.withValues(alpha: 0.92),
                        foregroundColor: AppColors.ink,
                      ),
                      tooltip: 'Quay lại bản đồ',
                      icon: const Icon(Icons.chevron_left_rounded, size: 26),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    collapseMode: CollapseMode.parallax,
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        SceneArt(
                          scene: location.scene,
                          imageUrl: location.timeLens.presentImageUrl,
                          semanticLabel: location.name,
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Color(0xD91C0F08),
                                Color(0x401C0F08),
                                Color(0x001C0F08),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 16,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                    Icon(
                                      route.icon,
                                      size: 13,
                                      color: Colors.white,
                                    ),
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
                              const SizedBox(height: 8),
                              Text(
                                location.name,
                                style: displayStyle(
                                  30,
                                  color: Colors.white,
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.place_outlined,
                                    size: 14,
                                    color: Colors.white70,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      location.address,
                                      style: bodyStyle(
                                        14,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Tiến độ: dính ngay dưới thanh tiêu đề khi cuộn để luôn nhìn thấy.
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _ProgressHeader(
                    extent: 118 * MediaQuery.textScalerOf(context).scale(1),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: cardDecoration(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              StatusChip(
                                unlocked: unlocked,
                                stamped: stampedAt != null,
                              ),
                              const Spacer(),
                              Text(
                                '$doneCount/${location.tasks.length + 1} nhiệm vụ',
                                style: bodyStyle(14, color: AppColors.inkSoft),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: AppProgressBar(
                                  value: pct,
                                  height: 10,
                                  label: 'Tiến độ ${location.name}',
                                ),
                              ),
                              SizedBox(
                                width: 56,
                                child: Text(
                                  '$pct%',
                                  textAlign: TextAlign.right,
                                  style: bodyStyle(
                                    18,
                                    weight: FontWeight.w700,
                                    color: AppColors.progressInk,
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
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, unlocked ? 32 : 110),
                  sliver: SliverList.list(
                    children: [
                      if (!unlocked)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.paper2,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.qr_code_2_rounded,
                                size: 36,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      const TextSpan(text: 'Đến tận nơi và '),
                                      TextSpan(
                                        text: 'quét mã QR',
                                        style: bodyStyle(
                                          14,
                                          weight: FontWeight.w700,
                                        ),
                                      ),
                                      const TextSpan(
                                        text:
                                            ' gắn tại di tích để mở khóa câu chuyện, Lăng kính thời gian và dấu mộc.',
                                      ),
                                    ],
                                  ),
                                  style: bodyStyle(14, height: 1.45),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (!unlocked) const SizedBox(height: 28),

                      const SectionTitle(
                        'Câu chuyện 60 giây',
                        icon: Icons.menu_book_outlined,
                      ),
                      const SizedBox(height: 12),
                      _Stories(
                        key: ValueKey('$locationId-$unlocked'),
                        location: location,
                        unlocked: unlocked,
                        onAllRead: () => _setTask(context, 'story', true),
                      ),
                      const SizedBox(height: 28),

                      const SectionTitle('Lăng kính thời gian'),
                      const SizedBox(height: 4),
                      Text(
                        'Kéo thanh trượt để nhìn xuyên từ hiện tại về quá khứ.',
                        style: bodyStyle(14, color: AppColors.inkSoft),
                      ),
                      const SizedBox(height: 12),
                      if (unlocked)
                        TimeLens(
                          location: location,
                          onExplored: () => _setTask(context, 'timelens', true),
                        )
                      else
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: AspectRatio(
                            aspectRatio: 20 / 13,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ImageFiltered(
                                  imageFilter: ImageFilter.blur(
                                    sigmaX: 4,
                                    sigmaY: 4,
                                  ),
                                  child: SceneArt(
                                    scene: location.scene,
                                    era: Era.past,
                                    imageUrl: location.timeLens.pastImageUrl,
                                  ),
                                ),
                                const _LockedOverlay(
                                  'TimeLens chỉ mở khi bạn có mặt tại di tích',
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 28),

                      const SectionTitle('Checklist khám phá'),
                      const SizedBox(height: 12),
                      Container(
                        decoration: cardDecoration(),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            _CheckRow(
                              title: 'Quét mã QR check-in tại di tích',
                              done: unlocked,
                              enabled: false,
                              trailing: const Icon(
                                Icons.qr_code_scanner_rounded,
                                size: 18,
                                color: AppColors.inkSoft,
                              ),
                            ),
                            for (final t in location.tasks) ...[
                              const Divider(height: 1, color: AppColors.line),
                              _CheckRow(
                                title: t.title,
                                done: store.isTaskDone(locationId, t.id),
                                enabled: unlocked,
                                trailing: t.type == TaskType.manual
                                    ? null
                                    : Text(
                                        'tự động',
                                        style: bodyStyle(
                                          11,
                                          weight: FontWeight.w500,
                                          color: AppColors.inkSoft,
                                        ),
                                      ),
                                onChanged: (v) => _setTask(context, t.id, v),
                              ),
                            ],
                          ],
                        ),
                      ),

                      if (stampedAt != null) ...[
                        const SizedBox(height: 28),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: cardDecoration(),
                          child: Row(
                            children: [
                              StampSeal(
                                location: location,
                                route: route,
                                date: stampedAt,
                                size: 96,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Đã đóng mộc',
                                      style: displayStyle(18),
                                    ),
                                    Text(
                                      _formatDateTime(stampedAt),
                                      style: bodyStyle(
                                        13,
                                        color: AppColors.inkSoft,
                                      ),
                                    ),
                                    if (!hasMyReflection)
                                      TextButton.icon(
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: const Size(0, 44),
                                          foregroundColor: AppColors.primary,
                                        ),
                                        onPressed: () => showStampCeremony(
                                          context,
                                          locationId,
                                          startAtFeedback: true,
                                        ),
                                        icon: const Icon(
                                          Icons.rate_review_outlined,
                                          size: 18,
                                        ),
                                        label: Text(
                                          'Viết cảm nhận',
                                          style: bodyStyle(
                                            14,
                                            weight: FontWeight.w600,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 28),
                      const SectionTitle('Lữ khách nói gì'),
                      const SizedBox(height: 12),
                      if (feed.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.line),
                          ),
                          child: Text(
                            'Chưa có cảm nhận nào. Hãy là người đầu tiên sau khi nhận dấu mộc!',
                            textAlign: TextAlign.center,
                            style: bodyStyle(14, color: AppColors.inkSoft),
                          ),
                        )
                      else
                        for (final r in feed) ...[
                          ReflectionCard(reflection: r, showLocation: false),
                          const SizedBox(height: 12),
                        ],
                    ],
                  ),
                ),
              ],
            ),
            if (!unlocked)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        AppColors.paper,
                        AppColors.paper,
                        Color(0x00FBF6EC),
                      ],
                      stops: [0, 0.6, 1],
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: PrimaryButton(
                      label: 'Quét QR Check-in',
                      icon: Icons.qr_code_scanner_rounded,
                      onPressed: () => _scan(context),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Khung chứa thẻ tiến độ, ghim dưới thanh tiêu đề; đổ bóng khi nội dung cuộn qua.
class _ProgressHeader extends SliverPersistentHeaderDelegate {
  const _ProgressHeader({required this.extent, required this.child});

  final double extent;
  final Widget child;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.paper,
        boxShadow: overlaps
            ? const [
                BoxShadow(
                  color: Color(0x1A2B1810),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Align(alignment: Alignment.topCenter, child: child),
      ),
    );
  }

  @override
  bool shouldRebuild(_ProgressHeader old) =>
      old.extent != extent || old.child != child;
}

/// Gọi [onFirstFrame] đúng một lần sau khung hình đầu tiên.
class _OnFirstFrame extends StatefulWidget {
  const _OnFirstFrame({required this.onFirstFrame, required this.child});

  final VoidCallback? onFirstFrame;
  final Widget child;

  @override
  State<_OnFirstFrame> createState() => _OnFirstFrameState();
}

class _OnFirstFrameState extends State<_OnFirstFrame> {
  @override
  void initState() {
    super.initState();
    final cb = widget.onFirstFrame;
    if (cb != null) WidgetsBinding.instance.addPostFrameCallback((_) => cb());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

String _formatDateTime(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} · ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class _LockedOverlay extends StatelessWidget {
  const _LockedOverlay(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          color: AppColors.paper.withValues(alpha: 0.7),
          padding: const EdgeInsets.all(16),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.ink,
                child: Icon(
                  Icons.lock_outline,
                  color: AppColors.paper,
                  size: 20,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                text,
                textAlign: TextAlign.center,
                style: bodyStyle(14, weight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stories extends StatefulWidget {
  const _Stories({
    super.key,
    required this.location,
    required this.unlocked,
    required this.onAllRead,
  });

  final Location location;
  final bool unlocked;
  final VoidCallback onAllRead;

  @override
  State<_Stories> createState() => _StoriesState();
}

class _StoriesState extends State<_Stories> {
  final _controller = PageController();
  final _seen = <int>{0};
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPage(int i) {
    setState(() => _index = i);
    if (!widget.unlocked) return;
    _seen.add(i);
    if (_seen.length == widget.location.stories.length) widget.onAllRead();
  }

  @override
  Widget build(BuildContext context) {
    final stories = widget.location.stories;
    final total = stories.length;
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _controller,
            itemCount: total,
            onPageChanged: _onPage,
            itemBuilder: (context, i) {
              final s = stories[i];
              final locked = !widget.unlocked && i > 0;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: cardDecoration(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${(i + 1).toString().padLeft(2, '0')} / ${total.toString().padLeft(2, '0')}',
                              style: bodyStyle(
                                12,
                                weight: FontWeight.w600,
                                color: AppColors.gold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(s.title, style: displayStyle(20)),
                            const SizedBox(height: 8),
                            Expanded(
                              child: Text(
                                s.body,
                                style: bodyStyle(15, height: 1.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (locked)
                        const _LockedOverlay('Quét QR tại di tích để đọc tiếp'),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < total; i++)
              Semantics(
                button: true,
                label: 'Đến thẻ ${i + 1}',
                child: GestureDetector(
                  onTap: () => _controller.animateToPage(
                    i,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  ),
                  child: Container(
                    width: 28,
                    height: 24,
                    alignment: Alignment.center,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: i == _index ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _index ? AppColors.primary : AppColors.line,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.title,
    required this.done,
    required this.enabled,
    this.trailing,
    this.onChanged,
  });

  final String title;
  final bool done;
  final bool enabled;
  final Widget? trailing;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final interactive = enabled && onChanged != null;
    return Opacity(
      opacity: enabled || done || onChanged == null ? 1 : 0.55,
      child: Semantics(
        checked: done,
        enabled: interactive,
        child: InkWell(
          onTap: interactive ? () => onChanged!(!done) : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: done ? AppColors.progress : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: done ? AppColors.progress : AppColors.line,
                        width: 2,
                      ),
                    ),
                    child: done
                        ? const Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style:
                          bodyStyle(
                            15,
                            color: done ? AppColors.inkSoft : AppColors.ink,
                          ).copyWith(
                            decoration: done
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
