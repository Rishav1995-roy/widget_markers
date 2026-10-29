import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:widget_markers/widget_markers.dart';

/// Moves a [StandInMap] from code (used by the scripted demo and by cluster
/// taps).
class StandInMapController {
  _StandInMapState? _state;

  /// Jumps to [camera].
  void setCamera(CameraPosition camera) => _state?._setCamera(camera);

  /// Animates to [camera].
  Future<void> animateTo(CameraPosition camera,
          {Duration duration = const Duration(milliseconds: 500)}) async =>
      _state?._animateTo(camera, duration);
}

/// A drawn stand-in for `GoogleMap`.
///
/// Platform views (the real map) cannot render in widget tests or run without
/// an API key, so this widget draws a map-like background itself and paints
/// the very same marker bitmaps that `WidgetMarkerMap` would hand to the
/// plugin. It supports pan, pinch-zoom and rotate, and feeds the camera back
/// through the same bindings a real map would.
class StandInMap extends StatefulWidget {
  const StandInMap({
    super.key,
    required this.bindings,
    required this.initialCamera,
    this.controller,
    this.dark = false,
  });

  final WidgetMarkerMapBindings bindings;
  final CameraPosition initialCamera;
  final StandInMapController? controller;
  final bool dark;

  @override
  State<StandInMap> createState() => _StandInMapState();
}

