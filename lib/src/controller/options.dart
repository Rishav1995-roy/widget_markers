import 'package:flutter/widgets.dart';

import '../cluster/grid_clusterer.dart';
import '../widgets/cluster_badge.dart';
import '../widgets/info_bubble.dart';
import '../model/widget_marker.dart';

/// Builds the widget shown for a cluster.
typedef ClusterWidgetBuilder = Widget Function(
    BuildContext context, MarkerCluster cluster);

/// Builds the content of an info window for [marker].
typedef InfoWindowBuilder = Widget Function(
    BuildContext context, WidgetMarker marker);

/// Turns on clustering and configures it.
@immutable
class ClusterOptions {
  /// Creates cluster options.
  const ClusterOptions({
    this.cellSize = 72,
    this.minClusterSize = 2,
    this.maxZoom = 16,
    this.builder,
    this.cacheKey,
    this.anchor = const Offset(0.5, 0.5),
    this.zIndex = 1,
    this.zoomOnTap = true,
    this.zoomPadding = const EdgeInsets.all(72),
    this.badgeStyle = const ClusterBadgeStyle(),
    this.onTap,
  });

  /// Cell edge in logical pixels; larger = more aggressive merging.
  final double cellSize;

  /// Smallest group that becomes a cluster.
  final int minClusterSize;

  /// At and above this zoom no clustering happens.
  final double maxZoom;

  /// Builds the cluster widget. Defaults to a [ClusterBadge] with [badgeStyle].
  final ClusterWidgetBuilder? builder;

  /// Key of the cluster bitmap. Defaults to the member count, so every
  /// cluster of the same size shares one bitmap. Provide your own when your
  /// [builder] depends on more than the count.
  final Object Function(MarkerCluster cluster)? cacheKey;

  /// Anchor of the cluster icon.
  final Offset anchor;

  /// Stacking order of clusters.
  final double zIndex;

  /// Zoom to the cluster's members when it is tapped.
  final bool zoomOnTap;

  /// Padding used when fitting the members after a tap.
  final EdgeInsets zoomPadding;

  /// Style of the default badge.
  final ClusterBadgeStyle badgeStyle;

  /// Called when a cluster is tapped (before the zoom, if enabled).
  final ValueChanged<MarkerCluster>? onTap;
}

/// Configures the info window shown for the selected marker.
@immutable
class InfoWindowOptions {
  /// Creates info window options.
  const InfoWindowOptions({
    this.builder,
    this.bubbleStyle = const InfoBubbleStyle(),
    this.gap = 4,
    this.offset = Offset.zero,
    this.hideWhenOffscreen = true,
    this.dismissOnMapTap = true,
    this.animationDuration = const Duration(milliseconds: 160),
  });

  /// Builds the content. Can be overridden per marker with
  /// [WidgetMarker.infoWindowBuilder].
  final InfoWindowBuilder? builder;

  /// Wraps the content in an [InfoBubble]. Null = show the content as is.
  final InfoBubbleStyle? bubbleStyle;

  /// Space between the top of the marker icon and the bottom of the window.
  final double gap;

  /// Extra shift of the window in logical pixels.
  final Offset offset;

  /// Hide the window while its marker is outside the map.
  final bool hideWhenOffscreen;

  /// Clear the selection (closing the window) when the map is tapped.
  final bool dismissOnMapTap;

  /// Fade/scale-in duration. Zero disables it.
  final Duration animationDuration;
}
