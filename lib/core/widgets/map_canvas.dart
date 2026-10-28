import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../models/lat_lng.dart';

/// A pin on the map.
class MapMarker {
  const MapMarker({
    required this.position,
    required this.color,
    this.icon = Icons.location_on,
  });

  final LatLng position;
  final Color color;
  final IconData icon;
}

/// A real map (OpenStreetMap tiles) that shows [markers] and an optional
/// route line [path].
///
/// [spanDegrees] says roughly how much of the world is visible at first
/// (smaller is closer). When [center] changes the map moves there, and when
/// [path] first appears the map zooms to show the whole path. [onTap]
/// reports where the user tapped.
class MapCanvas extends StatefulWidget {
  const MapCanvas({
    super.key,
    required this.center,
    this.markers = const <MapMarker>[],
    this.path = const <LatLng>[],
    this.onTap,
    this.height = 220,
    this.spanDegrees = 0.12,
  });

  final LatLng center;
  final List<MapMarker> markers;
  final List<LatLng> path;
  final ValueChanged<LatLng>? onTap;
  final double height;
  final double spanDegrees;

  /// Zoom level that shows about [span] degrees across the map.
  static double zoomForSpan(double span) {
    final double safe = span <= 0.0005 ? 0.0005 : span;
    final double zoom = 13 + math.log(0.12 / safe) / math.ln2;
    return zoom.clamp(3.0, 18.0).toDouble();
  }

  @override
  State<MapCanvas> createState() => _MapCanvasState();
}

class _MapCanvasState extends State<MapCanvas> {
  final MapController _controller = MapController();
  bool _ready = false;

  ll.LatLng _point(LatLng p) => ll.LatLng(p.lat, p.lng);

  /// Centre and zoom that show every point of the path.
  ({ll.LatLng center, double zoom}) _fitPath(List<LatLng> points) {
    double minLat = points.first.lat;
    double maxLat = points.first.lat;
    double minLng = points.first.lng;
    double maxLng = points.first.lng;
    for (final LatLng p in points) {
      minLat = math.min(minLat, p.lat);
      maxLat = math.max(maxLat, p.lat);
      minLng = math.min(minLng, p.lng);
      maxLng = math.max(maxLng, p.lng);
    }
    final double span = math.max(maxLat - minLat, maxLng - minLng) * 1.8;
    return (
      center: ll.LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2),
      zoom: MapCanvas.zoomForSpan(span),
    );
  }

  ({ll.LatLng center, double zoom}) _initialView() {
    if (widget.path.length >= 2) return _fitPath(widget.path);
    return (
      center: _point(widget.center),
      zoom: MapCanvas.zoomForSpan(widget.spanDegrees),
    );
  }

  @override
  void didUpdateWidget(covariant MapCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_ready) return;
    if (oldWidget.center != widget.center) {
      _controller.move(
        _point(widget.center),
        MapCanvas.zoomForSpan(widget.spanDegrees),
      );
    } else if (oldWidget.path.length < 2 && widget.path.length >= 2) {
      final ({ll.LatLng center, double zoom}) view = _fitPath(widget.path);
      _controller.move(view.center, view.zoom);
    }
  }

  void _zoomBy(double delta) {
    if (!_ready) return;
    final MapCamera camera = _controller.camera;
    _controller.move(
      camera.center,
      (camera.zoom + delta).clamp(3.0, 19.0).toDouble(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ({ll.LatLng center, double zoom}) view = _initialView();
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Stack(
          children: <Widget>[
            FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCenter: view.center,
                initialZoom: view.zoom,
                minZoom: 3,
                maxZoom: 19,
                // No rotation and no mouse-wheel zoom, so a map inside a
                // scrolling page does not trap the scroll.
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.drag |
                      InteractiveFlag.pinchZoom |
                      InteractiveFlag.pinchMove |
                      InteractiveFlag.doubleTapZoom,
                ),
                onMapReady: () => _ready = true,
                onTap: widget.onTap == null
                    ? null
                    : (TapPosition tap, ll.LatLng point) =>
                        widget.onTap!(LatLng(point.latitude, point.longitude)),
              ),
              children: <Widget>[
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.fixonway.app',
                ),
                if (widget.path.length >= 2)
                  PolylineLayer(
                    polylines: <Polyline>[
                      Polyline(
                        points: <ll.LatLng>[
                          for (final LatLng p in widget.path) _point(p),
                        ],
                        strokeWidth: 4,
                        color: const Color(0xFF1565C0),
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: <Marker>[
                    for (final MapMarker m in widget.markers)
                      Marker(
                        point: _point(m.position),
                        width: 40,
                        height: 40,
                        alignment: m.icon == Icons.my_location
                            ? Alignment.center
                            : Alignment.topCenter,
                        child: IgnorePointer(
                          child: Icon(m.icon, color: m.color, size: 36),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            Positioned(
              right: 8,
              top: 8,
              child: Column(
                children: <Widget>[
                  _ZoomButton(icon: Icons.add, onTap: () => _zoomBy(1)),
                  const SizedBox(height: 4),
                  _ZoomButton(icon: Icons.remove, onTap: () => _zoomBy(-1)),
                ],
              ),
            ),
            const Positioned(
              left: 6,
              bottom: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xCCFFFFFF),
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  child: Text(
                    '© OpenStreetMap contributors',
                    style: TextStyle(fontSize: 10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 1,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 20),
        ),
      ),
    );
  }
}
