import 'dart:typed_data';

import 'package:anoworld/foundation/graph/graph_edge_painter.dart';
import 'package:anoworld/foundation/graph/graph_models.dart';
import 'package:anoworld/foundation/graph/graph_node_visual.dart';
import 'package:anoworld/foundation/graph/graph_port.dart';
import 'package:anoworld/foundation/graph/graph_viewport_controller.dart';
import 'package:flutter/material.dart';

/// Bird's-eye navigator: node thumbnails with a fixed center viewport frame.
///
/// Dragging the map pans the canvas camera so the frame always matches the
/// live canvas view (same aspect ratio as the screen viewport).
class GraphOverviewMap extends StatefulWidget {
  const GraphOverviewMap({
    super.key,
    required this.nodes,
    required this.edges,
    required this.camera,
    this.thumbnails = const {},
    this.padding = 24,
  });

  final List<GraphNodeData> nodes;
  final List<GraphEdgeData> edges;
  final GraphViewportController camera;
  final Map<String, Uint8List> thumbnails;
  final double padding;

  @override
  State<GraphOverviewMap> createState() => _GraphOverviewMapState();
}

class _GraphOverviewMapState extends State<GraphOverviewMap> {
  @override
  void initState() {
    super.initState();
    widget.camera.addListener(_onCamera);
  }

  @override
  void dispose() {
    widget.camera.removeListener();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant GraphOverviewMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.camera != widget.camera) {
      oldWidget.camera.removeListener();
      widget.camera.addListener(_onCamera);
    }
  }

  void _onCamera() {
    if (mounted) setState(() {});
  }

  List<GraphNodeData> _shifted(GraphOverviewBounds bounds) {
    final dx = -bounds.rect.left;
    final dy = -bounds.rect.top;
    return [
      for (final n in widget.nodes)
        GraphNodeData(
          id: n.id,
          label: n.label,
          x: n.x + dx,
          y: n.y + dy,
          width: n.width,
          height: n.height,
          subtitle: n.subtitle,
          badgeLabel: n.badgeLabel,
          badgeColor: n.badgeColor,
          inputLabel: n.inputLabel,
          outputs: n.outputs,
        ),
    ];
  }

  Size _viewportFallback(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Size(size.width, size.height);
  }

  Rect _centerFrame(Size area, double aspect) {
    final maxW = area.width * 0.72;
    final maxH = area.height * 0.72;
    var w = maxW;
    var h = w / aspect;
    if (h > maxH) {
      h = maxH;
      w = h * aspect;
    }
    return Rect.fromCenter(
      center: Offset(area.width / 2, area.height / 2),
      width: w,
      height: h,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.nodes.isEmpty) {
      return const Center(child: Text('还没有情节站'));
    }

    final theme = Theme.of(context);
    final bounds = GraphOverviewBounds.forNodes(
      widget.nodes,
      padding: widget.padding,
    );
    final shifted = _shifted(bounds);
    final byId = {for (final n in shifted) n.id: n};
    final mapSize = Size(bounds.rect.width, bounds.rect.height);
    final chipPad = GraphNodeVisual.horizontalPad;

    return LayoutBuilder(
      builder: (context, constraints) {
        final area = Size(constraints.maxWidth, constraints.maxHeight);
        if (widget.camera.viewportSize == Size.zero) {
          final fallback = _viewportFallback(context);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (widget.camera.viewportSize == Size.zero) {
              widget.camera.setViewportSize(fallback);
            }
          });
        }
        final vp = widget.camera.viewportSize == Size.zero
            ? _viewportFallback(context)
            : widget.camera.viewportSize;
        final aspect = vp.width / vp.height;
        final frame = _centerFrame(area, aspect);

        final viewScene = widget.camera.visibleSceneRect ??
            Rect.fromLTWH(
              bounds.rect.left,
              bounds.rect.top,
              vp.width,
              vp.height,
            );
        final viewLocal = bounds.shiftRect(viewScene);
        final mapScale = frame.width / viewLocal.width;

        final mapOffset = Offset(
          frame.left - viewLocal.left * mapScale,
          frame.top - viewLocal.top * mapScale,
        );

        return ClipRect(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (details) {
              widget.camera.panVisibleByScene(
                Offset(
                  -details.delta.dx / mapScale,
                  -details.delta.dy / mapScale,
                ),
              );
            },
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Transform.translate(
                  offset: mapOffset,
                  child: Transform.scale(
                    scale: mapScale,
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: mapSize.width,
                      height: mapSize.height,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: GraphEdgePainter(
                                nodes: byId,
                                edges: widget.edges,
                                strokeColor: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.55),
                                emphasisColor: theme.colorScheme.primary,
                                selectedEdgeId: null,
                              ),
                            ),
                          ),
                          for (final node in shifted)
                            Positioned(
                              left: node.x - chipPad,
                              top: node.y,
                              width: node.resolvedWidth + GraphPort.hitSize,
                              height: node.resolvedHeight,
                              child: _OverviewNodeTile(
                                node: node,
                                thumbnail: widget.thumbnails[node.id],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned.fromRect(
                  rect: frame,
                  child: const _ViewportFrame(
                    key: ValueKey('graph-overview-viewport-frame'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ViewportFrame extends StatelessWidget {
  const _ViewportFrame({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: accent, width: 2.5),
          color: accent.withValues(alpha: 0.18),
        ),
      ),
    );
  }
}

class _OverviewNodeTile extends StatelessWidget {
  const _OverviewNodeTile({
    required this.node,
    required this.thumbnail,
  });

  final GraphNodeData node;
  final Uint8List? thumbnail;

  @override
  Widget build(BuildContext context) {
    if (thumbnail != null) {
      return Image.memory(
        thumbnail!,
        fit: BoxFit.fill,
        filterQuality: FilterQuality.medium,
      );
    }
    return GraphNodeVisual(data: node);
  }
}
