import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// The result of rendering a widget off-screen.
class RenderedWidget {
  /// Creates a rendered widget result.
  const RenderedWidget({
    required this.image,
    required this.logicalSize,
    required this.pixelRatio,
  });

  /// The rasterised widget. Its size is [logicalSize] times [pixelRatio].
  final ui.Image image;

  /// Size of the widget in logical pixels (what a marker occupies on screen).
  final Size logicalSize;

  /// Device pixel ratio the image was rasterised at.
  final double pixelRatio;

  /// Encodes the image as PNG bytes.
  Future<Uint8List> toPng() async {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      throw StateError('Could not encode the rendered widget as PNG.');
    }
    return data.buffer.asUint8List();
  }
}

/// Renders widgets to images without attaching them to the widget tree.
///
/// The widget is laid out in a private render pipeline, so it does not need to
/// be visible, mounted or even inside the current route.
///
/// In widget tests, call [render] inside `tester.runAsync`, because encoding
/// uses real asynchronous engine work.
class WidgetRenderer {
  /// Creates a renderer.
  const WidgetRenderer();

  /// Renders [widget] and returns the image plus its logical size.
  ///
  /// * [context] - optional; its theme, text style and text direction are
  ///   captured so the widget looks like it would inside the app.
  /// * [pixelRatio] - defaults to the context's device pixel ratio, else the
  ///   platform's first view, else 1.
  /// * [maxSize] - layout constraints. The widget is sized to its content
  ///   within these bounds.
  /// * [fixedSize] - force an exact logical size instead of measuring.
  /// * [precache] - image providers resolved before the first layout so that
  ///   `Image` widgets are painted instead of rendered empty.
  /// * [settle] - optional extra wait followed by a second layout pass.
  Future<RenderedWidget> render(
    Widget widget, {
    BuildContext? context,
    double? pixelRatio,
    Size maxSize = const Size(400, 400),
    Size? fixedSize,
    List<ImageProvider> precache = const [],
    Duration settle = Duration.zero,
    TextDirection textDirection = TextDirection.ltr,
  }) async {
    final ratio = pixelRatio ?? _defaultRatio(context);
    assert(ratio > 0, 'pixelRatio must be positive');

    for (final provider in precache) {
      await precacheProvider(provider, ratio);
    }

    final constraints = fixedSize != null
        ? BoxConstraints.tight(fixedSize)
        : BoxConstraints.loose(maxSize);

    Widget content = widget;
    if (context != null && context.mounted) {
      final themes = InheritedTheme.capture(from: context, to: null);
      content = themes.wrap(widget);
    }
    final dir = context != null && context.mounted
        ? (Directionality.maybeOf(context) ?? textDirection)
        : textDirection;
    final media = context != null && context.mounted
        ? (MediaQuery.maybeOf(context) ?? const MediaQueryData())
        : const MediaQueryData();

    final wrapped = Directionality(
      textDirection: dir,
      child: MediaQuery(
        data:
            media.copyWith(devicePixelRatio: ratio, size: constraints.biggest),
        child: Material(
          type: MaterialType.transparency,
          child: fixedSize != null
              ? SizedBox.fromSize(size: fixedSize, child: content)
              : content,
        ),
      ),
    );

    final view = _view();
    final boundary = RenderRepaintBoundary();
    final renderView = RenderView(
      view: view,
      child: RenderPositionedBox(alignment: Alignment.topLeft, child: boundary),
      configuration: ViewConfiguration(
        logicalConstraints: BoxConstraints.tight(constraints.biggest),
        physicalConstraints: BoxConstraints.tight(constraints.biggest * ratio),
        devicePixelRatio: ratio,
      ),
    );
    final pipelineOwner = PipelineOwner();
    pipelineOwner.rootNode = renderView;
    renderView.prepareInitialFrame();

    final focusManager = FocusManager();
    final buildOwner = BuildOwner(focusManager: focusManager);
    final root = RenderObjectToWidgetAdapter<RenderBox>(
      container: boundary,
      child: wrapped,
    ).attachToRenderTree(buildOwner);

    void pump() {
      buildOwner.buildScope(root);
      buildOwner.finalizeTree();
      pipelineOwner
        ..flushLayout()
        ..flushCompositingBits()
        ..flushPaint();
    }

    try {
      pump();
      if (settle > Duration.zero) {
        await Future<void>.delayed(settle);
        pump();
      }
      final size = boundary.size;
      if (size.isEmpty) {
        throw StateError(
          'The widget has an empty size ($size). Give it a size or content.',
        );
      }
      final image = await boundary.toImage(pixelRatio: ratio);
      return RenderedWidget(image: image, logicalSize: size, pixelRatio: ratio);
    } finally {
      buildOwner.buildScope(root, () {
        root.update(
          RenderObjectToWidgetAdapter<RenderBox>(container: boundary),
        );
      });
      buildOwner.finalizeTree();
      pipelineOwner.rootNode = null;
      renderView.dispose();
      focusManager.dispose();
    }
  }

  static double _defaultRatio(BuildContext? context) {
    if (context != null && context.mounted) {
      final r = MediaQuery.maybeDevicePixelRatioOf(context);
      if (r != null) return r;
    }
    final views = WidgetsBinding.instance.platformDispatcher.views;
    return views.isEmpty ? 1.0 : views.first.devicePixelRatio;
  }

  static ui.FlutterView _view() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) {
      throw StateError('No FlutterView is available to render against.');
    }
    return views.first;
  }
}

/// Resolves [provider] at [pixelRatio] and completes when its first frame is
/// in the image cache, so later `Image` widgets paint synchronously.
Future<void> precacheProvider(ImageProvider provider, double pixelRatio) {
  final completer = Completer<void>();
  final stream =
      provider.resolve(ImageConfiguration(devicePixelRatio: pixelRatio));
  late ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, sync) {
      if (!completer.isCompleted) completer.complete();
      stream.removeListener(listener);
    },
    onError: (error, stack) {
      if (!completer.isCompleted) completer.complete();
      stream.removeListener(listener);
    },
  );
  stream.addListener(listener);
  return completer.future;
}
