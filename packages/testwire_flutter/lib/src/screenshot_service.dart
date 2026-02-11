import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Captures screenshots of all active render views as base64-encoded PNGs.
///
/// Each call to [takeScreenshots] iterates over every [RenderView] known to
/// [WidgetsBinding] and renders its layer tree into a [ui.Image], then encodes
/// that image as a PNG and returns a base64 string.
///
/// Based on the approach used by Marionette MCP.
class ScreenshotService {
  /// Creates a screenshot service.
  const ScreenshotService();

  /// Captures a screenshot of every active [RenderView] and returns
  /// a list of base64-encoded PNG strings (one per view).
  Future<List<String>> takeScreenshots() async {
    final binding = WidgetsBinding.instance;
    final renderViews = binding.renderViews.toList();

    if (renderViews.isEmpty) {
      return const [];
    }

    final futures = <Future<String?>>[];
    for (final renderView in renderViews) {
      futures.add(_captureView(renderView));
    }

    final results = await Future.wait(futures);
    return results.whereType<String>().toList();
  }

  Future<String?> _captureView(RenderView renderView) async {
    try {
      // Schedule a frame if the view hasn't painted yet so the layer tree
      // is populated.
      // ignore: invalid_use_of_protected_member
      if (renderView.debugNeedsPaint || renderView.layer == null) {
        WidgetsBinding.instance.scheduleFrame();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      // ignore: invalid_use_of_protected_member
      final layer = renderView.layer;
      if (layer == null) return null;

      // Use the physical size from the FlutterView — this already accounts
      // for the device pixel ratio.  The layer tree is rendered in physical
      // coordinates, so we must NOT apply an extra transform.
      final size = renderView.flutterView.physicalSize;
      if (size.isEmpty) return null;

      final width = size.width.ceil();
      final height = size.height.ceil();
      if (width <= 0 || height <= 0) return null;

      final builder = ui.SceneBuilder();
      layer.addToScene(builder);
      final scene = builder.build();

      ui.Image? image;
      try {
        image = await scene.toImage(width, height);

        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) return null;

        return base64Encode(byteData.buffer.asUint8List());
      } finally {
        image?.dispose();
        scene.dispose();
      }
    } catch (_) {
      // If capturing fails for any reason (e.g. the view was disposed
      // mid-capture), silently skip this view.
      return null;
    }
  }
}
