import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../controller/options.dart';
import '../controller/widget_markers_controller.dart';
import '../geo/map_projection.dart';
import '../model/marker_animator.dart';
import '../model/widget_marker.dart';
import 'info_bubble.dart';

/// What [WidgetMarkerMap] hands to your map widget. Wire these into
/// `GoogleMap`:
///
/// ```dart
/// GoogleMap(
///   initialCameraPosition: camera,
///   markers: b.markers,
///   onMapCreated: b.onMapCreated,
///   onCameraMove: b.onCameraMove,
///   onCameraIdle: b.onCameraIdle,
///   onTap: b.onMapTap,
/// )
/// ```
class WidgetMarkerMapBindings {
  /// Creates bindings. Normally built by [WidgetMarkerMap].
  const WidgetMarkerMapBindings({
    required this.markers,
    required this.onMapCreated,
    required this.onCameraMove,
    required this.onCameraIdle,
    required this.onMapTap,
  });

  /// Markers to show.
  final Set<Marker> markers;

  /// Give the created controller to the package (needed to zoom on cluster tap).
  final void Function(GoogleMapController controller) onMapCreated;

  /// Feed camera movement (keeps info windows and clusters in sync).
  final void Function(CameraPosition position) onCameraMove;

  /// Feed camera idle (final re-clustering).
  final VoidCallback onCameraIdle;

  /// Feed map taps (dismisses the info window).
  final void Function(LatLng position) onMapTap;
}

/// Builds the map for [WidgetMarkerMap], typically a `GoogleMap`.
typedef WidgetMarkerMapBuilder = Widget Function(
    BuildContext context, WidgetMarkerMapBindings bindings);

/// Wraps a map and gives it widget markers, widget cluster icons and a
/// camera-following widget info window.
///
/// The map itself is created by [mapBuilder], so this works with any
/// `GoogleMap` configuration (styles, padding, gestures...).
class WidgetMarkerMap extends StatefulWidget {
  /// Creates the map wrapper.
  const WidgetMarkerMap({
    super.key,
    required this.initialCameraPosition,
    required this.markers,
    required this.mapBuilder,
    this.controller,
    this.cluster,
    this.infoWindow,
    this.animation = const MarkerAnimation(),
    this.pixelRatio,
    this.onMarkerTap,
    this.onSelectionChanged,
  });

  /// The same camera you give the map; used before the first camera event.
  final CameraPosition initialCameraPosition;

  /// The markers to show.
  final List<WidgetMarker> markers;

  /// Builds the map.
  final WidgetMarkerMapBuilder mapBuilder;

  /// Optional controller to read/change the selection and share a cache.
  final WidgetMarkersController? controller;

  /// Enables clustering when non-null.
  final ClusterOptions? cluster;

  /// Enables the info window when non-null.
  final InfoWindowOptions? infoWindow;

  /// How moving markers animate. [MarkerAnimation.none] disables it.
  final MarkerAnimation animation;

  /// Overrides the device pixel ratio used for rendering icons.
  final double? pixelRatio;

  /// Called when a marker is tapped.
  final ValueChanged<WidgetMarker>? onMarkerTap;

  /// Called when the selected marker changes (null = cleared).
  final ValueChanged<WidgetMarker?>? onSelectionChanged;

  @override
  State<WidgetMarkerMap> createState() => _WidgetMarkerMapState();
}

