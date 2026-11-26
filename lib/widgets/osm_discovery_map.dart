import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../data/routes.dart';
import '../services/geo.dart';
import '../theme.dart';
import 'common.dart';
import 'discovery_map.dart';
import 'location_prompt.dart';

/// Khung ban đầu vừa đủ mọi địa điểm, từ Nam Ô tới Non Nước.
final _fit = CameraFit.coordinates(
  coordinates: [for (final l in publishedLocations) _ll(l.coordinates)],
  padding: const EdgeInsets.all(28),
  maxZoom: 14,
);

/// Không cho kéo bản đồ ra quá xa Đà Nẵng.
final _bounds = LatLngBounds(
  const ll.LatLng(15.80, 107.90),
  const ll.LatLng(16.30, 108.45),
);

/// Tâm ban đầu nằm trong [_bounds]. Thiếu nó, flutter_map dùng tâm mặc định ở
/// châu Âu trước khi canh khung, vi phạm ràng buộc khung (lỗi assert/null).
const _center = ll.LatLng(16.047, 108.206);

/// Giữ cùng một đối tượng giữa các lần build để MapOptions không bị coi là đổi.
final _constraint = CameraConstraint.containCenter(bounds: _bounds);

/// Bản đồ thật từ OpenStreetMap: không cần API key, không cần thẻ thanh toán.
/// Cùng tham số với DiscoveryMap để map_screen đổi qua lại được.
class OsmDiscoveryMap extends StatefulWidget {
  const OsmDiscoveryMap({
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
  State<OsmDiscoveryMap> createState() => _OsmDiscoveryMapState();
}

class _OsmDiscoveryMapState extends State<OsmDiscoveryMap> {
  final _map = MapController();
  bool _ready = false;
  LatLng? _me;
  bool _locating = false;
  StreamSubscription<LatLng>? _sub;

  @override
  void initState() {
    super.initState();
    // Đợi khung hình đầu để hộp thoại hỏi vị trí (nếu có) hiện được.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _autoLocate();
    });
  }

  @override
  void didUpdateWidget(covariant OsmDiscoveryMap old) {
    super.didUpdateWidget(old);
    final id = widget.selectedId;
    if (id != null && id != old.selectedId) _focus(id);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _map.dispose();
    super.dispose();
  }

  void _focus(String id) {
    final loc = locationById[id];
    if (!_ready || loc == null) return;
    final zoom = _map.camera.zoom < 14 ? 14.0 : _map.camera.zoom;
    _map.move(_ll(loc.coordinates), zoom);
  }

  Future<void> _autoLocate() async {
    try {
      final p = await requestLocation(context, quiet: true);
      if (!mounted || p == null) return;
      setState(() => _me = p);
      _watch();
    } catch (_) {
      // Không cho phép / không lấy được vị trí: không hiện chấm, không làm phiền.
    }
  }

  void _watch() {
    _sub?.cancel();
    _sub = watchPosition().listen(
      (p) {
        if (mounted) setState(() => _me = p);
      },
      onError: (_) {
        _sub?.cancel();
        if (mounted) setState(() => _me = null);
      },
    );
  }

  /// Đưa bản đồ về vị trí hiện tại và báo điểm gần nhất.
  Future<void> _locate() async {
    setState(() => _locating = true);
    try {
      final p = await requestLocation(context);
      if (!mounted || p == null) return;
      setState(() => _me = p);
      _watch();
      final inCity = _bounds.contains(_ll(p));
      if (inCity) _map.move(_ll(p), 15);
      final nearest = publishedLocations.reduce(
        (a, b) =>
            distanceMeters(p, a.coordinates) <= distanceMeters(p, b.coordinates)
            ? a
            : b,
      );
      showToast(
        context,
        '${inCity ? '' : 'Bạn đang ở ngoài Đà Nẵng\n'}'
        'Gần nhất: ${nearest.name} '
        '(${formatDistance(distanceMeters(p, nearest.coordinates))})',
        duration: const Duration(seconds: 6),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(24),
        ),
        child: AspectRatio(
          aspectRatio: 400 / 440,
          child: Stack(
            children: [
              FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: _center,
                  initialZoom: 12,
                  initialCameraFit: _fit,
                  minZoom: 11,
                  maxZoom: 18,
                  backgroundColor: AppColors.paper2,
                  cameraConstraint: _constraint,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onMapReady: () {
                    _ready = true;
                    final id = widget.selectedId;
                    if (id != null) _focus(id);
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'vn.localpassport.local_passport',
                  ),
                  MarkerLayer(
                    markers: [
                      if (me != null)
                        Marker(
                          point: _ll(me),
                          width: 28,
                          height: 28,
                          child: const IgnorePointer(child: _MeDot()),
                        ),
                      for (final loc in publishedLocations)
                        Marker(
                          point: _ll(loc.coordinates),
                          width: 44,
                          height: 44,
                          child: MapHotspot(
                            color: routeById[loc.routeId]!.color,
                            dimmed:
                                widget.filter != 'all' &&
                                widget.filter != loc.routeId,
                            selected: widget.selectedId == loc.id,
                            stamped: widget.isStamped(loc.id),
                            unlocked: widget.isUnlocked(loc.id),
                            label: loc.name,
                            onTap: () => widget.onSelect(loc.id),
                          ),
                        ),
                    ],
                  ),
                  // OpenStreetMap yêu cầu luôn ghi nguồn trên bản đồ.
                  SimpleAttributionWidget(
                    alignment: Alignment.bottomLeft,
                    backgroundColor: AppColors.card.withValues(alpha: 0.85),
                    source: Text(
                      'OpenStreetMap contributors',
                      style: bodyStyle(10, color: AppColors.inkSoft),
                    ),
                  ),
                ],
              ),
              Positioned(
                right: 10,
                bottom: 8,
                child: Material(
                  color: AppColors.card,
                  shape: const CircleBorder(
                    side: BorderSide(color: AppColors.line),
                  ),
                  elevation: 1,
                  child: IconButton(
                    tooltip: 'Vị trí của tôi',
                    onPressed: _locating ? null : _locate,
                    constraints: const BoxConstraints.tightFor(
                      width: 44,
                      height: 44,
                    ),
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
          ),
        ),
      ),
    );
  }
}

/// Chấm xanh "Bạn ở đây".
class _MeDot extends StatelessWidget {
  const _MeDot();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Vị trí của bạn',
    child: Container(
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
  );
}

ll.LatLng _ll(LatLng p) => ll.LatLng(p.lat, p.lng);
