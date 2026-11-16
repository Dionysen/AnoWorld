import 'dart:math' as math;
import 'dart:typed_data';

import 'package:anoworld/foundation/graph/graph_edge_painter.dart';
import 'package:anoworld/foundation/graph/graph_models.dart';
import 'package:anoworld/foundation/graph/graph_node_visual.dart';
import 'package:anoworld/foundation/graph/graph_port.dart';
import 'package:flutter/material.dart';

/// Read-only bird's-eye view of a graph for picking a node.
class GraphOverviewMap extends StatelessWidget {
  const GraphOverviewMap({
    super.key,
    required this.nodes,
    required this.edges,
    this.thumbnails = const {},
    this.selectedId,
    this.onNodeTap,
    this.padding = 24,
  });

  final List<GraphNodeData> nodes;
  final List<GraphEdgeData> edges;
  final Map<String, Uint8List> thumbnails;
  final String? selectedId;
  final ValueChanged<String>? onNodeTap;
  final double padding;

  static Rect _bounds(List<GraphNodeData> nodes, double pad) {
    if (nodes.isEmpty) {
      return Rect.fromLTWH(0, 0, 240, 160);
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
    return Rect.fromLTRB(
      minX - pad,
      minY - pad,
      maxX + pad,
      maxY + pad,
    );
  }

  List<GraphNodeData> _shifted(Rect bounds) {
    final dx = -bounds.left;
    final dy = -bounds.top;
    return [
      for (final n in nodes)
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

  @override
  Widget build(BuildContext context) {
    if (nodes.isEmpty) {
      return const Center(child: Text('还没有情节站'));
    }

    final theme = Theme.of(context);
    final bounds = _bounds(nodes, padding);
    final shifted = _shifted(bounds);
    final byId = {for (final n in shifted) n.id: n};
    final size = Size(bounds.width, bounds.height);
    final chipPad = GraphNodeVisual.horizontalPad;

    return LayoutBuilder(
      builder: (context, constraints) {
        final fitScale = math.min(
          constraints.maxWidth / size.width,
          constraints.maxHeight / size.height,
        ).clamp(0.05, 4.0);

        return Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: InteractiveViewer(
                minScale: fitScale * 0.5,
                maxScale: math.max(2.5, fitScale * 3),
                constrained: false,
                boundaryMargin: const EdgeInsets.all(80),
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: GraphEdgePainter(
                            nodes: byId,
                            edges: edges,
                            strokeColor: theme.colorScheme.outline,
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
                            thumbnail: thumbnails[node.id],
                            selected: node.id == selectedId,
                            onTap: onNodeTap == null
                                ? null
                                : () => onNodeTap!(node.id),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OverviewNodeTile extends StatelessWidget {
  const _OverviewNodeTile({
    required this.node,
    required this.thumbnail,
    required this.selected,
    this.onTap,
  });

  final GraphNodeData node;
  final Uint8List? thumbnail;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget child;
    if (thumbnail != null) {
      child = Image.memory(
        thumbnail!,
        fit: BoxFit.fill,
        filterQuality: FilterQuality.medium,
      );
    } else {
      child = GraphNodeVisual(
        data: node,
        selected: selected,
      );
    }

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: selected
              ? BoxDecoration(
                  border: Border.all(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(4),
                )
              : const BoxDecoration(),
          child: child,
        ),
      ),
    );
  }
}