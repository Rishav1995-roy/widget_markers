import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Synchronous Web-Mercator projection matching how Google Maps lays out the
/// world: at zoom `z` the whole world is `256 * 2^z` logical pixels wide.
///
/// Because it is pure math, an overlay can be repositioned in the same frame
/// as every `onCameraMove`, instead of awaiting the asynchronous
/// `GoogleMapController.getScreenCoordinate` (which is what makes
/// controller-based info windows lag behind the map).
///
/// Camera tilt is not modelled: with a non-zero tilt, positions are only
/// approximate.
class MapProjection {
  /// Creates a projection for [camera] on a map that is [size] logical pixels.
  const MapProjection({required this.camera, required this.size});

  /// The current camera.
  final CameraPosition camera;

  /// Size of the map widget in logical pixels.
  final Size size;

  /// Width of the world in logical pixels at [zoom].
  static double worldSize(double zoom) => 256.0 * math.pow(2, zoom);

  /// Converts [p] to world pixel coordinates at [zoom] (origin top-left).
  static Offset toWorld(LatLng p, double zoom) {
    final w = worldSize(zoom);
    final lat = p.latitude.clamp(-85.05112878, 85.05112878);
    final sinLat = math.sin(lat * math.pi / 180);
    final x = (p.longitude + 180) / 360 * w;
    final y = (0.5 - math.log((1 + sinLat) / (1 - sinLat)) / (4 * math.pi)) * w;
    return Offset(x, y);
  }

  /// Converts world pixel coordinates at [zoom] back to a [LatLng].
  static LatLng fromWorld(Offset o, double zoom) {
    final w = worldSize(zoom);
    final lng = o.dx / w * 360 - 180;
    final n = math.pi - 2 * math.pi * o.dy / w;
    final lat = 180 / math.pi * math.atan(0.5 * (math.exp(n) - math.exp(-n)));
    return LatLng(lat, lng);
  }

  /// Screen position (logical pixels, origin top-left of the map) of [p].
  Offset toScreen(LatLng p) {
    final w = worldSize(camera.zoom);
    final c = toWorld(camera.target, camera.zoom);
    final t = toWorld(p, camera.zoom);
    var dx = t.dx - c.dx;
    final dy = t.dy - c.dy;
    // Take the short way around the antimeridian.
    if (dx > w / 2) dx -= w;
    if (dx < -w / 2) dx += w;
    final b = camera.bearing * math.pi / 180;
    final cb = math.cos(b), sb = math.sin(b);
    return Offset(
      size.width / 2 + dx * cb + dy * sb,
      size.height / 2 - dx * sb + dy * cb,
    );
  }

  /// Inverse of [toScreen].
  LatLng toLatLng(Offset screen) {
    final b = camera.bearing * math.pi / 180;
    final cb = math.cos(b), sb = math.sin(b);
    final sx = screen.dx - size.width / 2;
    final sy = screen.dy - size.height / 2;
    final dx = sx * cb - sy * sb;
    final dy = sx * sb + sy * cb;
    final c = toWorld(camera.target, camera.zoom);
    return fromWorld(Offset(c.dx + dx, c.dy + dy), camera.zoom);
  }

  /// Whether [screen] lies inside the map, grown by [margin] on every side.
  bool isVisible(Offset screen, {double margin = 0}) =>
      (Offset.zero & size).inflate(margin).contains(screen);

  /// A camera (bearing 0) that fits [bounds] inside [size] minus [padding].
  static CameraPosition cameraForBounds(
    LatLngBounds bounds,
    Size size, {
    EdgeInsets padding = EdgeInsets.zero,
    double maxZoom = 20,
  }) {
    final availW = math.max(1.0, size.width - padding.horizontal);
    final availH = math.max(1.0, size.height - padding.vertical);
    final sw = toWorld(bounds.southwest, 0);
    var ne = toWorld(bounds.northeast, 0);
    if (ne.dx < sw.dx) ne = Offset(ne.dx + 256, ne.dy);
    final spanX = (ne.dx - sw.dx).abs();
    final spanY = (sw.dy - ne.dy).abs();
    double zoom = maxZoom;
    if (spanX > 0) zoom = math.min(zoom, math.log(availW / spanX) / math.ln2);
    if (spanY > 0) zoom = math.min(zoom, math.log(availH / spanY) / math.ln2);
    zoom = zoom.clamp(0, maxZoom);
    final mid = Offset((sw.dx + ne.dx) / 2, (sw.dy + ne.dy) / 2);
    final k = math.pow(2, zoom).toDouble();
    final centre = fromWorld(
      Offset(mid.dx * k + (padding.left - padding.right) / 2 * -1,
          mid.dy * k + (padding.top - padding.bottom) / 2 * -1),
      zoom,
    );
    return CameraPosition(target: centre, zoom: zoom);
  }
}
