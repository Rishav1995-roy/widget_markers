import 'dart:typed_data';

import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:widget_markers/widget_markers.dart';

MarkerBitmap _bmp() => MarkerBitmap(
    png: Uint8List(4), logicalSize: const Size(10, 10), pixelRatio: 2);

void main() {
  group('MarkerBitmapCache', () {
    test('renders once per key and ratio; concurrent calls share a render',
        () async {
      final cache = MarkerBitmapCache();
      var renders = 0;
      Future<MarkerBitmap> make() async {
        renders++;
        return _bmp();
      }

      await Future.wait([
        cache.obtain('a', 2, make),
        cache.obtain('a', 2, make),
      ]);
      await cache.obtain('a', 2, make);
      expect(renders, 1);
      await cache.obtain('a', 3, make); // other pixel ratio = other bitmap
      expect(renders, 2);
      expect(cache.hits, 1);
    });

    test('LRU eviction keeps the most recently used', () async {
      final cache = MarkerBitmapCache(maxEntries: 2);
      await cache.obtain('a', 1, () async => _bmp());
      await cache.obtain('b', 1, () async => _bmp());
      cache.peek('a', 1); // a is now most recent
      await cache.obtain('c', 1, () async => _bmp());
      expect(cache.peek('a', 1), isNotNull);
      expect(cache.peek('b', 1), isNull);
      expect(cache.length, 2);
    });

    test('evict and clear', () async {
      final cache = MarkerBitmapCache();
      await cache.obtain('a', 1, () async => _bmp());
      await cache.obtain('a', 2, () async => _bmp());
      cache.evict('a');
      expect(cache.length, 0);
    });

    test('a failed render is not cached and can be retried', () async {
      final cache = MarkerBitmapCache();
      await expectLater(cache.obtain('a', 1, () async => throw StateError('x')),
          throwsStateError);
      await cache.obtain('a', 1, () async => _bmp());
      expect(cache.length, 1);
    });

    test('descriptor carries explicit logical size and pixel ratio', () {
      final d = _bmp().descriptor as BytesMapBitmap;
      expect(d.width, 10);
      expect(d.height, 10);
      expect(d.imagePixelRatio, 2);
    });
  });

  group('MarkerAnimator', () {
    const a = LatLng(0, 0), b = LatLng(10, 20);
    const anim =
        MarkerAnimation(duration: Duration(seconds: 1), curve: Curves.linear);

    test('interpolates and finishes', () {
      final an = MarkerAnimator()..moveTo('m', a, b, anim);
      expect(an.isAnimating, isTrue);
      an.advance(const Duration(milliseconds: 500));
      expect(an.current('m', b).latitude, closeTo(5, 1e-9));
      expect(an.current('m', b).longitude, closeTo(10, 1e-9));
      an.advance(const Duration(milliseconds: 600));
      expect(an.isAnimating, isFalse);
      expect(an.current('m', b), b);
    });

    test('retargeting starts from the current position (no jump)', () {
      final an = MarkerAnimator()..moveTo('m', a, b, anim);
      an.advance(const Duration(milliseconds: 500));
      an.moveTo('m', a, const LatLng(0, 0), anim);
      expect(an.current('m', a).latitude, closeTo(5, 1e-9));
    });

    test('zero duration disables animation', () {
      final an = MarkerAnimator()..moveTo('m', a, b, MarkerAnimation.none);
      expect(an.isAnimating, isFalse);
    });
  });
}
