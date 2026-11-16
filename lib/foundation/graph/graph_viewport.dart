import 'package:anoworld/foundation/graph/graph_edge_geometry.dart';
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
    this.onAddOutput,
    this.onOpenNode,
    this.minScale = 0.4,
    this.maxScale = 2.5,
  });

  final List<GraphNodeData> nodes;
  final List<GraphEdgeData> edges;
  final String? selectedId;
  final ValueChanged<String?> onSelect;
  final void Function(String id, double x, double y) onMove;

  /// [fromPortId] is an existing edge id to retarget, or [GraphOutputPort.pendingId].
  final void Function(String fromId, String toId, String fromPortId) onConnect;
  final ValueChanged<String>? onAddOutput;
  final ValueChanged<String>? onOpenNode;
  final double minScale;
  final double maxScale;

  @override
  State<GraphViewport> createState() => _GraphViewportState();
}

class _GraphViewportState extends State<GraphViewport> {
  final _transform = TransformationController();
  final _viewerKey = GlobalKey();
  String? _linkFromId;
  String? _linkFromPortId;
  Offset? _draftPointer;
  bool _draggingNode = false;

  static const double _portHitRadius = 48;

  Offset? _scenePoint(Offset global) {
    final box = _viewerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    return _transform.toScene(box.globalToLocal(global));
  }

  Map<String, GraphNodeData> get _byId => {
        for (final n in widget.nodes) n.id: n,
      };

  void _clearLink() {
    setState(() {
      _linkFromId = null;
      _linkFromPortId = null;
      _draftPointer = null;
    });
  }

  String? _hitInputPort(Offset canvasPoint) {
    String? bestId;
    var bestDist = _portHitRadius;
    for (final node in widget.nodes) {
      if (node.id == _linkFromId) continue;
      final port = GraphEdgeGeometry.inputPort(node);
      final d = (port - canvasPoint).distance;
      if (d <= bestDist) {
        bestDist = d;
        bestId = node.id;
      }
    }
    return bestId;
  }

  void _onOutputDragStart(String nodeId, String portId) {
    final node = _byId[nodeId];
    setState(() {
      _linkFromId = nodeId;
      _linkFromPortId = portId;
      _draftPointer = node == null
          ? null
          : GraphEdgeGeometry.outputPort(node, portId: portId);
      widget.onSelect(nodeId);
    });
  }

  void _onOutputDragUpdate(DragUpdateDetails details) {
    final scene = _scenePoint(details.globalPosition);
    if (scene == null) return;
    setState(() => _draftPointer = scene);
  }

  void _onOutputDragEnd(DragEndDetails details) {
    final tip = _draftPointer;
    final fromId = _linkFromId;
    final fromPortId = _linkFromPortId;
    if (fromId != null && fromPortId != null && tip != null) {
      final toId = _hitInputPort(tip);
      if (toId != null) {
        widget.onConnect(fromId, toId, fromPortId);
      }
    }
    _clearLink();
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
    final draftFromNode =
        _linkFromId == null ? null : byId[_linkFromId!];
    final draftFrom = draftFromNode == null
        ? null
        : GraphEdgeGeometry.outputPort(
            draftFromNode,
            portId: _linkFromPortId,
          );
    final canvasInteractive = !_draggingNode && _linkFromId == null;
    final linking = _linkFromId != null;

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
            child: InteractiveViewer(
              key: _viewerKey,
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
                  clipBehavior: Clip.none,
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
                        left: node.x - GraphNodeChip.horizontalPad,
                        top: node.y,
                        child: GraphNodeChip(
                          data: node,
                          selected: node.id == widget.selectedId ||
                              node.id == _linkFromId,
                          highlightPorts: linking && node.id != _linkFromId,
                          onTap: () => widget.onSelect(node.id),
                          onPanUpdate: (details) {
                            if (linking) return;
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
                          onOutputDragStart: (portId) =>
                              _onOutputDragStart(node.id, portId),
                          onOutputDragUpdate: _onOutputDragUpdate,
                          onOutputDragEnd: _onOutputDragEnd,
                          onAddOutput: widget.onAddOutput == null
                              ? null
                              : () => widget.onAddOutput!(node.id),
                        ),
                      ),
                    if (widget.selectedId != null && widget.onOpenNode != null)
                      Positioned(
                        left: (byId[widget.selectedId!]?.x ?? 0) + 8,
                        top: (byId[widget.selectedId!]?.y ?? 0) +
                            (byId[widget.selectedId!]?.resolvedHeight ?? 72) +
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
