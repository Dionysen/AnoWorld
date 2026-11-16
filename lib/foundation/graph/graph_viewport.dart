import 'package:anoworld/foundation/graph/graph_edge_painter.dart';
import 'package:anoworld/foundation/graph/graph_models.dart';
import 'package:anoworld/foundation/graph/graph_node_chip.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:flutter/material.dart';

/// Pan/zoom canvas hosting [GraphNodeChip]s and painted edges.
class GraphViewport extends StatefulWidget {
  const GraphViewport({
    super.key,
    required this.nodes,
    required this.edges,
    required this.selectedId,
    required this.onSelect,
    required this.onMove,
    required this.onConnect,
    this.onOpenNode,
    this.minScale = 0.4,
    this.maxScale = 2.5,
  });

  final List<GraphNodeData> nodes;
  final List<GraphEdgeData> edges;
  final String? selectedId;
  final ValueChanged<String?> onSelect;
  final void Function(String id, double x, double y) onMove;
  final void Function(String fromId, String toId) onConnect;
  final ValueChanged<String>? onOpenNode;
  final double minScale;
  final double maxScale;

  @override
  State<GraphViewport> createState() => _GraphViewportState();
}

class _GraphViewportState extends State<GraphViewport> {
  final _transform = TransformationController();
  String? _linkFromId;
  Offset? _draftPointer;
  bool _draggingNode = false;

  Map<String, GraphNodeData> get _byId => {
        for (final n in widget.nodes) n.id: n,
      };

  void _clearLink() {
    setState(() {
      _linkFromId = null;
      _draftPointer = null;
    });
  }

  void _startLink(String id) {
    setState(() {
      _linkFromId = id;
      _draftPointer = _byId[id]?.center;
    });
  }

  void _onCanvasTap() {
    if (_linkFromId != null) {
      _clearLink();
      return;
    }
    widget.onSelect(null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byId = _byId;
    final draftFrom = _linkFromId == null ? null : byId[_linkFromId!]?.center;
    final canvasInteractive = !_draggingNode && _linkFromId == null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 800.0;
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 600.0;
        return ClipRect(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onCanvasTap,
            onPanUpdate: _linkFromId == null
                ? null
                : (details) {
                    setState(() => _draftPointer = details.localPosition);
                  },
            child: InteractiveViewer(
              transformationController: _transform,
              minScale: widget.minScale,
              maxScale: widget.maxScale,
              panEnabled: canvasInteractive,
              scaleEnabled: canvasInteractive,
              constrained: false,
              boundaryMargin: const EdgeInsets.all(800),
              child: SizedBox(
                width: width + 1200,
                height: height + 1200,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: GraphEdgePainter(
                          nodes: byId,
                          edges: widget.edges,
                          strokeColor: theme.colorScheme.outline,
                          emphasisColor: theme.colorScheme.primary,
                          labelStyle: theme.textTheme.labelSmall ??
                              const TextStyle(fontSize: 11),
                          draftFrom: draftFrom,
                          draftTo: _draftPointer,
                        ),
                      ),
                    ),
                    for (final node in widget.nodes)
                      Positioned(
                        left: node.x,
                        top: node.y,
                        child: GraphNodeChip(
                          data: node,
                          selected: node.id == widget.selectedId ||
                              node.id == _linkFromId,
                          onTap: () {
                            if (_linkFromId != null) {
                              if (_linkFromId != node.id) {
                                widget.onConnect(_linkFromId!, node.id);
                              }
                              _clearLink();
                              return;
                            }
                            widget.onSelect(node.id);
                          },
                          onPanUpdate: (details) {
                            if (!_draggingNode) {
                              setState(() => _draggingNode = true);
                            }
                            widget.onMove(
                              node.id,
                              node.x + details.delta.dx,
                              node.y + details.delta.dy,
                            );
                          },
                          onPanEnd: (_) {
                            if (_draggingNode) {
                              setState(() => _draggingNode = false);
                            }
                          },
                          onLinkStart: () => _startLink(node.id),
                        ),
                      ),
                    if (widget.selectedId != null && widget.onOpenNode != null)
                      Positioned(
                        left: (byId[widget.selectedId!]?.x ?? 0) + 8,
                        top: (byId[widget.selectedId!]?.y ?? 0) +
                            (byId[widget.selectedId!]?.height ?? 72) +
                            6,
                        child: AppButton(
                          label: '编辑',
                          variant: AppButtonVariant.secondary,
                          onPressed: () =>
                              widget.onOpenNode!(widget.selectedId!),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
