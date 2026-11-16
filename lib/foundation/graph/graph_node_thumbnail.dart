import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:anoworld/foundation/graph/graph_models.dart';
import 'package:anoworld/foundation/graph/graph_node_visual.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Renders [GraphNodeVisual] off-screen and returns PNG bytes for map chips.
abstract final class GraphNodeThumbnail {
  static Future<Uint8List?> capture(
    BuildContext context, {
    required GraphNodeData data,
    double pixelRatio = 2.0,
  }) async {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return null;

    final key = GlobalKey();
    final size = GraphNodeVisual.chipSize(data);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (overlayContext) => Positioned(
        left: -size.width * 4,
        top: -size.height * 4,
        child: Material(
          type: MaterialType.transparency,
          child: RepaintBoundary(
            key: key,
            child: GraphNodeVisual(data: data),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    try {
      await Future<void>.delayed(Duration.zero);
      await WidgetsBinding.instance.endOfFrame;
      final boundary = key.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      return bytes?.buffer.asUint8List();
    } finally {
      entry.remove();
    }
  }
}