class _StandInMapState extends State<StandInMap>
    with SingleTickerProviderStateMixin {
  late CameraPosition _camera = widget.initialCamera;
  final Map<Uint8List, ui.Image> _images = {};
  final Set<Uint8List> _loading = {};
  late final AnimationController _anim = AnimationController(vsync: this);
  CameraPosition? _from, _to;
  Size _size = Size.zero;
  CameraPosition? _gestureStart;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
    _anim.addListener(_tick);
  }

  @override
  void dispose() {
    _anim.dispose();
    for (final i in _images.values) {
      i.dispose();
    }
    super.dispose();
  }

  void _tick() {
    final f = _from, t = _to;
    if (f == null || t == null) return;
    final e = Curves.easeInOutCubic.transform(_anim.value);
    _setCamera(CameraPosition(
      target: LatLng(
        f.target.latitude + (t.target.latitude - f.target.latitude) * e,
        f.target.longitude + (t.target.longitude - f.target.longitude) * e,
      ),
      zoom: f.zoom + (t.zoom - f.zoom) * e,
      bearing: f.bearing + (t.bearing - f.bearing) * e,
    ));
  }

  void _setCamera(CameraPosition c) {
    setState(() => _camera = c);
    widget.bindings.onCameraMove(c);
  }

  Future<void> _animateTo(CameraPosition c, Duration d) async {
    _from = _camera;
    _to = c;
    _anim.duration = d;
    await _anim.forward(from: 0);
    widget.bindings.onCameraIdle();
  }

  void _decode(Uint8List bytes) {
    if (_loading.contains(bytes) || _images.containsKey(bytes)) return;
    _loading.add(bytes);
    ui.instantiateImageCodec(bytes).then((codec) => codec.getNextFrame()).then(
      (f) {
        if (!mounted) return;
        setState(() => _images[bytes] = f.image);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final markers = widget.bindings.markers.toList()
      // ignore: deprecated_member_use
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));
    for (final m in markers) {
      final icon = m.icon;
      if (icon is BytesMapBitmap) _decode(icon.byteData);
    }
    return LayoutBuilder(builder: (context, c) {
      _size = c.biggest;
      final projection = MapProjection(camera: _camera, size: _size);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: (d) {
          _anim.stop();
          _gestureStart = _camera;
        },
        onScaleUpdate: (d) {
          final s = _gestureStart!;
          final startProj = MapProjection(camera: s, size: _size);
          final zoom = s.zoom + math.log(d.scale) / math.ln2;
          final bearing = s.bearing - d.rotation * 180 / math.pi;
          // Keep the geographic point under the initial focal point under the
          // current focal point.
          final anchor =
              startProj.toLatLng(d.localFocalPoint - d.focalPointDelta);
          final probe = MapProjection(
              camera: CameraPosition(
                  target: s.target, zoom: zoom, bearing: bearing),
              size: _size);
          final shift = probe.toScreen(anchor) - d.localFocalPoint;
          final centre =
              probe.toLatLng(Offset(_size.width / 2, _size.height / 2) + shift);
          _setCamera(CameraPosition(
              target: centre, zoom: zoom.clamp(3, 20), bearing: bearing));
        },
        onScaleEnd: (_) => widget.bindings.onCameraIdle(),
        onTapUp: (d) {
          for (final m in markers.reversed) {
            final icon = m.icon;
            if (icon is! BytesMapBitmap) continue;
            final p = projection.toScreen(m.position);
            final w = icon.width ?? 0, h = icon.height ?? 0;
            final r = Rect.fromLTWH(
                p.dx - m.anchor.dx * w, p.dy - m.anchor.dy * h, w, h);
            if (r.contains(d.localPosition)) {
              m.onTap?.call();
              return;
            }
          }
          widget.bindings.onMapTap(projection.toLatLng(d.localPosition));
        },
        child: CustomPaint(
          size: Size.infinite,
          painter: _MapPainter(
            projection: projection,
            markers: markers,
            images: _images,
            dark: widget.dark,
          ),
        ),
      );
    });
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter({
    required this.projection,
    required this.markers,
    required this.images,
    required this.dark,
  });

  final MapProjection projection;
  final List<Marker> markers;
  final Map<Uint8List, ui.Image> images;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final land = dark ? const Color(0xFF1F2429) : const Color(0xFFF1EEE6);
    final water = dark ? const Color(0xFF16324A) : const Color(0xFFAAD3EA);
    final park = dark ? const Color(0xFF1E3A2B) : const Color(0xFFCDE8C2);
    final road = dark ? const Color(0xFF3A4048) : Colors.white;
    final roadEdge = dark ? const Color(0xFF2C3238) : const Color(0xFFD9D4C7);
    final major = dark ? const Color(0xFF8A6A2E) : const Color(0xFFF7D68A);

    canvas.drawRect(Offset.zero & size, Paint()..color = land);
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    // Everything is defined in lat/lng so it pans, zooms and rotates exactly
    // like real map content.
    Offset s(double lat, double lng) => projection.toScreen(LatLng(lat, lng));
    final z = projection.camera.zoom;

    Path poly(List<List<double>> pts) {
      final p = Path();
      for (var i = 0; i < pts.length; i++) {
        final o = s(pts[i][0], pts[i][1]);
        i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
      }
      return p..close();
    }

    // Lake.
    canvas.drawPath(
        poly([
          [12.955, 77.62],
          [12.962, 77.634],
          [12.955, 77.655],
          [12.94, 77.66],
          [12.93, 77.645],
          [12.936, 77.625],
          [12.946, 77.615],
        ]),
        Paint()..color = water);
    // River-ish band.
    final river = Path();
    final rp = [
      [13.10, 77.52],
      [13.05, 77.56],
      [13.01, 77.57],
      [12.98, 77.55],
      [12.95, 77.53],
      [12.90, 77.55],
      [12.85, 77.58],
    ];
    for (var i = 0; i < rp.length; i++) {
      final o = s(rp[i][0], rp[i][1]);
      i == 0 ? river.moveTo(o.dx, o.dy) : river.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
        river,
        Paint()
          ..color = water
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(3, 0.00045 * MapProjection.worldSize(z) / 3)
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round);
    // Parks.
    for (final c in const [
      [12.9766, 77.5993, 0.006],
      [13.0100, 77.5800, 0.010],
      [12.9200, 77.5900, 0.008],
      [12.9900, 77.7000, 0.007],
    ]) {
      final r = c[2];
      canvas.drawPath(
          poly([
            [c[0] - r, c[1] - r * 1.2],
            [c[0] - r * .6, c[1] + r * 1.3],
            [c[0] + r, c[1] + r],
            [c[0] + r * 1.1, c[1] - r * .8],
          ]),
          Paint()..color = park);
    }

    // Street grid, density follows zoom.
    final step = z >= 14 ? 0.004 : (z >= 12 ? 0.016 : 0.064);
    final c0 = projection.camera.target;
    final span = 0.0004 * math.pow(2, 20 - z).toDouble() * 1.2 + step * 2;
    final roadPaint = Paint()
      ..color = road
      ..style = PaintingStyle.stroke
      ..strokeWidth = z >= 14 ? 3.0 : (z >= 12 ? 1.8 : 1.0);
    final edgePaint = Paint()
      ..color = roadEdge
      ..style = PaintingStyle.stroke
      ..strokeWidth = roadPaint.strokeWidth + 1.2;
    final startLat = (c0.latitude - span) ~/ step * step;
    final startLng = (c0.longitude - span) ~/ step * step;
    final grid = Path();
    for (var lat = startLat; lat < c0.latitude + span; lat += step) {
      final jig = math.sin(lat * 900) * step * 0.12;
      final a = s(lat + jig, c0.longitude - span);
      final b = s(lat - jig, c0.longitude + span);
      grid
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy);
    }
    for (var lng = startLng; lng < c0.longitude + span; lng += step) {
      final jig = math.cos(lng * 800) * step * 0.12;
      final a = s(c0.latitude - span, lng + jig);
      final b = s(c0.latitude + span, lng - jig);
      grid
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy);
    }
    canvas.drawPath(grid, edgePaint);
    canvas.drawPath(grid, roadPaint);

    // Arterial roads.
    final arterial = Path();
    void line(List<List<double>> pts) {
      for (var i = 0; i < pts.length; i++) {
        final o = s(pts[i][0], pts[i][1]);
        i == 0 ? arterial.moveTo(o.dx, o.dy) : arterial.lineTo(o.dx, o.dy);
      }
    }

    line([
      [12.80, 77.45],
      [12.90, 77.55],
      [12.9716, 77.5946],
      [13.04, 77.64],
      [13.12, 77.72]
    ]);
    line([
      [13.12, 77.48],
      [13.04, 77.55],
      [12.9716, 77.5946],
      [12.92, 77.66],
      [12.85, 77.75]
    ]);
    line([
      [12.9352, 77.50],
      [12.9352, 77.6245],
      [12.9855, 77.7066],
      [12.99, 77.80]
    ]);
    canvas.drawPath(
        arterial,
        Paint()
          ..color = roadEdge
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = math.max(3.5, z * 0.9));
    canvas.drawPath(
        arterial,
        Paint()
          ..color = major
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = math.max(2.2, z * 0.9 - 1.6));

    canvas.restore();

    // Marker bitmaps, exactly what the plugin would receive.
    for (final m in markers) {
      final icon = m.icon;
      if (icon is! BytesMapBitmap) continue;
      final img = images[icon.byteData];
      if (img == null || !m.visible) continue;
      final p = projection.toScreen(m.position);
      final w = icon.width ?? img.width.toDouble();
      final h = icon.height ?? img.height.toDouble();
      final dst =
          Rect.fromLTWH(p.dx - m.anchor.dx * w, p.dy - m.anchor.dy * h, w, h);
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        dst,
        Paint()..filterQuality = FilterQuality.medium,
      );
    }
  }

  @override
  bool shouldRepaint(_MapPainter old) => true;
}
