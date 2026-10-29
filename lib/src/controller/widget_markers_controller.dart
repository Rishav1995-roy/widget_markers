import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../cluster/grid_clusterer.dart';
import '../geo/map_projection.dart';
import '../model/marker_animator.dart';
import '../model/widget_marker.dart';
import '../render/marker_bitmap_cache.dart';
import '../render/widget_renderer.dart';
import '../widgets/cluster_badge.dart';
import 'options.dart';

/// Turns a list of [WidgetMarker]s into the `Set<Marker>` that
/// `google_maps_flutter` understands, handling rendering, caching,
/// clustering, selection and animation.
///
/// [WidgetMarkerMap] drives it for you. You only create one yourself to
/// read or change the selection, or to share the bitmap cache.
class WidgetMarkersController extends ChangeNotifier {
  /// Creates a controller. Pass a shared [cache] to reuse bitmaps across maps.
  WidgetMarkersController({
    MarkerBitmapCache? cache,
    this.renderer = const WidgetRenderer(),
  }) : cache = cache ?? MarkerBitmapCache();

  /// Bitmap cache.
  final MarkerBitmapCache cache;

  /// Off-screen renderer.
  final WidgetRenderer renderer;

  /// The camera, updated on every `onCameraMove`. Listen to this (not to the
  /// controller) to follow the camera cheaply.
  final ValueNotifier<CameraPosition> camera =
      ValueNotifier(const CameraPosition(target: LatLng(0, 0)));

  /// Size of the map in logical pixels.
  Size mapSize = Size.zero;

  /// Set when the map is created, so cluster taps can animate the camera.
  GoogleMapController? googleMapController;

  /// Fallback camera mover for when there is no [googleMapController].
  Future<void> Function(CameraPosition)? onCameraRequest;

  /// Called when a marker is tapped.
  ValueChanged<WidgetMarker>? onMarkerTap;

  /// Called when the selection changes.
  ValueChanged<WidgetMarker?>? onSelectionChanged;

  BuildContext? _context;
  double? _pixelRatioOverride;
  List<WidgetMarker> _inputs = const [];
  Map<String, WidgetMarker> _byId = {};
  ClusterOptions? _cluster;
  MarkerAnimation _animation = const MarkerAnimation();
  final MarkerAnimator _animator = MarkerAnimator();
  Set<Marker> _output = const {};
  final Map<String, Size> _sizes = {};
  final Map<String, LatLng> _singles = {};
  String? _selectedId;
  double _clusterZoom = 0;
  int _renderEpoch = 0;
  bool _disposed = false;
  bool _refreshQueued = false;

  /// The markers to pass to `GoogleMap.markers`.
  Set<Marker> get markers => _output;

  /// Whether positions are currently being animated.
  bool get isAnimating => _animator.isAnimating;

  /// Id of the selected marker, if any.
  String? get selectedId => _selectedId;

  /// The selected marker, if any.
  WidgetMarker? get selectedMarker =>
      _selectedId == null ? null : _byId[_selectedId];

  /// Number of icon renders performed so far (cache misses). Useful in tests.
  int get renderCount => cache.misses;

  /// Called by [WidgetMarkerMap]; applies new inputs and rebuilds [markers]
  /// without notifying listeners.
  void configure({
    required BuildContext? context,
    required List<WidgetMarker> markers,
    ClusterOptions? cluster,
    MarkerAnimation animation = const MarkerAnimation(),
    double? pixelRatio,
  }) {
    _context = context;
    _pixelRatioOverride = pixelRatio;
    _cluster = cluster;
    _animation = animation;
    final oldById = _byId;
    final newById = {for (final m in markers) m.id: m};
    for (final m in markers) {
      final old = oldById[m.id];
      if (old != null && old.position != m.position) {
        _animator.moveTo(
          m.id,
          _singles[m.id] ?? old.position,
          m.position,
          animation,
        );
      }
    }
    for (final id in oldById.keys) {
      if (!newById.containsKey(id)) {
        _animator.remove(id);
        _sizes.remove(id);
      }
    }
    _inputs = markers;
    _byId = newById;
    if (_selectedId != null && !newById.containsKey(_selectedId)) {
      _selectedId = null;
      scheduleMicrotask(() => onSelectionChanged?.call(null));
    }
    _clusterZoom = camera.value.zoom;
    _refresh();
  }

  /// Selects the marker [id] (null clears the selection).
  void select(String? id) {
    if (id == _selectedId) return;
    if (id != null && !_byId.containsKey(id)) return;
    _selectedId = id;
    _refresh();
    onSelectionChanged?.call(selectedMarker);
    _notify();
  }

  /// Clears the selection.
  void clearSelection() => select(null);

