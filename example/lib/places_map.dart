import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:widget_markers/widget_markers.dart';

import 'data.dart';
import 'stand_in_map.dart';
import 'widgets.dart';

/// Set `--dart-define=GOOGLE_MAP=true` (and add your API key) to run the
/// example on the real `GoogleMap` instead of the drawn stand-in.
const useGoogleMap = bool.fromEnvironment('GOOGLE_MAP');

/// Everything the customization screen can change.
class MapSettings {
  const MapSettings({
    this.clustering = true,
    this.cellSize = 72,
    this.badgeColor = const Color(0xFF1E88E5),
    this.pinColor = const Color(0xFF0F766E),
    this.bubbleRadius = 12,
    this.bubbleElevation = 6,
    this.gap = 4,
    this.animationMs = 600,
    this.infoWindow = true,
  });

  final bool clustering;
  final double cellSize;
  final Color badgeColor;
  final Color pinColor;
  final double bubbleRadius;
  final double bubbleElevation;
  final double gap;
  final int animationMs;
  final bool infoWindow;

  MapSettings copyWith({
    bool? clustering,
    double? cellSize,
    Color? badgeColor,
    Color? pinColor,
    double? bubbleRadius,
    double? bubbleElevation,
    double? gap,
    int? animationMs,
    bool? infoWindow,
  }) =>
      MapSettings(
        clustering: clustering ?? this.clustering,
        cellSize: cellSize ?? this.cellSize,
        badgeColor: badgeColor ?? this.badgeColor,
        pinColor: pinColor ?? this.pinColor,
        bubbleRadius: bubbleRadius ?? this.bubbleRadius,
        bubbleElevation: bubbleElevation ?? this.bubbleElevation,
        gap: gap ?? this.gap,
        animationMs: animationMs ?? this.animationMs,
        infoWindow: infoWindow ?? this.infoWindow,
      );
}

const bengaluru = CameraPosition(target: LatLng(12.9716, 77.5946), zoom: 11.2);

/// The shared demo scene: places as price-tag widget markers, cluster badges
/// and a widget info window, on the real map or the drawn stand-in.
class PlacesMap extends StatelessWidget {
  const PlacesMap({
    super.key,
    required this.places,
    this.settings = const MapSettings(),
    this.markersController,
    this.standIn,
    this.initialCamera = bengaluru,
    this.dark = false,
    this.onOpen,
  });

  final List<Place> places;
  final MapSettings settings;
  final WidgetMarkersController? markersController;
  final StandInMapController? standIn;
  final CameraPosition initialCamera;
  final bool dark;
  final ValueChanged<Place>? onOpen;

  @override
  Widget build(BuildContext context) {
    final byId = {for (final p in places) p.id: p};
    return WidgetMarkerMap(
      controller: markersController,
      initialCameraPosition: initialCamera,
      animation: MarkerAnimation(
          duration: Duration(milliseconds: settings.animationMs)),
      markers: [
        for (final p in places)
          WidgetMarker(
            id: p.id,
            position: p.position,
            data: p,
            cacheKey: ('price', p.price, settings.pinColor.hashCode),
            child: PricePin(price: p.price, color: settings.pinColor),
            selectedChild: PricePin(price: p.price, selected: true),
          ),
      ],
      cluster: settings.clustering
          ? ClusterOptions(
              cellSize: settings.cellSize,
              badgeStyle: ClusterBadgeStyle(color: settings.badgeColor),
            )
          : null,
      infoWindow: settings.infoWindow
          ? InfoWindowOptions(
              gap: settings.gap,
              bubbleStyle: InfoBubbleStyle(
                borderRadius: BorderRadius.circular(settings.bubbleRadius),
                elevation: settings.bubbleElevation,
              ),
              builder: (context, m) {
                final place = byId[m.id]!;
                return PlaceCard(
                    place: place, onOpen: () => onOpen?.call(place));
              },
            )
          : null,
      mapBuilder: (context, b) {
        if (useGoogleMap) {
          return GoogleMap(
            initialCameraPosition: initialCamera,
            markers: b.markers,
            onMapCreated: b.onMapCreated,
            onCameraMove: b.onCameraMove,
            onCameraIdle: b.onCameraIdle,
            onTap: b.onMapTap,
            zoomControlsEnabled: false,
          );
        }
        // Cluster taps ask the controller to move the camera; hand that to
        // the stand-in map.
        markersController?.onCameraRequest = (c) async => standIn?.animateTo(c);
        return StandInMap(
          bindings: b,
          initialCamera: initialCamera,
          controller: standIn,
          dark: dark,
        );
      },
    );
  }
}
