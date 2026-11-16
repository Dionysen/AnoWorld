import 'dart:math' as math;

import 'package:anoworld/foundation/graph/graph_edge_geometry.dart';
import 'package:anoworld/foundation/graph/graph_edge_painter.dart';
import 'package:anoworld/foundation/graph/graph_models.dart';
import 'package:anoworld/foundation/graph/graph_node_chip.dart';
import 'package:anoworld/foundation/graph/graph_viewport_controller.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_circle_button.dart';
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
    this.selectedEdgeId,
    this.onSelectEdge,
    this.onAddOutput,
    this.onOpenOutput,
    this.onOpenNode,
    this.onAddNode,
    this.onArrange,
    this.focusSelected = false,
    this.minScale = 0.4,
    this.maxScale = 2.5,
    this.camera,
  });

  final List<GraphNodeData> nodes;
  final List<GraphEdgeData> edges;
  final String? selectedId;
  final ValueChanged<String?> onSelect;
  final String? selectedEdgeId;
  final ValueChanged<String?>? onSelectEdge;
  final void Function(String id, double x, double y) onMove;

  /// [fromPortId] is an existing edge id to retarget, or [GraphOutputPort.pendingId].
  final void Function(String fromId, String toId, String fromPortId) onConnect;
  final ValueChanged<String>? onAddOutput;

  /// Open editor for a wired output port (edge id).
  final void Function(String nodeId, String portId)? onOpenOutput;
  final ValueChanged<String>? onOpenNode;

  /// Floating actions (canvas bottom-right, outside the pan/zoom layer).
  final VoidCallback? onAddNode;
  final VoidCallback? onArrange;

  /// When true, camera locks onto [selectedId] (centered + zoomed). Same graph.
  final bool focusSelected;
  final double minScale;
  final double maxScale;

  /// When set, pan/zoom state is owned here (for overview navigator sync).
  final GraphViewportController? camera;

  @override
  State<GraphViewport> createState() => _GraphViewportState();
}