  /// Moves marker [id] to [position], animated per the map's [MarkerAnimation].
  /// For data-driven apps prefer passing a new [WidgetMarker.position].
  void moveMarker(String id, LatLng position) {
    final m = _byId[id];
    if (m == null) return;
    configure(
      context: _context,
      markers: [
        for (final x in _inputs)
          if (x.id == id)
            WidgetMarker(
              id: x.id,
              position: position,
              child: x.child,
              selectedChild: x.selectedChild,
              cacheKey: x.cacheKey,
              maxSize: x.maxSize,
              size: x.size,
              anchor: x.anchor,
              zIndex: x.zIndex,
              onTap: x.onTap,
              draggable: x.draggable,
              onDragEnd: x.onDragEnd,
              flat: x.flat,
              rotation: x.rotation,
              visible: x.visible,
              clusterable: x.clusterable,
              data: x.data,
              infoWindowBuilder: x.infoWindowBuilder,
            )
          else
            x,
      ],
      cluster: _cluster,
      animation: _animation,
      pixelRatio: _pixelRatioOverride,
    );
    _notify();
  }

  /// Feeds the camera from `GoogleMap.onCameraMove`.
  void updateCamera(CameraPosition position) {
    camera.value = position;
    if (_cluster == null) return;
    final crossed =
        _clusterActiveAt(position.zoom) != _clusterActiveAt(_clusterZoom);
    if (crossed || (position.zoom - _clusterZoom).abs() >= 0.75) {
      _clusterZoom = position.zoom;
      _refresh();
      _notify();
    }
  }

  /// Feeds `GoogleMap.onCameraIdle`: re-clusters for the final zoom.
  void cameraIdle() {
    if (_cluster != null && camera.value.zoom != _clusterZoom) {
      _clusterZoom = camera.value.zoom;
      _refresh();
      _notify();
    }
  }

  /// Moves time forward for animations. Called from the map's ticker.
  void advance(Duration dt) {
    if (!_animator.isAnimating) return;
    _animator.advance(dt);
    _refresh();
    _notify();
  }

  /// Current (possibly animating) position of marker [id].
  LatLng? positionOf(String id) {
    final m = _byId[id];
    return m == null ? null : _animator.current(id, m.position);
  }

  /// Logical size of marker [id]'s icon, once rendered.
  Size? iconSizeOf(String id) => _sizes[id];

  /// Whether marker [id] is currently shown as itself (not inside a cluster).
  bool isShownAsSingle(String id) => _singles.containsKey(id);

  /// Animates the camera so that [cluster]'s members fit on screen.
  Future<void> zoomToCluster(MarkerCluster cluster, EdgeInsets padding) {
    final target = MapProjection.cameraForBounds(
      cluster.bounds,
      mapSize,
      padding: padding,
      maxZoom: (_cluster?.maxZoom ?? 20) + 1,
    );
    final cameraNow = camera.value;
    final next = CameraPosition(
      target: target.target,
      zoom: target.zoom <= cameraNow.zoom + 0.2
          ? cameraNow.zoom + 1.5
          : target.zoom,
      bearing: cameraNow.bearing,
    );
    return moveCamera(next);
  }

  /// Moves the camera using the attached map controller or fallback.
  Future<void> moveCamera(CameraPosition position) async {
    final c = googleMapController;
    if (c != null) {
      await c.animateCamera(CameraUpdate.newCameraPosition(position));
    } else if (onCameraRequest != null) {
      await onCameraRequest!(position);
    }
  }

  // ---------------------------------------------------------------------

  bool _clusterActiveAt(double zoom) =>
      _cluster != null && zoom < _cluster!.maxZoom;

