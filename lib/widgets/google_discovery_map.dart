import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;

import '../data/routes.dart';
import '../theme.dart';

// Đà Nẵng, đủ rộng để thấy từ Hòa Khánh tới Non Nước.
const _initialCamera = gm.CameraPosition(
  target: gm.LatLng(16.047, 108.206),
  zoom: 11.5,
);

/// Bản đồ Google Maps thật (khi có API key). Cùng tham số với DiscoveryMap
/// để map_screen đổi qua lại được.
class GoogleDiscoveryMap extends StatefulWidget {
  const GoogleDiscoveryMap({
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
  State<GoogleDiscoveryMap> createState() => _GoogleDiscoveryMapState();
}

class _GoogleDiscoveryMapState extends State<GoogleDiscoveryMap> {
  gm.GoogleMapController? _controller;

  @override
  void didUpdateWidget(covariant GoogleDiscoveryMap old) {
    super.didUpdateWidget(old);
    final id = widget.selectedId;
    if (id != null && id != old.selectedId) _focus(id);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _focus(String id) {
    final c = _controller;
    final loc = locationById[id];
    if (c == null || loc == null) return;
    c.animateCamera(gm.CameraUpdate.newLatLng(_toGm(loc.coordinates)));
    c.showMarkerInfoWindow(gm.MarkerId(id));
  }

  Set<gm.Marker> _markers() => {
    for (final loc in locations)
      if (widget.filter == 'all' || widget.filter == loc.routeId)
        gm.Marker(
          markerId: gm.MarkerId(loc.id),
          position: _toGm(loc.coordinates),
          // Ghim tô theo màu tuyến, giống thiết kế Figma.
          icon: gm.BitmapDescriptor.defaultMarkerWithHue(
            HSVColor.fromColor(routeById[loc.routeId]!.color).hue,
          ),
          infoWindow: gm.InfoWindow(
            title: loc.name,
            snippet: widget.isStamped(loc.id)
                ? 'Đã đóng mộc'
                : widget.isUnlocked(loc.id)
                ? 'Đã mở khóa'
                : routeById[loc.routeId]!.short,
          ),
          onTap: () => widget.onSelect(loc.id),
        ),
  };

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
          aspectRatio: 400 / 440,
          child: gm.GoogleMap(
            initialCameraPosition: _initialCamera,
            markers: _markers(),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            mapToolbarEnabled: false,
            // Cho phép kéo bản đồ khi nằm trong danh sách cuộn.
            gestureRecognizers: {
              Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
            },
            onMapCreated: (c) {
              _controller = c;
              final id = widget.selectedId;
              if (id != null) _focus(id);
            },
          ),
        ),
      ),
    );
  }
}

gm.LatLng _toGm(LatLng p) => gm.LatLng(p.lat, p.lng);
