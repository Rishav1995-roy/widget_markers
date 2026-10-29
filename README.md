# widget_markers

[![pub version](https://img.shields.io/pub/v/widget_markers.svg)](https://pub.dev/packages/widget_markers)
[![pub points](https://img.shields.io/pub/points/widget_markers)](https://pub.dev/packages/widget_markers/score)
[![likes](https://img.shields.io/pub/likes/widget_markers)](https://pub.dev/packages/widget_markers)
[![popularity](https://img.shields.io/pub/popularity/widget_markers)](https://pub.dev/packages/widget_markers/score)
[![CI](https://github.com/Rishav1995-roy/widget_markers/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/Rishav1995-roy/widget_markers/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![Platforms](https://img.shields.io/badge/platforms-android%20%7C%20ios%20%7C%20web-informational)

Use **any Flutter widget** as a `google_maps_flutter` marker, show **real widget info windows that follow the camera**, and build **cluster badges from widgets**. This is what [flutter/flutter#24213](https://github.com/flutter/flutter/issues/24213) (open since 2018, 487 reactions) has been asking for.

![Demo](https://raw.githubusercontent.com/Rishav1995-roy/widget_markers/main/doc/demo.gif)

> **About the images:** platform views (the real Google map) cannot render in widget tests, so the demo GIF and screenshots show a **stand-in map drawn in Flutter**. The markers, cluster badges and info window in them are the real output of this package, painted from the very same bitmaps the plugin receives. Run the example with `--dart-define=GOOGLE_MAP=true` to see it on the real map.

<p>
  <img src="https://raw.githubusercontent.com/Rishav1995-roy/widget_markers/main/doc/screenshot_light.png" width="260" alt="Light">
  <img src="https://raw.githubusercontent.com/Rishav1995-roy/widget_markers/main/doc/screenshot_dark.png" width="260" alt="Dark">
  <img src="https://raw.githubusercontent.com/Rishav1995-roy/widget_markers/main/doc/screenshot_clusters.png" width="260" alt="Clusters">
</p>

## Why this package

`google_maps_flutter` only accepts bitmaps for markers and has no custom info windows. Existing helpers each cover a slice:

| | `widget_to_marker` | `custom_info_window` | `widget_markers` |
|---|---|---|---|
| Widget to marker bitmap | Yes (one-shot helper) | No | Yes, off-screen, at the device pixel ratio |
| Needs the widget in the tree / a screen | Needs a `BuildContext` | n/a | No: laid out in a private render pipeline |
| Caching, re-render only on change | No | n/a | LRU cache keyed by your data; identical keys share one render |
| Marker updates (data, selection, animation) | You rebuild by hand | n/a | Selected variant, animated position changes |
| Info window as a real widget | No | Yes | Yes, with taps handled inside the window |
| Window position follows the camera | n/a | Via async `getScreenCoordinate` | Synchronous projection, same frame as `onCameraMove` |
| Cluster icons from widgets | No | No | Yes (built-in grid clustering) |
| Rendering core testable without a map | No | No | Yes (pure Dart + unit tests) |

Problems reported against the alternatives that this package is designed around (not a claim about their current state):

- `custom_info_window` positions the window with `GoogleMapController.getScreenCoordinate`; its tracker shows a native-channel failure on some setups ([#20](https://github.com/abhishekduhoon/custom_info_window/issues/20)), `setState() called after dispose` ([#22](https://github.com/abhishekduhoon/custom_info_window/issues/22)) and asks for showing a window programmatically ([#23](https://github.com/abhishekduhoon/custom_info_window/issues/23), [#8](https://github.com/abhishekduhoon/custom_info_window/issues/8)) and multiple windows ([#7](https://github.com/abhishekduhoon/custom_info_window/issues/7)). Here the position is plain math, the selected marker is controllable (`select`/`clearSelection`), and the overlay disposes with the widget.
- `widget_to_marker` has open reports about `ViewConfiguration` API changes breaking rendering ([#9](https://github.com/Mohamedfaroouk/widget_to_marker/issues/9), [#4](https://github.com/Mohamedfaroouk/widget_to_marker/issues/4)) and background colour problems ([#12](https://github.com/Mohamedfaroouk/widget_to_marker/issues/12)). This package is tested on Flutter 3.27.4 and the latest stable.
- Re-creating bitmaps for every update is the cost behind [flutter#41731](https://github.com/flutter/flutter/issues/41731). Bitmaps are cached by key here.

## Features

- **Widget markers** with anchor, z-index, rotation, flat, drag callbacks, per-marker selected widget.
- **Off-screen rendering** at the right pixel ratio; `precache` for images; theme captured from your context.
- **Caching** with `cacheKey`: change the key and only that marker re-renders.
- **Info windows**: any widget, bubble styling (`InfoBubbleStyle`) or none, per-marker builders, hide when off-screen, dismiss on map tap, fade-in.
- **Clustering** with widget badges (`ClusterBadge` / your own builder), tap to zoom to members.
- **Animated updates**: change a marker's `position` and it glides.

## Install

```sh
flutter pub add widget_markers google_maps_flutter
```

Set up `google_maps_flutter` (API keys) as usual. This package works with `google_maps_flutter >=2.10.0 <3.0.0`.

## Quick start

```dart
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:widget_markers/widget_markers.dart';

const start = CameraPosition(target: LatLng(12.9716, 77.5946), zoom: 13);

WidgetMarkerMap(
  initialCameraPosition: start,
  markers: [
    for (final p in places)
      WidgetMarker(
        id: p.id,
        position: p.latLng,
        cacheKey: p.price, // re-render only when the price changes
        child: PriceTag(price: p.price),
        selectedChild: PriceTag(price: p.price, highlighted: true),
      ),
  ],
  cluster: const ClusterOptions(),
  infoWindow: InfoWindowOptions(
    builder: (context, marker) => PlaceCard(place: marker.data as Place),
  ),
  mapBuilder: (context, b) => GoogleMap(
    initialCameraPosition: start,
    markers: b.markers,
    onMapCreated: b.onMapCreated,
    onCameraMove: b.onCameraMove,
    onCameraIdle: b.onCameraIdle,
    onTap: b.onMapTap,
  ),
);
```

The map is created by **your** `mapBuilder`, so styles, padding, gestures and every other `GoogleMap` option keep working. Wire the five bindings and you are done.

## API

### WidgetMarkerMap

| Parameter | Description |
|---|---|
| `initialCameraPosition` | The same camera you give the map (used before the first camera event). |
| `markers` | `List<WidgetMarker>`. Build a new list when data changes. |
| `mapBuilder` | Builds the map from `WidgetMarkerMapBindings`. |
| `controller` | Optional `WidgetMarkersController` (selection, shared cache, camera moves). |
| `cluster` | `ClusterOptions`; null disables clustering. |
| `infoWindow` | `InfoWindowOptions`; null disables the info window. |
| `animation` | `MarkerAnimation` (duration, curve). `MarkerAnimation.none` to disable. |
| `pixelRatio` | Override the rendering pixel ratio. |
| `onMarkerTap`, `onSelectionChanged` | Callbacks. |

### WidgetMarker

| Field | Description |
|---|---|
| `id`, `position`, `child` | Required. |
| `selectedChild` | Icon while selected. |
| `cacheKey` | Bitmap key, default `id`. **Change it to re-render.** Markers with the same key share one bitmap. |
| `maxSize` / `size` | Layout constraint / exact size. |
| `anchor` | Point of the icon on the position, default bottom centre `(0.5, 1)`. |
| `zIndex`, `rotation`, `flat`, `visible`, `draggable`, `onDragEnd`, `onTap` | As on `Marker`. |
| `clusterable` | Opt out of clustering. |
| `data` | Your payload. |
| `infoWindowBuilder` | Per-marker info window. |

### ClusterOptions

`cellSize` (72 px), `minClusterSize` (2), `maxZoom` (16), `builder`, `cacheKey` (default: member count), `anchor`, `zIndex`, `zoomOnTap`, `zoomPadding`, `badgeStyle` (`ClusterBadgeStyle`), `onTap`.

### InfoWindowOptions

`builder`, `bubbleStyle` (`InfoBubbleStyle`, null = no bubble), `gap`, `offset`, `hideWhenOffscreen`, `dismissOnMapTap`, `animationDuration`.

### Lower-level building blocks

| | |
|---|---|
| `WidgetRenderer.render` | Widget to `ui.Image` off-screen. |
| `MarkerBitmapCache` / `MarkerBitmap` | LRU cache and a `BitmapDescriptor` with explicit logical size. |
| `MapProjection` | Synchronous lat/lng to screen (zoom, bearing), bounds fitting. |
| `GridClusterer` | Pure clustering, no map needed. |
| `MarkerAnimator` | Pure position tweening. |
| `WidgetMarkersController` | Selection, camera moves, cache access. |

## Customization examples

```dart
// Your own cluster widget
ClusterOptions(
  cacheKey: (c) => (c.count ~/ 10),            // bucket sizes to share bitmaps
  builder: (context, c) => MyHeatBubble(count: c.count),
);

// Style the bubble, or remove it and draw everything yourself
InfoWindowOptions(
  bubbleStyle: InfoBubbleStyle(
    color: Colors.black87,
    borderRadius: BorderRadius.circular(20),
    elevation: 10,
  ),
  builder: (context, m) => MyCard(m),
);
InfoWindowOptions(bubbleStyle: null, builder: (context, m) => MyOwnShape(m));

// Select from outside
final controller = WidgetMarkersController();
controller.select('p12');
```

## How it works

- **Rendering:** the widget is attached to a private `RenderView`/`BuildOwner`, laid out, painted and rasterised at the pixel ratio, then handed to the plugin as `BitmapDescriptor.bytes` with an explicit logical size so it is sharp and the same physical size on every device.
- **Info window position:** Google Maps lays the world out as `256 * 2^zoom` logical pixels. `MapProjection` applies that (plus bearing) in pure Dart, so the overlay moves in the same frame as `onCameraMove` instead of waiting for an asynchronous platform call. The overlay only hit-tests the window itself, so map gestures outside it are untouched.
- **Clustering:** markers are bucketed into screen-space grid cells; zooming re-clusters. `google_maps_flutter`'s own `ClusterManager` draws native default icons that cannot be replaced with widgets, which is why clustering is done here.

## Platform support

| Android | iOS | Web | macOS / Windows / Linux |
|---|---|---|---|
| Yes | Yes | Yes (see FAQ) | No (no `google_maps_flutter` implementation) |

Pure Dart/Flutter, no native code, so there is nothing to configure for Swift Package Manager or CocoaPods.

## Limitations

- **Camera tilt** is not modelled by the projection; with a tilted camera the info window position is approximate.
- The projection assumes the standard 256 px world at zoom 0 used by the Google Maps SDKs. It is covered by unit tests, but agreement with the native map on real devices is something to verify in your own app; the example runs on the real map with `--dart-define=GOOGLE_MAP=true`.
- Widgets are rasterised: animations inside a marker widget are not live (change `cacheKey` to re-render).
- Clusters are rebuilt on zoom change and idle; they do not animate between zoom levels.

## Coming from `widget_to_marker`

| Before | After |
|---|---|
| `await myWidget.toBitmapDescriptor(...)` per marker | `WidgetMarker(child: myWidget, ...)`; bitmaps are cached and rendered for you |
| Keep a `Set<Marker>` and rebuild it | Pass a `List<WidgetMarker>` to `WidgetMarkerMap` |
| Wrong size on dense screens | Logical size and pixel ratio handled |

You can still use the renderer alone: `WidgetRenderer().render(widget)` then `MarkerBitmap.fromRendered(r)`.

## Coming from `custom_info_window`

| Before | After |
|---|---|
| `CustomInfoWindow` + `CustomInfoWindowController` + manual `onCameraMove` plumbing | `infoWindow: InfoWindowOptions(builder: ...)` and the five bindings |
| `addInfoWindow(widget, latLng)` | Tap a marker, or `controller.select(id)` |
| `hideInfoWindow` | `controller.clearSelection()` or tap the map |

## FAQ

**Does it work on web?** The package is pure Flutter. On web the map is a platform view that can swallow pointer events over the info window; wrap the window content in a pointer-interceptor widget if buttons inside it do not react.

**My marker looks stale.** Bitmaps are cached by `cacheKey` (default `id`). Include whatever changes the look in the key.

**Images inside markers are blank.** Pass the providers in your own `WidgetRenderer.render(precache: [...])` or make sure they are already in Flutter's image cache; the renderer paints once.

**Can I tap the info window?** Yes: it is a normal widget, and taps on it do not reach the map.

## Contributing

Issues and PRs are welcome at https://github.com/Rishav1995-roy/widget_markers. Please run `flutter analyze --fatal-infos` and `flutter test` on the minimum (3.27.4) and latest Flutter first. To rebuild the demo assets: `tool/make_demo.sh`.

## License

MIT, see [LICENSE](LICENSE).
