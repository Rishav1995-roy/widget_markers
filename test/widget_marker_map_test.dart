import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:widget_markers/widget_markers.dart';

const _start = CameraPosition(target: LatLng(12.9716, 77.5946), zoom: 14);

WidgetMarker _pin(String id, LatLng p,
        {Object? key,
        Widget? selected,
        Offset anchor = const Offset(0.5, 1)}) =>
    WidgetMarker(
      id: id,
      position: p,
      cacheKey: key,
      selectedChild: selected,
      anchor: anchor,
      child: Container(
        width: 40,
        height: 50,
        decoration: BoxDecoration(
            color: Colors.teal, borderRadius: BorderRadius.circular(8)),
      ),
    );

class _Harness {
  WidgetMarkerMapBindings? b;
  int mapTaps = 0;
  final controller = WidgetMarkersController();
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
    await tester.pump();
  }
}

Future<_Harness> _pump(
  WidgetTester tester,
  List<WidgetMarker> markers, {
  ClusterOptions? cluster,
  InfoWindowOptions? info,
  MarkerAnimation animation = MarkerAnimation.none,
  _Harness? harness,
  CameraPosition camera = _start,
}) async {
  final h = harness ?? _Harness();
  tester.view.physicalSize = Size(400, 800) * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 400,
          height: 800,
          child: WidgetMarkerMap(
            controller: h.controller,
            initialCameraPosition: camera,
            markers: markers,
            cluster: cluster,
            infoWindow: info,
            animation: animation,
            mapBuilder: (context, bindings) {
              h.b = bindings;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  h.mapTaps++;
                  bindings.onMapTap(const LatLng(0, 0));
                },
                child: const ColoredBox(color: Color(0xFFE0E0E0)),
              );
            },
          ),
        ),
      ),
    ),
  ));
  await _settle(tester);
  return h;
}

