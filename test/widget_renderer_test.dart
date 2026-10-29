import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widget_markers/widget_markers.dart';

void main() {
  testWidgets(
      'renders a widget that is NOT in the tree at the requested pixel ratio',
      (tester) async {
    // Nothing is pumped: the widget never enters the tree.
    final r = await tester.runAsync(() => const WidgetRenderer().render(
          Container(width: 40, height: 20, color: Colors.red),
          pixelRatio: 3,
        ));
    expect(r!.logicalSize, const Size(40, 20));
    expect(r.image.width, 120);
    expect(r.image.height, 60);
    expect(r.pixelRatio, 3);
  });

  testWidgets('pixels are really painted (not an empty image)', (tester) async {
    final bytes = await tester.runAsync(() async {
      final r = await const WidgetRenderer().render(
        Container(width: 10, height: 10, color: const Color(0xFFFF0000)),
        pixelRatio: 2,
      );
      return (await r.image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    });
    expect(bytes!.getUint8(0), 255);
    expect(bytes.getUint8(1), 0);
    expect(bytes.getUint8(3), 255);
  });

  testWidgets('different pixel ratios give same logical size, scaled pixels',
      (tester) async {
    final a = (await tester.runAsync(() => const WidgetRenderer()
        .render(const SizedBox(width: 30, height: 30), pixelRatio: 1)))!;
    final b = (await tester.runAsync(() => const WidgetRenderer()
        .render(const SizedBox(width: 30, height: 30), pixelRatio: 2.625)))!;
    expect(a.logicalSize, b.logicalSize);
    expect(b.image.width, (30 * 2.625).round());
  });

  testWidgets('sizes to content within maxSize, and respects fixedSize',
      (tester) async {
    final fit = (await tester.runAsync(() => const WidgetRenderer().render(
        const Text('Hello', textDirection: TextDirection.ltr),
        pixelRatio: 1)))!;
    expect(fit.logicalSize.width, lessThan(100));
    final fixed = (await tester.runAsync(() => const WidgetRenderer().render(
        const Text('x', textDirection: TextDirection.ltr),
        fixedSize: const Size(64, 32),
        pixelRatio: 1)))!;
    expect(fixed.logicalSize, const Size(64, 32));
  });

  testWidgets('uses theme and pixel ratio from a context when given',
      (tester) async {
    late BuildContext ctx;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme:
          ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.green)),
      home: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      }),
    ));
    final r = (await tester.runAsync(() => const WidgetRenderer()
        .render(const SizedBox(width: 10, height: 10), context: ctx)))!;
    expect(r.pixelRatio, 2);
  });

  testWidgets('empty-size widgets fail with a clear error', (tester) async {
    final error = await tester.runAsync(() async {
      try {
        await const WidgetRenderer().render(const SizedBox.shrink());
      } on StateError catch (e) {
        return e;
      }
      return null;
    });
    expect(error, isNotNull);
  });

  testWidgets('precached Image widgets are painted, not left empty',
      (tester) async {
    final provider = MemoryImage(await _redPng(tester));
    final bytes = await tester.runAsync(() async {
      final r = await const WidgetRenderer().render(
        Image(image: provider, width: 8, height: 8, fit: BoxFit.fill),
        precache: [provider],
        pixelRatio: 1,
      );
      return (await r.image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    });
    const center = (4 * 8 + 4) * 4;
    expect(bytes!.getUint8(center), 255);
    expect(bytes.getUint8(center + 3), 255);
  });
}

Future<Uint8List> _redPng(WidgetTester tester) async {
  return (await tester.runAsync(() async {
    final rec = ui.PictureRecorder();
    Canvas(rec).drawRect(const Rect.fromLTWH(0, 0, 4, 4),
        Paint()..color = const Color(0xFFFF0000));
    final img = await rec.endRecording().toImage(4, 4);
    return (await img.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
  }))!;
}
