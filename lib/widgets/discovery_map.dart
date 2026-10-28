import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/routes.dart';
import '../services/geo.dart';
import '../theme.dart';
import 'common.dart';

// Bản đồ minh họa Đà Nẵng (không tỉ lệ). Khi có API key, thay bằng
// google_maps_flutter và dùng cùng dữ liệu tọa độ.
const _minLng = 108.1, _maxLng = 108.3, _minLat = 15.95, _maxLat = 16.14;
const _w = 400.0, _h = 440.0;

Offset _project(LatLng p) => Offset(
  (p.lng - _minLng) / (_maxLng - _minLng) * _w,
  (_maxLat - p.lat) / (_maxLat - _minLat) * _h,
);

class DiscoveryMap extends StatelessWidget {
  const DiscoveryMap({
    super.key,
    required this.filter,
    required this.selectedId,
    required this.onSelect,
    required this.isUnlocked,
    required this.isStamped,
  });

  final String filter;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final bool Function(String id) isUnlocked;
  final bool Function(String id) isStamped;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(24),
        ),
        child: AspectRatio(
          aspectRatio: _w / _h,
          child: LayoutBuilder(
            builder: (context, c) {
              final scale = c.maxWidth / _w;
              return Stack(
                children: [
                  Positioned.fill(
                    child: SvgPicture.asset(
                      'assets/map/danang_map.svg',
                      fit: BoxFit.fill,
                      excludeFromSemantics: true,
                    ),
                  ),
                  for (final loc in locations) _hotspotFor(loc, scale),
                  Positioned.fill(child: _MyLocationLayer(scale: scale)),
                  Positioned(
                    left: 10,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.card.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Bản đồ minh họa · không theo tỉ lệ',
                        style: bodyStyle(10, color: AppColors.inkSoft),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _hotspotFor(Location loc, double scale) {
    final p = _project(loc.coordinates) + loc.mapNudge;
    final route = routeById[loc.routeId]!;
    final dimmed = filter != 'all' && filter != loc.routeId;
    final selected = selectedId == loc.id;
    return Positioned(
      left: p.dx * scale - 22,
      top: p.dy * scale - 22,
      child: _Hotspot(
        color: route.color,
        dimmed: dimmed,
        selected: selected,
        stamped: isStamped(loc.id),
        unlocked: isUnlocked(loc.id),
        label: loc.name,
        onTap: () => onSelect(loc.id),
      ),
    );
  }
}

bool _onMap(Offset p) => p.dx >= 0 && p.dx <= _w && p.dy >= 0 && p.dy <= _h;

/// Chấm "Bạn ở đây" theo GPS thật + nút định vị. Mở bản đồ là xin quyền vị trí
/// ngay; từ chối thì không hiện chấm (bấm nút định vị để thử lại).
class _MyLocationLayer extends StatefulWidget {
  const _MyLocationLayer({required this.scale});

  final double scale;

  @override
  State<_MyLocationLayer> createState() => _MyLocationLayerState();
}

class _MyLocationLayerState extends State<_MyLocationLayer> {
  LatLng? _me;
  bool _locating = false;
  StreamSubscription<LatLng>? _sub;

  @override
  void initState() {
    super.initState();
    _autoLocate();
  }

  Future<void> _autoLocate() async {
    try {
      final p = await currentPosition();
      if (!mounted) return;
      setState(() => _me = p);
      _watch();
    } catch (_) {
      // Không cho phép / không lấy được vị trí → không hiện chấm, không làm phiền.
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _watch() {
    _sub?.cancel();
    _sub = watchPosition().listen(
      (p) => setState(() => _me = p),
      onError: (_) {
        _sub?.cancel();
        if (mounted) setState(() => _me = null);
      },
    );
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    try {
      final p = await currentPosition();
      if (!mounted) return;
      setState(() => _me = p);
      _watch();
      // Hiện tọa độ + điểm gần nhất để đối chiếu/hiệu chỉnh tọa độ địa điểm.
      final nearest = locations.reduce(
        (a, b) =>
            distanceMeters(p, a.coordinates) <= distanceMeters(p, b.coordinates)
            ? a
            : b,
      );
      showToast(
        context,
        '${_onMap(_project(p)) ? '' : 'Bạn đang ở ngoài khu vực bản đồ\n'}'
        'Vị trí của bạn: ${p.lat.toStringAsFixed(5)}, ${p.lng.toStringAsFixed(5)}\n'
        'Gần nhất: ${nearest.name} (${formatDistance(distanceMeters(p, nearest.coordinates))})',
        duration: const Duration(seconds: 8),
      );
    } catch (e) {
      if (mounted) {
        showToast(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = _me;
    final p = me == null ? null : _project(me);
    return Stack(
      children: [
        if (p != null && _onMap(p))
          AnimatedPositioned(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOut,
            left: p.dx * widget.scale - 14,
            top: p.dy * widget.scale - 14,
            child: IgnorePointer(
              child: Semantics(
                label: 'Vị trí của bạn',
                child: Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                    ),
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          right: 10,
          bottom: 8,
          child: Material(
            color: AppColors.card,
            shape: const CircleBorder(side: BorderSide(color: AppColors.line)),
            elevation: 1,
            child: IconButton(
              tooltip: 'Vị trí của tôi',
              onPressed: _locating ? null : _locate,
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              icon: _locating
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      me == null
                          ? Icons.location_searching_rounded
                          : Icons.my_location_rounded,
                      size: 20,
                      color: const Color(0xFF2563EB),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Hotspot extends StatefulWidget {
  const _Hotspot({
    required this.color,
    required this.dimmed,
    required this.selected,
    required this.stamped,
    required this.unlocked,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final bool dimmed;
  final bool selected;
  final bool stamped;
  final bool unlocked;
  final String label;
  final VoidCallback onTap;

  @override
  State<_Hotspot> createState() => _HotspotState();
}

class _HotspotState extends State<_Hotspot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Tôn trọng cài đặt giảm chuyển động.
    if (MediaQuery.of(context).disableAnimations) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.selected ? 30.0 : 20.0;
    final showPulse = !widget.dimmed && !widget.stamped;
    return Semantics(
      button: true,
      selected: widget.selected,
      label:
          '${widget.label}${widget.stamped
              ? ' — đã đóng mộc'
              : widget.unlocked
              ? ' — đã mở khóa'
              : ''}',
      child: AnimatedOpacity(
        opacity: widget.dimmed ? 0.25 : 1,
        duration: const Duration(milliseconds: 300),
        child: GestureDetector(
          onTap: widget.dimmed ? null : widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (showPulse)
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, _) {
                      final t = _pulse.value;
                      return Opacity(
                        opacity: (0.55 * (1 - t)).clamp(0, 1),
                        child: Container(
                          width: 24 * (0.6 + 1.6 * t),
                          height: 24 * (0.6 + 1.6 * t),
                          decoration: BoxDecoration(
                            color: widget.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    },
                  ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: widget.stamped
                      ? Icon(
                          Icons.check_rounded,
                          size: widget.selected ? 16 : 12,
                          color: Colors.white,
                        )
                      : (!widget.unlocked && widget.selected
                            ? const Icon(
                                Icons.lock_outline,
                                size: 13,
                                color: Colors.white,
                              )
                            : null),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