  double get _ratio {
    final o = _pixelRatioOverride;
    if (o != null) return o;
    final c = _context;
    if (c != null && c.mounted) {
      final r = MediaQuery.maybeDevicePixelRatioOf(c);
      if (r != null) return r;
    }
    return WidgetsBinding.instance.platformDispatcher.views.isEmpty
        ? 1
        : WidgetsBinding
            .instance.platformDispatcher.views.first.devicePixelRatio;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _queueRefresh() {
    if (_refreshQueued || _disposed) return;
    _refreshQueued = true;
    scheduleMicrotask(() {
      _refreshQueued = false;
      if (_disposed) return;
      _refresh();
      notifyListeners();
    });
  }

  void _refresh() {
    final ratio = _ratio;
    final cluster = _cluster;
    final out = <Marker>{};
    final singles = <String, LatLng>{};
    final epoch = ++_renderEpoch;
    var missing = false;

    final clustering = cluster != null && _clusterActiveAt(_clusterZoom);
    final fixed = <WidgetMarker>[];
    final points = <ClusterPoint>[];
    for (final m in _inputs) {
      if (!m.visible) continue;
      if (clustering && m.clusterable && m.id != _selectedId) {
        points.add(ClusterPoint(m.id, m.position));
      } else {
        fixed.add(m);
      }
    }
    final singleMarkers = [...fixed];
    if (clustering) {
      final groups = GridClusterer(
        cellSize: cluster.cellSize,
        minClusterSize: cluster.minClusterSize,
      ).cluster(points, _clusterZoom);
      for (final g in groups) {
        if (g.count == 1) {
          singleMarkers.add(_byId[g.memberIds.first]!);
        } else {
          final key = cluster.cacheKey?.call(g) ?? g.count;
          final bitmap = _bitmap(
            ('cluster', key),
            ratio,
            () =>
                (_context != null && cluster.builder != null
                    ? cluster.builder!(_context!, g)
                    : null) ??
                ClusterBadge(count: g.count, style: cluster.badgeStyle),
            const Size(160, 160),
            null,
            epoch,
          );
          if (bitmap == null) {
            missing = true;
            continue;
          }
          out.add(Marker(
            markerId: MarkerId(g.id),
            position: g.position,
            icon: bitmap.descriptor,
            anchor: cluster.anchor,
            // ignore: deprecated_member_use
            zIndex: cluster.zIndex,
            consumeTapEvents: true,
            onTap: () {
              cluster.onTap?.call(g);
              if (cluster.zoomOnTap) zoomToCluster(g, cluster.zoomPadding);
            },
          ));
        }
      }
    }

    for (final m in singleMarkers) {
      final selected = m.id == _selectedId && m.selectedChild != null;
      final bitmap = _bitmap(
        ('marker', m.cacheKey ?? m.id, selected),
        ratio,
        () => selected ? m.selectedChild! : m.child,
        m.maxSize,
        m.size,
        epoch,
      );
      if (bitmap == null) {
        missing = true;
        continue;
      }
      _sizes[m.id] = bitmap.logicalSize;
      final pos = _animator.current(m.id, m.position);
      singles[m.id] = pos;
      out.add(Marker(
        markerId: MarkerId(m.id),
        position: pos,
        icon: bitmap.descriptor,
        anchor: m.anchor,
        // ignore: deprecated_member_use
        zIndex: m.zIndex,
        flat: m.flat,
        rotation: m.rotation,
        draggable: m.draggable,
        consumeTapEvents: true,
        onTap: () {
          m.onTap?.call();
          onMarkerTap?.call(m);
          select(m.id);
        },
        onDragEnd: (p) {
          m.onDragEnd?.call(p);
          configure(
            context: _context,
            markers: [
              for (final x in _inputs)
                if (x.id == m.id) _withPosition(x, p) else x
            ],
            cluster: _cluster,
            animation: MarkerAnimation.none,
            pixelRatio: _pixelRatioOverride,
          );
        },
      ));
    }

    _singles
      ..clear()
      ..addAll(singles);
    _output = out;
    if (missing) {
      // Some icons are still rendering; they call back when done.
    }
  }

  WidgetMarker _withPosition(WidgetMarker x, LatLng p) => WidgetMarker(
        id: x.id,
        position: p,
        child: x.child,
        selectedChild: x.selectedChild,
        cacheKey: x.cacheKey,
        maxSize: x.maxSize,
        size: x.size,
        anchor: x.anchor,
        zIndex: x.zIndex,
        onTap: x.onTap,
        draggable: x.draggable,
        onDragEnd: x.onDragEnd,
        flat: x.flat,
        rotation: x.rotation,
        visible: x.visible,
        clusterable: x.clusterable,
        data: x.data,
        infoWindowBuilder: x.infoWindowBuilder,
      );

  /// Returns the bitmap if cached, otherwise starts a render and returns null.
  MarkerBitmap? _bitmap(
    Object key,
    double ratio,
    Widget Function() widget,
    Size maxSize,
    Size? fixedSize,
    int epoch,
  ) {
    final hit = cache.peek(key, ratio);
    if (hit != null) {
      cache.hits++;
      return hit;
    }
    final ctx = _context;
    unawaited(cache
        .obtain(key, ratio, () async {
          final r = await renderer.render(
            widget(),
            context: ctx != null && ctx.mounted ? ctx : null,
            pixelRatio: ratio,
            maxSize: maxSize,
            fixedSize: fixedSize,
          );
          return MarkerBitmap.fromRendered(r);
        })
        .then((_) => _queueRefresh())
        .catchError((Object e, StackTrace s) {
          FlutterError.reportError(FlutterErrorDetails(
            exception: e,
            stack: s,
            library: 'widget_markers',
            context: ErrorDescription('while rendering a marker widget'),
          ));
          return null;
        }));
    return null;
  }

  @override
  void dispose() {
    _disposed = true;
    camera.dispose();
    super.dispose();
  }
}
