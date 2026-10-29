import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// A map marker whose icon is a Flutter widget.
///
/// This is a plain, immutable data object: build a new list of them whenever
/// your data changes. Bitmaps are cached by [cacheKey], so a marker is only
/// re-rendered when its key (or its selected state) changes.
@immutable
class WidgetMarker {
  /// Creates a widget marker.
  const WidgetMarker({
    required this.id,
    required this.position,
    required this.child,
    this.selectedChild,
    this.cacheKey,
    this.maxSize = const Size(320, 320),
    this.size,
    this.anchor = const Offset(0.5, 1.0),
    this.zIndex = 0,
    this.onTap,
    this.draggable = false,
    this.onDragEnd,
    this.flat = false,
    this.rotation = 0,
    this.visible = true,
    this.clusterable = true,
    this.data,
    this.infoWindowBuilder,
  });

  /// Unique id within one map.
  final String id;

  /// Where the marker is.
  final LatLng position;

  /// The icon. Any widget; it is laid out off-screen and does not have to be
  /// in the tree.
  final Widget child;

  /// Optional icon used while this marker is selected.
  final Widget? selectedChild;

  /// Key of the rendered bitmap. Defaults to [id]. **Change it whenever the
  /// icon should look different** (for example include a price or a count);
  /// keep it the same to reuse the cached bitmap.
  final Object? cacheKey;

  /// Layout constraint for measuring [child].
  final Size maxSize;

  /// Forces an exact icon size instead of measuring.
  final Size? size;

  /// Point of the icon placed on [position], as a fraction (0..1) of its
  /// width and height. `Offset(0.5, 1.0)` = bottom centre (a pin);
  /// `Offset(0.5, 0.5)` = centre (a badge).
  final Offset anchor;

  /// Stacking order.
  final double zIndex;

  /// Called when the marker is tapped (in addition to selecting it).
  final VoidCallback? onTap;

  /// Whether the user can drag the marker.
  final bool draggable;

  /// Called with the new position when a drag ends.
  final ValueChanged<LatLng>? onDragEnd;

  /// Whether the icon is flat against the map.
  final bool flat;

  /// Icon rotation in degrees clockwise.
  final double rotation;

  /// Whether the marker is shown.
  final bool visible;

  /// Whether the marker may merge into a cluster.
  final bool clusterable;

  /// Your own payload, passed back in callbacks and builders.
  final Object? data;

  /// Builds this marker's info window, overriding the map-wide builder.
  final WidgetBuilder? infoWindowBuilder;
}
