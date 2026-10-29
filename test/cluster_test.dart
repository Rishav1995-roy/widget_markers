import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:widget_markers/widget_markers.dart';

void main() {
  const near = [
    ClusterPoint('a', LatLng(12.9716, 77.5946)),
    ClusterPoint('b', LatLng(12.9717, 77.5947)),
    ClusterPoint('c', LatLng(12.9718, 77.5945)),
  ];
  const far = ClusterPoint('z', LatLng(28.61, 77.20));

  test('close points merge at low zoom, split at high zoom', () {
    const c = GridClusterer(cellSize: 72);
    final low = c.cluster([...near, far], 10);
    expect(low.where((e) => e.count == 3), hasLength(1));
    expect(low.where((e) => e.count == 1), hasLength(1));
    final high = c.cluster([...near, far], 20);
    expect(high.every((e) => e.count == 1), isTrue);
    expect(high, hasLength(4));
  });

  test('centroid, bounds and stable id', () {
    final g = const GridClusterer().cluster(near, 8).single;
    expect(g.position.latitude, closeTo(12.9717, 1e-9));
    expect(g.bounds.southwest.latitude, closeTo(12.9716, 1e-9));
    expect(g.bounds.northeast.longitude, closeTo(77.5947, 1e-9));
    final again = const GridClusterer().cluster(near.reversed, 8).single;
    expect(again.id, g.id);
    expect(g.memberIds, ['a', 'b', 'c']);
  });

  test('minClusterSize keeps small groups as singles', () {
    final r = const GridClusterer(minClusterSize: 4).cluster(near, 8);
    expect(r, hasLength(3));
  });

  test('every point appears exactly once', () {
    final pts = [
      for (var i = 0; i < 500; i++)
        ClusterPoint('p$i', LatLng(12 + (i % 25) * 0.01, 77 + (i ~/ 25) * 0.01))
    ];
    for (final z in [6.0, 10.0, 14.0]) {
      final ids = const GridClusterer()
          .cluster(pts, z)
          .expand((c) => c.memberIds)
          .toList();
      expect(ids.length, 500);
      expect(ids.toSet().length, 500);
    }
  });

  test('cell size controls how aggressive merging is', () {
    final pts = [
      for (var i = 0; i < 100; i++)
        ClusterPoint('p$i', LatLng(10 + i * 0.002, 20))
    ];
    final small = const GridClusterer(cellSize: 30).cluster(pts, 12).length;
    final big = const GridClusterer(cellSize: 200).cluster(pts, 12).length;
    expect(big, lessThan(small));
  });
}