class _GraphViewportState extends State<GraphViewport>
    with SingleTickerProviderStateMixin {
  TransformationController? _ownedTransform;
  final _viewerKey = GlobalKey();

  TransformationController get _transform =>
      widget.camera?.transform ?? _ownedTransform!;
  String? _linkFromId;
  String? _linkFromPortId;
  Offset? _draftPointer;
  bool _draggingNode = false;
  Size _viewportSize = Size.zero;
  late final AnimationController _focusAnim;
  Animation<Matrix4>? _focusTween;

  static const double _portHitRadius = 48;

  @override
  void initState() {
    super.initState();
    _ownedTransform ??= TransformationController();
    _focusAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
        final tween = _focusTween;
        if (tween != null) {
          _transform.value = tween.value;
        }
      });
  }

  @override
  void dispose() {
    _focusAnim.dispose();
    _ownedTransform?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant GraphViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    final focusChanged = oldWidget.focusSelected != widget.focusSelected;
    final selectionChanged = oldWidget.selectedId != widget.selectedId;
    final nodesMoved = oldWidget.nodes != widget.nodes;
    if (widget.focusSelected &&
        (focusChanged || selectionChanged || nodesMoved)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusCamera(animate: !focusChanged || selectionChanged);
      });
    } else if (!widget.focusSelected && focusChanged) {
      _animateTransform(Matrix4.identity());
    }
  }

  Offset? _scenePoint(Offset global) {
    final box = _viewerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    return _transform.toScene(box.globalToLocal(global));
  }

  Map<String, GraphNodeData> get _byId => {
        for (final n in widget.nodes) n.id: n,
      };

  GraphEdgeData? get _selectedEdge {
    final id = widget.selectedEdgeId;
    if (id == null) return null;
    for (final e in widget.edges) {
      if (e.id == id) return e;
    }
    return null;
  }

  void _clearLink() {
    setState(() {
      _linkFromId = null;
      _linkFromPortId = null;
      _draftPointer = null;
    });
  }

  void _selectNode(String? id) {
    widget.onSelect(id);
    widget.onSelectEdge?.call(null);
  }

  void _selectEdge(String? id) {
    widget.onSelectEdge?.call(id);
    if (id != null) widget.onSelect(null);
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
      _selectNode(nodeId);
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

  void _onCanvasTapUp(TapUpDetails details) {
    if (_linkFromId != null) {
      _clearLink();
      return;
    }
    final scene = _scenePoint(details.globalPosition);
    if (scene != null) {
      final edgeId = GraphEdgeGeometry.hitTestEdge(
        nodes: _byId,
        edges: widget.edges,
        point: scene,
      );
      if (edgeId != null) {
        _selectEdge(edgeId);
        return;
      }
    }
    if (!widget.focusSelected) {
      _selectNode(null);
    }
  }

  Matrix4 _matrixForNode(GraphNodeData node, Size viewport) {
    final nw = math.max(node.resolvedWidth, 1.0);
    final nh = math.max(node.resolvedHeight, 1.0);
    final scale = math
        .min(viewport.width * 0.72 / nw, viewport.height * 0.55 / nh)
        .clamp(widget.minScale, widget.maxScale);
    final cx = node.x + nw / 2;
    final cy = node.y + nh / 2;
    final tx = viewport.width / 2 - cx * scale;
    final ty = viewport.height / 2 - cy * scale;
    return Matrix4.identity()
      ..translateByDouble(tx, ty, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  void _animateTransform(Matrix4 target) {
    _focusTween = Matrix4Tween(
      begin: _transform.value.clone(),
      end: target,
    ).animate(CurvedAnimation(parent: _focusAnim, curve: Curves.easeOutCubic));
    _focusAnim.forward(from: 0);
  }

  void _focusCamera({required bool animate}) {
    if (!widget.focusSelected || _viewportSize == Size.zero) return;
    final id = widget.selectedId;
    if (id == null) return;
    final node = _byId[id];
    if (node == null) return;
    final target = _matrixForNode(node, _viewportSize);
    if (animate) {
      _animateTransform(target);
    } else {
      _focusAnim.stop();
      _transform.value = target;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byId = _byId;
    final selectedEdge = _selectedEdge;
    final draftFromNode =
        _linkFromId == null ? null : byId[_linkFromId!];
    final draftFrom = draftFromNode == null
        ? null
        : GraphEdgeGeometry.outputPort(
            draftFromNode,
            portId: _linkFromPortId,
          );
    final freeCamera = !widget.focusSelected;
    final canvasInteractive =
        freeCamera && !_draggingNode && _linkFromId == null;
    final linking = _linkFromId != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 800.0;
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 600.0;
        final nextSize = Size(width, height);
        if (nextSize != _viewportSize) {
          _viewportSize = nextSize;
          widget.camera?.setViewportSize(nextSize);
          if (widget.focusSelected) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _focusCamera(animate: false);
            });
          }
        }
        final selected = widget.selectedId == null
            ? null
            : byId[widget.selectedId!];
        final showCornerActions =
            widget.onAddNode != null || widget.onArrange != null;

        return Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: _onCanvasTapUp,
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
                              selectedEdgeId: widget.selectedEdgeId,
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
                              highlightPorts:
                                  linking && node.id != _linkFromId,
                              highlightInput:
                                  selectedEdge?.toId == node.id,
                              highlightOutputPortId:
                                  selectedEdge?.fromId == node.id
                                      ? (selectedEdge!.fromPortId ??
                                          selectedEdge.id)
                                      : null,
                              onTap: () => _selectNode(node.id),
                              onPanUpdate: (details) {
                                if (linking) return;
                                if (!_draggingNode) {
                                  setState(() => _draggingNode = true);
                                }
                                // Deltas are in the chip's local (scene) space.
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
                                if (widget.focusSelected &&
                                    node.id == widget.selectedId) {
                                  _focusCamera(animate: true);
                                }
                              },
                              onOutputDragStart: (portId) =>
                                  _onOutputDragStart(node.id, portId),
                              onOutputDragUpdate: _onOutputDragUpdate,
                              onOutputDragEnd: _onOutputDragEnd,
                              onOutputTap: widget.onOpenOutput == null
                                  ? null
                                  : (portId) => widget.onOpenOutput!(
                                        node.id,
                                        portId,
                                      ),
                              onAddOutput: widget.onAddOutput == null
                                  ? null
                                  : () => widget.onAddOutput!(node.id),
                            ),
                          ),
                        if (selected != null && widget.onOpenNode != null)
                          Positioned(
                            left: selected.x +
                                selected.resolvedWidth / 2 -
                                AppCircleButton.diameter / 2,
                            top: math.max(
                              0,
                              selected.y -
                                  AppCircleButton.diameter -
                                  AppTheme.spaceXs,
                            ),
                            child: AppCircleButton(
                              icon: Icons.edit_outlined,
                              tooltip: '编辑',
                              variant: AppCircleButtonVariant.tonal,
                              onPressed: () =>
                                  widget.onOpenNode!(selected.id),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (showCornerActions)
                Positioned(
                  right: AppTheme.spaceMd,
                  bottom: AppTheme.spaceMd,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.onArrange != null) ...[
                        AppCircleButton(
                          icon: Icons.dashboard_customize_outlined,
                          tooltip: '整理排版',
                          variant: AppCircleButtonVariant.tonal,
                          onPressed: widget.onArrange,
                        ),
                        if (widget.onAddNode != null)
                          const SizedBox(width: AppTheme.spaceSm),
                      ],
                      if (widget.onAddNode != null)
                        AppCircleButton(
                          icon: Icons.add,
                          tooltip: '加一站',
                          variant: AppCircleButtonVariant.tonal,
                          onPressed: widget.onAddNode,
                        ),
                    ],
                  ),
                ),
            ],
          );
      },
    );
  }
}
