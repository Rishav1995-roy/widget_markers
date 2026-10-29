// Generates the frames for doc/demo.gif and the screenshots.
//
// Opt-in: it only runs through tool/make_demo.sh (GENERATE_DEMO=1).
// The map in these images is a STAND-IN drawn in Flutter (platform views
// cannot render in tests); the markers, cluster badges and info window are
// the real widget_markers output.
// ignore_for_file: avoid_relative_lib_imports
@Tags(['demo'])
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:widget_markers/widget_markers.dart';

import '../../example/lib/data.dart';
import '../../example/lib/places_map.dart';
import '../../example/lib/stand_in_map.dart';

const _ratio = 1.2;
const _size = Size(400, 640);
const _fps = 12;

Future<void> _loadFonts(WidgetTester tester) async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = File('tool/fonts/$f').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }

  await tester.runAsync(() async {
    await load('Roboto', ['Roboto-Regular.ttf', 'Roboto-Bold.ttf']);
    await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
  });
}

Widget _scene({
  required GlobalKey boundary,
  required List<Place> places,
  required WidgetMarkersController markers,
  required StandInMapController standIn,
  required bool dark,
  required CameraPosition camera,
  MapSettings settings = const MapSettings(),
}) {
  final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F766E),
      brightness: dark ? Brightness.dark : Brightness.light);
  return RepaintBoundary(
    key: boundary,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: scheme, useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('widget_markers',
              style: TextStyle(fontWeight: FontWeight.w600)),
          backgroundColor: scheme.surface,
        ),
        body: PlacesMap(
          places: places,
          markersController: markers,
          standIn: standIn,
          dark: dark,
          initialCamera: camera,
          settings: settings,
        ),
      ),
    ),
  );
}

Future<void> _save(WidgetTester tester, GlobalKey key, String path) async {
  await tester.runAsync(() async {
    final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await b.toImage(pixelRatio: _ratio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(data!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> _settle(WidgetTester tester, [int rounds = 3]) async {
  for (var i = 0; i < rounds; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump(const Duration(milliseconds: 16));
  }
}

double _ease(double t) => t * t * (3 - 2 * t);

CameraPosition _lerp(CameraPosition a, CameraPosition b, double t) {
  final e = _ease(t.clamp(0.0, 1.0));
  return CameraPosition(
    target: LatLng(
        a.target.latitude + (b.target.latitude - a.target.latitude) * e,
        a.target.longitude + (b.target.longitude - a.target.longitude) * e),
    zoom: a.zoom + (b.zoom - a.zoom) * e,
    bearing: a.bearing + (b.bearing - a.bearing) * e,
  );
}

void main() {
  final generate = Platform.environment['GENERATE_DEMO'] == '1';

  testWidgets('demo frames and screenshots', skip: !generate, (tester) async {
    tester.view.devicePixelRatio = _ratio;
    tester.view.physicalSize = _size * _ratio;
    addTearDown(tester.view.reset);
    await _loadFonts(tester);

    final places = samplePlaces();
    final out = Directory('build/demo_frames');
    if (out.existsSync()) out.deleteSync(recursive: true);
    out.createSync(recursive: true);

    // ---- animated demo (light) -------------------------------------
    {
      final key = GlobalKey();
      final markers = WidgetMarkersController();
      final standIn = StandInMapController();
      const start =
          CameraPosition(target: LatLng(12.9716, 77.5946), zoom: 11.2);
      await tester.pumpWidget(_scene(
          boundary: key,
          places: places,
          markers: markers,
          standIn: standIn,
          dark: false,
          camera: start));
      await _settle(tester, 6);

      const hub = CameraPosition(target: LatLng(12.9716, 77.5946), zoom: 15.8);
      const pan = CameraPosition(
          target: LatLng(12.9738, 77.5984), zoom: 16.4, bearing: 38);
      const total = 7 * _fps;
      final target = places.firstWhere((p) => p.id == 'p0');
      for (var f = 0; f < total; f++) {
        CameraPosition cam;
        if (f < 12) {
          cam = start;
        } else if (f < 36) {
          cam = _lerp(start, hub, (f - 12) / 24);
        } else if (f < 46) {
          cam = hub;
        } else if (f < 72) {
          cam = _lerp(hub, pan, (f - 46) / 26);
        } else {
          cam = _lerp(pan, start, (f - 72) / (total - 72 - 1));
        }
        if (f == 36) markers.select(target.id);
        if (f == 72) markers.clearSelection();
        standIn.setCamera(cam);
        if (f >= 72 && f < 76) markers.cameraIdle();
        await tester.pump(const Duration(milliseconds: 40));
        // Re-clustering renders new badges off-screen; give them time.
        await _settle(tester, 2);
        await _save(tester, key,
            'build/demo_frames/f_${f.toString().padLeft(3, '0')}.png');
        if (f == 40) {
          await _save(tester, key, 'build/demo_frames/shot_light.png');
        }
        if (f == 60) {
          await _save(tester, key, 'build/demo_frames/shot_follow.png');
        }
        if (f == 6) {
          await _save(tester, key, 'build/demo_frames/shot_clusters.png');
        }
      }
      await tester.pumpWidget(const SizedBox());
      markers.dispose();
    }

    // ---- dark screenshot ----------------------------------------------
    {
      final key = GlobalKey();
      final markers = WidgetMarkersController();
      final standIn = StandInMapController();
      const cam = CameraPosition(
          target: LatLng(12.9722, 77.5966), zoom: 15.9, bearing: 20);
      await tester.pumpWidget(_scene(
          boundary: key,
          places: places,
          markers: markers,
          standIn: standIn,
          dark: true,
          camera: cam));
      await _settle(tester, 6);
      markers.select('p0');
      await _settle(tester, 4);
      await tester.pump(const Duration(milliseconds: 400));
      await _save(tester, key, 'build/demo_frames/shot_dark.png');
      await tester.pumpWidget(const SizedBox());
      markers.dispose();
    }
    expect(math.max(1, out.listSync().length), greaterThan(1));
  });
}