void main() {
  const a = LatLng(12.9716, 77.5946);

  group('widgets become markers', () {
    testWidgets('icon is a real bitmap with the widget size, anchor and ratio',
        (tester) async {
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final h = await _pump(tester, [_pin('a', a)]);
      final m = h.b!.markers.single;
      final icon = m.icon as BytesMapBitmap;
      expect(icon.width, 40);
      expect(icon.height, 50);
      expect(icon.imagePixelRatio, 3);
      expect(m.anchor, const Offset(0.5, 1));
      expect(m.position, a);
      expect(m.consumeTapEvents, isTrue);
    });

    testWidgets('anchor is configurable per marker', (tester) async {
      final h =
          await _pump(tester, [_pin('a', a, anchor: const Offset(0.5, 0.5))]);
      expect(h.b!.markers.single.anchor, const Offset(0.5, 0.5));
    });
  });

  group('caching: re-render only when key/data changes', () {
    testWidgets('same data, rebuilds and camera moves cause zero new renders',
        (tester) async {
      final markers = [
        for (var i = 0; i < 5; i++) _pin('m$i', LatLng(12.97 + i * .01, 77.59))
      ];
      final h = await _pump(tester, markers);
      final renders = h.controller.renderCount;
      // Same cache key for all five -> keyed by id, so 5 renders initially.
      expect(renders, 5);
      await _pump(tester, markers, harness: h); // rebuild, same data
      h.b!.onCameraMove(
          const CameraPosition(target: LatLng(13, 77.6), zoom: 15));
      h.b!.onCameraIdle();
      await _settle(tester);
      expect(h.controller.renderCount, renders);
      expect(h.b!.markers, hasLength(5));
    });

    testWidgets('changing one cacheKey re-renders only that marker',
        (tester) async {
      final h = await _pump(
          tester, [_pin('a', a, key: 'v1'), _pin('b', a, key: 'x')]);
      final before = h.controller.renderCount;
      await _pump(tester, [_pin('a', a, key: 'v2'), _pin('b', a, key: 'x')],
          harness: h);
      expect(h.controller.renderCount, before + 1);
    });

    testWidgets('markers sharing a cacheKey share one render', (tester) async {
      final h = await _pump(tester, [
        _pin('a', a, key: 'same'),
        _pin('b', const LatLng(13, 77.6), key: 'same'),
      ]);
      expect(h.controller.renderCount, 1);
      expect(h.b!.markers, hasLength(2));
    });

    testWidgets('moving a marker does not re-render it', (tester) async {
      final h = await _pump(tester, [_pin('a', a)]);
      final before = h.controller.renderCount;
      await _pump(tester, [_pin('a', const LatLng(13, 77.7))], harness: h);
      expect(h.controller.renderCount, before);
      expect(h.b!.markers.single.position, const LatLng(13, 77.7));
    });

    testWidgets('selection swaps to selectedChild (rendered once, cached)',
        (tester) async {
      final sel = Container(width: 60, height: 70, color: Colors.orange);
      final h = await _pump(tester, [_pin('a', a, selected: sel)]);
      h.controller.select('a');
      await _settle(tester);
      expect((h.b!.markers.single.icon as BytesMapBitmap).width, 60);
      final n = h.controller.renderCount;
      h.controller.clearSelection();
      await _settle(tester);
      h.controller.select('a');
      await _settle(tester);
      expect(h.controller.renderCount, n); // both variants already cached
    });
  });

  group('animated marker updates', () {
    testWidgets('a moved marker glides to its new position', (tester) async {
      const to = LatLng(13.0, 77.7);
      final h = await _pump(tester, [_pin('a', a)],
          animation: const MarkerAnimation(
              duration: Duration(milliseconds: 1000), curve: Curves.linear));
      await _pump(tester, [_pin('a', to)],
          harness: h,
          animation: const MarkerAnimation(
              duration: Duration(milliseconds: 1000), curve: Curves.linear));
      await tester.pump(); // start ticker
      await tester.pump(const Duration(milliseconds: 500));
      final mid = h.b!.markers.single.position;
      expect(mid.latitude, closeTo((a.latitude + to.latitude) / 2, 0.01));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 100));
      expect(h.b!.markers.single.position, to);
    });
  });

  group('cluster icons are widgets', () {
    final near = [
      for (var i = 0; i < 3; i++)
        _pin('n$i', LatLng(12.9716 + i * 1e-4, 77.5946)),
    ];
    final other = [
      for (var i = 0; i < 3; i++) _pin('o$i', LatLng(13.2 + i * 1e-4, 77.9)),
    ];
    final far = _pin('far', const LatLng(28.6, 77.2));

    testWidgets('groups become count badges; zooming in splits them',
        (tester) async {
      final h = await _pump(tester, [...near, ...other, far],
          cluster: const ClusterOptions(),
          camera: const CameraPosition(target: LatLng(13, 77.7), zoom: 8));
      var ms = h.b!.markers;
      expect(ms.where((m) => m.markerId.value.startsWith('cluster:')),
          hasLength(2));
      expect(ms.where((m) => m.markerId.value == 'far'), hasLength(1));
      // Badge icon is a real bitmap larger than nothing.
      final badge =
          ms.firstWhere((m) => m.markerId.value.startsWith('cluster:'));
      expect((badge.icon as BytesMapBitmap).width, greaterThan(30));
      expect(badge.anchor, const Offset(0.5, 0.5));
      // Two clusters of the same size share ONE rendered badge bitmap.
      expect(h.controller.cache.length, lessThan(ms.length + 1));

      h.b!.onCameraMove(
          const CameraPosition(target: LatLng(12.9716, 77.5946), zoom: 19));
      h.b!.onCameraIdle();
      await _settle(tester);
      ms = h.b!.markers;
      expect(ms.where((m) => m.markerId.value.startsWith('cluster:')), isEmpty);
      expect(ms.length, 7);
    });

    testWidgets('same-size clusters share one badge render', (tester) async {
      final h = await _pump(tester, [...near, ...other],
          cluster: const ClusterOptions(),
          camera: const CameraPosition(target: LatLng(13, 77.7), zoom: 8));
      expect(h.b!.markers, hasLength(2));
      expect(h.controller.renderCount, 1);
    });

    testWidgets('custom builder widget is used as the cluster icon',
        (tester) async {
      final h = await _pump(tester, near,
          cluster: ClusterOptions(
            builder: (c, cl) =>
                Container(width: 77, height: 33, color: Colors.pink),
          ),
          camera: const CameraPosition(target: LatLng(12.97, 77.59), zoom: 8));
      final icon = h.b!.markers.single.icon as BytesMapBitmap;
      expect(icon.width, 77);
      expect(icon.height, 33);
    });

    testWidgets('tapping a cluster zooms to its members', (tester) async {
      final h = await _pump(tester, near,
          cluster: const ClusterOptions(),
          camera: const CameraPosition(target: LatLng(12.97, 77.59), zoom: 8));
      CameraPosition? requested;
      h.controller.onCameraRequest = (p) async => requested = p;
      h.b!.markers.single.onTap!();
      await tester.pump();
      expect(requested, isNotNull);
      expect(requested!.zoom, greaterThan(8));
      expect(requested!.target.latitude, closeTo(12.9717, 0.001));
    });

    testWidgets('non-clusterable markers stay single', (tester) async {
      final h = await _pump(
          tester,
          [
            for (final m in near)
              WidgetMarker(
                  id: m.id,
                  position: m.position,
                  child: m.child,
                  clusterable: false)
          ],
          cluster: const ClusterOptions(),
          camera: const CameraPosition(target: LatLng(12.97, 77.59), zoom: 8));
      expect(h.b!.markers, hasLength(3));
    });
  });

  group('info window is a real widget that follows the camera', () {
    Offset expectedTarget(CameraPosition cam, LatLng p,
        {double gap = 4, Size icon = const Size(40, 50)}) {
      final s =
          MapProjection(camera: cam, size: const Size(400, 800)).toScreen(p);
      return Offset(s.dx, s.dy - icon.height - gap);
    }

    Offset bubbleBottomCentre(WidgetTester tester) =>
        tester.getBottomLeft(find.byType(InfoBubble)) +
        Offset(tester.getSize(find.byType(InfoBubble)).width / 2, 0);

    InfoWindowOptions options({VoidCallback? onPressed}) => InfoWindowOptions(
          builder: (c, m) => Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Hello ${m.id}'),
            TextButton(onPressed: onPressed, child: const Text('Open')),
          ]),
        );

    testWidgets('appears above the selected marker', (tester) async {
      final h = await _pump(tester, [_pin('a', a)], info: options());
      expect(find.byType(InfoBubble), findsNothing);
      h.b!.markers.single.onTap!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Hello a'), findsOneWidget);
      final got = bubbleBottomCentre(tester);
      final want = expectedTarget(_start, a);
      expect(got.dx, closeTo(want.dx, 0.6));
      expect(got.dy, closeTo(want.dy, 0.6));
    });

    testWidgets('tracks pan, zoom and rotation in the SAME frame as the camera',
        (tester) async {
      final h = await _pump(tester, [_pin('a', a)], info: options());
      h.b!.markers.single.onTap!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final cams = [
        const CameraPosition(target: LatLng(12.9740, 77.5970), zoom: 14), // pan
        const CameraPosition(
            target: LatLng(12.9740, 77.5970), zoom: 16.4), // zoom
        const CameraPosition(
            target: LatLng(12.9725, 77.5950),
            zoom: 16.4,
            bearing: 70), // rotate
        const CameraPosition(
            target: LatLng(12.9720, 77.5948), zoom: 17, bearing: 200),
      ];
      for (final cam in cams) {
        h.b!.onCameraMove(cam); // one event ...
        await tester.pump(); //    ... exactly one frame
        final got = bubbleBottomCentre(tester);
        final want = expectedTarget(cam, a);
        expect(got.dx, closeTo(want.dx, 0.6), reason: '$cam');
        expect(got.dy, closeTo(want.dy, 0.6), reason: '$cam');
      }
    });

    testWidgets('hides when the marker leaves the map and returns when back',
        (tester) async {
      final h = await _pump(tester, [_pin('a', a)], info: options());
      h.b!.markers.single.onTap!();
      await tester.pump(const Duration(milliseconds: 400));
      h.b!.onCameraMove(const CameraPosition(target: LatLng(14, 78), zoom: 14));
      await tester.pump();
      expect(find.byType(InfoBubble), findsNothing);
      h.b!.onCameraMove(_start);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(InfoBubble), findsOneWidget);
    });

    testWidgets('taps on the window do not reach the map; elsewhere they do',
        (tester) async {
      var pressed = 0;
      final h = await _pump(tester, [_pin('a', a)],
          info: options(onPressed: () => pressed++));
      h.b!.markers.single.onTap!();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Open'));
      await tester.pump();
      expect(pressed, 1);
      expect(h.mapTaps, 0);
      expect(find.byType(InfoBubble), findsOneWidget);
      await tester.tapAt(const Offset(350, 700)); // empty map area
      await tester.pump();
      expect(h.mapTaps, 1);
      expect(find.byType(InfoBubble), findsNothing); // dismissed
      expect(h.controller.selectedId, isNull);
    });

    testWidgets('per-marker infoWindowBuilder overrides the map-wide one',
        (tester) async {
      final m = WidgetMarker(
        id: 'a',
        position: a,
        child: const SizedBox(width: 40, height: 50),
        infoWindowBuilder: (c) => const Text('custom!'),
      );
      final h = await _pump(tester, [m], info: options());
      h.b!.markers.single.onTap!();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('custom!'), findsOneWidget);
    });

    testWidgets('follows an animating marker', (tester) async {
      const to = LatLng(12.9800, 77.6000);
      const anim = MarkerAnimation(
          duration: Duration(milliseconds: 1000), curve: Curves.linear);
      final h =
          await _pump(tester, [_pin('a', a)], info: options(), animation: anim);
      h.b!.markers.single.onTap!();
      await tester.pump(const Duration(milliseconds: 400));
      await _pump(tester, [_pin('a', to)],
          info: options(), animation: anim, harness: h);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final p = h.controller.positionOf('a')!;
      final want = expectedTarget(_start, p);
      final got = bubbleBottomCentre(tester);
      expect(got.dx, closeTo(want.dx, 0.6));
      expect(got.dy, closeTo(want.dy, 0.6));
    });
  });

  group('selection', () {
    testWidgets('tap selects, callbacks fire, controller can change it',
        (tester) async {
      final tapped = <String>[];
      final selected = <WidgetMarker?>[];
      final h = _Harness();
      h.controller.onSelectionChanged = selected.add;
      await _pump(
          tester,
          [
            WidgetMarker(
                id: 'a',
                position: a,
                child: const SizedBox(width: 20, height: 20),
                onTap: () => tapped.add('a'))
          ],
          harness: h);
      h.b!.markers.single.onTap!();
      expect(tapped, ['a']);
      expect(h.controller.selectedId, 'a');
      h.controller.clearSelection();
      expect(h.controller.selectedId, isNull);
      expect(selected, isNotEmpty);
    });
  });
}
