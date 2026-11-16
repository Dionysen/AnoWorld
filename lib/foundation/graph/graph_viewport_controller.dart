import 'dart:math' as math;

import 'package:anoworld/foundation/graph/graph_models.dart';
import 'package:anoworld/foundation/graph/graph_node_visual.dart';
import 'package:flutter/widgets.dart';

/// Bridges [GraphViewport] camera state to the overview navigator.
class GraphViewportController {
  GraphViewportController() {
    transform.addListener(_notify);
  }

  final TransformationController transform = TransformationController();
  Size viewportSize = Size.zero;

  /// Extra top padding inside the InteractiveViewer child so selection
  /// actions can sit above a node at layout y=0 without leaving the scene.
  double sceneTopInset = 0;

  VoidCallback? _listener;

  void addListener(VoidCallback listener) {
    _listener = listener;
  }

  void removeListener() {
    _listener = null;
  }

  void _notify() => _listener?.call();

  void setViewportSize(Size size) {
    if (viewportSize == size) return;
    viewportSize = size;
    _notify();
  }

  /// Visible region in graph scene coordinates (same space as node layout).
  ///
  /// Width and height match [viewportSize] aspect ratio at the current zoom.
  Rect? get visibleSceneRect {
    if (viewportSize == Size.zero) return null;
    final s = scale.clamp(0.001, 100.0);
    final w = viewportSize.width / s;
    final h = viewportSize.height / s;
    final tl = transform.toScene(Offset.zero);
    return Rect.fromLTWH(
      tl.dx,
      tl.dy - sceneTopInset,
      w,
      h,
    );
  }

  double get scale => transform.value.getMaxScaleOnAxis();

  Offset _toChild(Offset layoutPoint) =>
      Offset(layoutPoint.dx, layoutPoint.dy + sceneTopInset);

  /// Pans so [topLeft] becomes the visible top-left corner (keeps zoom).
  void setVisibleSceneTopLeft(Offset topLeft) {
    final s = scale.clamp(0.001, 100.0);
    // Keep the current matrix's scale block; only rewrite translation so
    // InteractiveViewer pinch-zoom is not normalized away.
    final child = _toChild(topLeft);
    final m = Matrix4.copy(transform.value);
    m.setTranslationRaw(-child.dx * s, -child.dy * s, 0);
    transform.value = m;
  }

  /// Centers [scenePoint] in the viewport (keeps zoom).
  void centerOnScenePoint(Offset scenePoint) {
    final s = scale.clamp(0.001, 100.0);
    final child = _toChild(scenePoint);
    final m = Matrix4.copy(transform.value);
    m.setTranslationRaw(
      viewportSize.width / 2 - child.dx * s,
      viewportSize.height / 2 - child.dy * s,
      0,
    );
    transform.value = m;
  }

  /// Pans the camera in scene space without changing zoom.
  void panVisibleByScene(Offset sceneDelta) {
    if (viewportSize == Size.zero) return;
    final s = scale.clamp(0.001, 100.0);
    final m = Matrix4.copy(transform.value);
    final t = m.getTranslation();
    m.setTranslationRaw(
      t.x - sceneDelta.dx * s,
      t.y - sceneDelta.dy * s,
      t.z,
    );
    transform.value = m;
  }

  void dispose() {
    transform.removeListener(_notify);
    transform.dispose();
  }
}

/// Axis-aligned bounds of all nodes including port gutters.
class GraphOverviewBounds {
  GraphOverviewBounds._(this.rect);

  final Rect rect;

  static GraphOverviewBounds forNodes(
    List<GraphNodeData> nodes, {
    double padding = 24,
    Rect? includeScene,
  }) {
    if (nodes.isEmpty) {
      var rect = const Rect.fromLTWH(0, 0, 240, 160);
      if (includeScene != null && !includeScene.isEmpty) {
        rect = rect.expandToInclude(includeScene);
      }
      return GraphOverviewBounds._(rect);
    }
    final side = GraphNodeVisual.horizontalPad;
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    for (final n in nodes) {
      minX = math.min(minX, n.x - side);
      minY = math.min(minY, n.y);
      maxX = math.max(maxX, n.x + n.resolvedWidth + side);
      maxY = math.max(maxY, n.y + n.resolvedHeight);
    }
    if (includeScene != null && !includeScene.isEmpty) {
      minX = math.min(minX, includeScene.left);
      minY = math.min(minY, includeScene.top);
      maxX = math.max(maxX, includeScene.right);
      maxY = math.max(maxY, includeScene.bottom);
    }
    return GraphOverviewBounds._(
      Rect.fromLTRB(
        minX - padding,
        minY - padding,
        maxX + padding,
        maxY + padding,
      ),
    );
  }

  Offset shift(Offset scenePoint) =>
      Offset(scenePoint.dx - rect.left, scenePoint.dy - rect.top);

  Rect shiftRect(Rect sceneRect) => Rect.fromLTWH(
        sceneRect.left - rect.left,
        sceneRect.top - rect.top,
        sceneRect.width,
        sceneRect.height,
      );
}