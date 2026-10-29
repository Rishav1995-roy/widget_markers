import 'dart:collection';
import 'dart:typed_data';
import 'dart:ui';

import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'widget_renderer.dart';

/// A rendered marker image ready for `google_maps_flutter`.
class MarkerBitmap {
  /// Creates a marker bitmap.
  const MarkerBitmap({
    required this.png,
    required this.logicalSize,
    required this.pixelRatio,
  });

  /// Encodes a [RenderedWidget] as PNG and releases its image.
  static Future<MarkerBitmap> fromRendered(RenderedWidget r) async {
    final png = await r.toPng();
    r.image.dispose();
    return MarkerBitmap(
      png: png,
      logicalSize: r.logicalSize,
      pixelRatio: r.pixelRatio,
    );
  }

  /// PNG bytes (physical pixels).
  final Uint8List png;

  /// Size on screen in logical pixels.
  final Size logicalSize;

  /// Pixel ratio the PNG was rasterised at.
  final double pixelRatio;

  /// Descriptor with the explicit logical size, so the marker is the same
  /// physical size on every device and sharp on dense screens.
  BitmapDescriptor get descriptor => BitmapDescriptor.bytes(
        png,
        imagePixelRatio: pixelRatio,
        width: logicalSize.width,
        height: logicalSize.height,
      );
}

/// LRU cache of [MarkerBitmap]s keyed by an arbitrary value (plus pixel ratio).
///
/// Concurrent requests for the same key share one render, and a key that is
/// already cached is never rendered again.
class MarkerBitmapCache {
  /// Creates a cache holding at most [maxEntries] bitmaps.
  MarkerBitmapCache({this.maxEntries = 256}) : assert(maxEntries > 0);

  /// Maximum number of cached bitmaps.
  final int maxEntries;

  final LinkedHashMap<(Object, double), MarkerBitmap> _ready =
      LinkedHashMap<(Object, double), MarkerBitmap>();
  final Map<(Object, double), Future<MarkerBitmap>> _pending = {};

  /// Number of lookups served from cache.
  int hits = 0;

  /// Number of lookups that had to render.
  int misses = 0;

  /// Number of cached bitmaps.
  int get length => _ready.length;

  /// The cached bitmap for [key], or null. Refreshes its LRU position.
  MarkerBitmap? peek(Object key, double pixelRatio) {
    final k = (key, pixelRatio);
    final v = _ready.remove(k);
    if (v != null) _ready[k] = v;
    return v;
  }

  /// Returns the cached bitmap or renders it once with [create].
  Future<MarkerBitmap> obtain(
    Object key,
    double pixelRatio,
    Future<MarkerBitmap> Function() create,
  ) {
    final hit = peek(key, pixelRatio);
    if (hit != null) {
      hits++;
      return Future.value(hit);
    }
    final k = (key, pixelRatio);
    final inFlight = _pending[k];
    if (inFlight != null) return inFlight;
    misses++;
    final f = create().then((bitmap) {
      _ready[k] = bitmap;
      while (_ready.length > maxEntries) {
        _ready.remove(_ready.keys.first);
      }
      return bitmap;
    }).whenComplete(() {
      _pending.remove(k);
    });
    _pending[k] = f;
    return f;
  }

  /// Removes every entry for [key] (all pixel ratios).
  void evict(Object key) => _ready.removeWhere((k, _) => k.$1 == key);

  /// Removes everything.
  void clear() => _ready.clear();
}
