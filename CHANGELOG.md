## 0.0.1

Initial release.

- Render any widget to a `BitmapDescriptor` off-screen (`WidgetRenderer`), at the
  device pixel ratio, with an LRU cache keyed by your own data (`MarkerBitmapCache`).
- `WidgetMarkerMap` + `WidgetMarker`: widget markers with anchor, selected variant,
  tap/selection, drag callbacks and animated position changes.
- Camera-following widget info window (`InfoWindowOptions`, `InfoBubble`) positioned
  with a synchronous Web-Mercator projection (`MapProjection`).
- Built-in grid clustering (`GridClusterer`, `ClusterOptions`) with widget cluster
  icons (`ClusterBadge`) and tap-to-zoom.
