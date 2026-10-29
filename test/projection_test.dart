import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:widget_markers/widget_markers.dart';

void main() {
  const size = Size(400, 800);

  test('the camera target is the centre of the map', () {
    const cam = CameraPosition(target: LatLng(12.97, 77.59), zoom: 12);
    final p = const MapProjection(camera: cam, size: size).toScreen(cam.target);
    expect(p.dx, closeTo(200, 1e-6));
    expect(p.dy, closeTo(400, 1e-6));
  });

  test('world is 256 logical px at zoom 0 and doubles each zoom level', () {
    expect(MapProjection.worldSize(0), 256);
    expect(MapProjection.worldSize(3), 2048);
    const cam = CameraPosition(target: LatLng(0, 0), zoom: 0);
    final p = const MapProjection(camera: cam, size: Size(256, 256))
        .toScreen(const LatLng(0, 90));
    expect(p.dx, closeTo(128 + 64, 1e-6)); // a quarter of the world east
  });

  test('moving east one pixel-width shifts x by that many pixels at any zoom',
      () {
    for (final z in [3.0, 10.5, 17.0]) {
      final cam = CameraPosition(target: const LatLng(40, -74), zoom: z);
      final proj = MapProjection(camera: cam, size: size);
      final a = proj.toScreen(const LatLng(40, -74));
      final b = proj.toScreen(const LatLng(40, -73.999));
      final expected = 0.001 / 360 * MapProjection.worldSize(z);
      expect(b.dx - a.dx, closeTo(expected, 1e-6));
      expect(b.dy, closeTo(a.dy, 1e-6));
    }
  });

  test('round trip toScreen -> toLatLng, with bearing and zoom', () {
    for (final bearing in [0.0, 37.0, 90.0, 215.0]) {
      final cam = CameraPosition(
          target: const LatLng(51.5, -0.12), zoom: 13.3, bearing: bearing);
      final proj = MapProjection(camera: cam, size: size);
      const p = LatLng(51.51, -0.1);
      final back = proj.toLatLng(proj.toScreen(p));
      expect(back.latitude, closeTo(p.latitude, 1e-9));
      expect(back.longitude, closeTo(p.longitude, 1e-9));
    }
  });

  test('rotation: with bearing 90 (facing east) east is up, north is left', () {
    const target = LatLng(0, 0);
    final proj = const MapProjection(
        camera: CameraPosition(target: target, zoom: 10, bearing: 90),
        size: size);
    final east = proj.toScreen(const LatLng(0, 0.01));
    final north = proj.toScreen(const LatLng(0.01, 0));
    expect(east.dx, closeTo(200, 1e-6));
    expect(east.dy, lessThan(400));
    expect(north.dy, closeTo(400, 1e-6));
    expect(north.dx, lessThan(200));
  });

  test('zooming in keeps the target fixed and spreads other points', () {
    const t = LatLng(10, 10);
    const q = LatLng(10.01, 10.01);
    double dist(double z) {
      final pr =
          MapProjection(camera: CameraPosition(target: t, zoom: z), size: size);
      return (pr.toScreen(q) - pr.toScreen(t)).distance;
    }

    expect(dist(12) / dist(11), closeTo(2, 1e-6));
  });

  test('short way around the antimeridian', () {
    const cam = CameraPosition(target: LatLng(0, 179.9), zoom: 5);
    final p = const MapProjection(camera: cam, size: size)
        .toScreen(const LatLng(0, -179.9));
    expect((p.dx - 200).abs(), lessThan(10));
  });

  test('cameraForBounds fits the bounds inside the padded map', () {
    final bounds = LatLngBounds(
        southwest: const LatLng(12.9, 77.5),
        northeast: const LatLng(13.1, 77.7));
    const pad = EdgeInsets.fromLTRB(20, 60, 20, 10);
    final cam = MapProjection.cameraForBounds(bounds, size, padding: pad);
    final proj = MapProjection(camera: cam, size: size);
    final sw = proj.toScreen(bounds.southwest);
    final ne = proj.toScreen(bounds.northeast);
    expect(sw.dx, greaterThanOrEqualTo(20 - 1e-6));
    expect(ne.dx, lessThanOrEqualTo(400 - 20 + 1e-6));
    expect(ne.dy, greaterThanOrEqualTo(60 - 1e-6));
    expect(sw.dy, lessThanOrEqualTo(800 - 10 + 1e-6));
    // and it is tight on at least one axis
    final tight = math.min(sw.dx - 20, math.min(400 - 20 - ne.dx, ne.dy - 60));
    expect(tight, lessThan(1.0));
  });

  test('isVisible honours the margin', () {
    const proj = MapProjection(
        camera: CameraPosition(target: LatLng(0, 0)), size: Size(100, 100));
    expect(proj.isVisible(const Offset(-10, 50)), isFalse);
    expect(proj.isVisible(const Offset(-10, 50), margin: 20), isTrue);
  });
}