class _WidgetMarkerMapState extends State<WidgetMarkerMap>
    with SingleTickerProviderStateMixin {
  late WidgetMarkersController _controller;
  bool _owns = false;
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _bindController();
    _controller.camera.value = widget.initialCameraPosition;
    _ticker = createTicker((elapsed) {
      final dt = elapsed - _last;
      _last = elapsed;
      _controller.advance(dt);
      if (!_controller.isAnimating) _ticker.stop();
    });
  }

  void _bindController() {
    _owns = widget.controller == null;
    _controller = widget.controller ?? WidgetMarkersController();
    _controller.addListener(_onController);
  }

  void _unbindController() {
    _controller.removeListener(_onController);
    if (_owns) _controller.dispose();
  }

  void _configure() {
    if (widget.onMarkerTap != null) {
      _controller.onMarkerTap = widget.onMarkerTap;
    }
    if (widget.onSelectionChanged != null) {
      _controller.onSelectionChanged = widget.onSelectionChanged;
    }
    _controller.configure(
      context: context,
      markers: widget.markers,
      cluster: widget.cluster,
      animation: widget.animation,
      pixelRatio: widget.pixelRatio,
    );
    _syncTicker();
  }

  void _syncTicker() {
    if (_controller.isAnimating && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _onController() {
    if (!mounted) return;
    _syncTicker();
    // Listeners can fire during a build (selection from a tap is not, but
    // async renders are), so always defer to a safe moment.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _configure();
  }

  @override
  void didUpdateWidget(WidgetMarkerMap old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      _unbindController();
      _bindController();
      _controller.camera.value = widget.initialCameraPosition;
    }
    _configure();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _unbindController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final bindings = WidgetMarkerMapBindings(
      markers: c.markers,
      onMapCreated: (g) => c.googleMapController = g,
      onCameraMove: c.updateCamera,
      onCameraIdle: c.cameraIdle,
      onMapTap: (_) {
        if (widget.infoWindow?.dismissOnMapTap ?? false) c.clearSelection();
      },
    );
    return LayoutBuilder(builder: (context, constraints) {
      c.mapSize = constraints.biggest;
      return Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(child: widget.mapBuilder(context, bindings)),
          if (widget.infoWindow != null)
            Positioned.fill(
              child: InfoWindowOverlay(
                controller: c,
                options: widget.infoWindow!,
              ),
            ),
        ],
      );
    });
  }
}

/// The overlay that positions the selected marker's info window.
///
/// Used by [WidgetMarkerMap]; exposed so you can place it yourself.
class InfoWindowOverlay extends StatelessWidget {
  /// Creates the overlay.
  const InfoWindowOverlay({
    super.key,
    required this.controller,
    required this.options,
  });

  /// Source of camera, selection and marker positions.
  final WidgetMarkersController controller;

  /// Look and behaviour.
  final InfoWindowOptions options;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([controller, controller.camera]),
      builder: (context, _) {
        final m = controller.selectedMarker;
        final pos = m == null ? null : controller.positionOf(m.id);
        final icon = m == null ? null : controller.iconSizeOf(m.id);
        if (m == null ||
            pos == null ||
            icon == null ||
            !controller.isShownAsSingle(m.id)) {
          return const SizedBox.shrink();
        }
        final builder = m.infoWindowBuilder != null
            ? (BuildContext c, WidgetMarker _) => m.infoWindowBuilder!(c)
            : options.builder;
        if (builder == null) return const SizedBox.shrink();

        final projection = MapProjection(
          camera: controller.camera.value,
          size: controller.mapSize,
        );
        final p = projection.toScreen(pos);
        if (options.hideWhenOffscreen && !projection.isVisible(p, margin: 48)) {
          return const SizedBox.shrink();
        }
        // Bottom-centre of the window sits just above the icon's top edge.
        final iconCentreX = p.dx + (0.5 - m.anchor.dx) * icon.width;
        final iconTopY = p.dy - m.anchor.dy * icon.height;
        final target =
            Offset(iconCentreX, iconTopY - options.gap) + options.offset;

        Widget content = builder(context, m);
        final style = options.bubbleStyle;
        if (style != null) content = InfoBubble(style: style, child: content);
        if (options.animationDuration > Duration.zero) {
          content = TweenAnimationBuilder<double>(
            key: ValueKey(m.id),
            tween: Tween(begin: 0, end: 1),
            duration: options.animationDuration,
            curve: Curves.easeOutCubic,
            builder: (context, t, child) => Opacity(
              opacity: t,
              child: Transform.scale(
                scale: 0.92 + 0.08 * t,
                alignment: Alignment.bottomCenter,
                child: child,
              ),
            ),
            child: content,
          );
        }
        return CustomSingleChildLayout(
          delegate: InfoWindowLayoutDelegate(target),
          child: content,
        );
      },
    );
  }
}

/// Places a child so its bottom centre is on [target]. Layout is synchronous,
/// so the window never lags a frame behind the map.
class InfoWindowLayoutDelegate extends SingleChildLayoutDelegate {
  /// Creates a delegate.
  const InfoWindowLayoutDelegate(this.target);

  /// Where the child's bottom centre goes.
  final Offset target;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(constraints.biggest);

  @override
  Offset getPositionForChild(Size size, Size childSize) =>
      Offset(target.dx - childSize.width / 2, target.dy - childSize.height);

  @override
  bool shouldRelayout(InfoWindowLayoutDelegate oldDelegate) =>
      oldDelegate.target != target;
}
