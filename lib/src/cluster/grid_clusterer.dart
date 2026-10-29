import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../geo/map_projection.dart';

/// A point that can take part in clustering.
class ClusterPoint {
  /// Creates a point with a unique [id] at [position].
  const ClusterPoint(this.id, this.position);

  /// Unique id (the marker id).
  final String id;

  /// Geographic position.
  final LatLng position;
}

/// A group of one or more [ClusterPoint]s that are close on screen.
class MarkerCluster {
  /// Creates a cluster.
  const MarkerCluster({
    required this.id,
    required this.position,
    required this.memberIds,
    required this.bounds,
  });

  /// Stable id derived from the members.
  final String id;

  /// Centroid of the members.
  final LatLng position;

  /// Ids of the clustered markers.
  final List<String> memberIds;

  /// Bounding box of the members.
  final LatLngBounds bounds;

  /// Number of members.
  int get count => memberIds.length;
}

/// Simple screen-grid clustering.
///
/// Points are bucketed into square cells of [cellSize] logical pixels at the
/// given zoom, so two markers merge when they would be closer than roughly one
/// cell on screen. It is `O(n)` and deterministic, which keeps it testable
/// without a map.
class GridClusterer {
  /// Creates a clusterer.
  const GridClusterer({this.cellSize = 72, this.minClusterSize = 2})
      : assert(cellSize > 0),
        assert(minClusterSize >= 2);

  /// Cell edge in logical pixels.
  final double cellSize;

  /// Smallest group that becomes a cluster; smaller groups stay single.
  final int minClusterSize;

  /// Groups [points] for [zoom]. Singles are returned as clusters of one.
  List<MarkerCluster> cluster(Iterable<ClusterPoint> points, double zoom) {
    final cells = <(int, int), List<ClusterPoint>>{};
    for (final p in points) {
      final w = MapProjection.toWorld(p.position, zoom);
      cells.putIfAbsent(((w.dx / cellSize).floor(), (w.dy / cellSize).floor()),
          () => []).add(p);
    }
    final out = <MarkerCluster>[];
    for (final group in cells.values) {
      if (group.length >= minClusterSize) {
        out.add(_make(group));
      } else {
        for (final p in group) {
          out.add(_make([p]));
        }
      }
    }
    return out;
  }

  MarkerCluster _make(List<ClusterPoint> g) {
    var lat = 0.0, lng = 0.0;
    var minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;
    for (final p in g) {
      final a = p.position.latitude, o = p.position.longitude;
      lat += a;
      lng += o;
      if (a < minLat) minLat = a;
      if (a > maxLat) maxLat = a;
      if (o < minLng) minLng = o;
      if (o > maxLng) maxLng = o;
    }
    final ids = (g.map((p) => p.id).toList()..sort());
    return MarkerCluster(
      id: g.length == 1 ? ids.first : 'cluster:${ids.first}:${ids.length}',
      position: LatLng(lat / g.length, lng / g.length),
      memberIds: ids,
      bounds: LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      ),
    );
  }
}
