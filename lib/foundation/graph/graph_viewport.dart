import 'dart:math' as math;

import 'package:anoworld/foundation/graph/graph_edge_geometry.dart';
import 'package:anoworld/foundation/graph/graph_edge_painter.dart';
import 'package:anoworld/foundation/graph/graph_grid_painter.dart';
import 'package:anoworld/foundation/graph/graph_models.dart';
import 'package:anoworld/foundation/graph/graph_node_chip.dart';
import 'package:anoworld/foundation/graph/graph_viewport_controller.dart';
import 'package:anoworld/foundation/l10n/app_localizations.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_bottom_nav_icon_capsule.dart';
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
    this.onCopyNode,
    this.onDeleteNode,
    this.onAddNode,
    this.onArrange,
    this.onNodeDragEnd,
    this.showGrid = false,
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
  final ValueChanged<String>? onCopyNode;
  final ValueChanged<String>? onDeleteNode;

  /// Floating actions (canvas bottom-right, outside the pan/zoom layer).
  final VoidCallback? onAddNode;
  final VoidCallback? onArrange;
  final VoidCallback? onNodeDragEnd;

  /// Scene-aligned background grid with LOD spacing.
  final bool showGrid;

  /// When true, camera locks onto [selectedId] (centered + zoomed). Same graph.
  final bool focusSelected;
  final double minScale;
  final double maxScale;

  /// When set, pan/zoom state is owned here (for overview navigator sync).
  final GraphViewportController? camera;

  /// Space above layout y=0 for the selection action bar (child-space inset).
  static double get sceneTopInset =>
      AppCircleButton.diameter + AppTheme.spaceXs;

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
  String? _dragNodeId;
  int? _dragPointer;
  /// Scene-space pointer − node origin at pointer-down. Absolute tracking so
  /// multi-move frames never depend on a stale parent [GraphNodeData] layout.
  Offset? _dragGrabOffset;
  Size _viewportSize = Size.zero;
  late final AnimationController _focusAnim;
  Animation<Matrix4>? _focusTween;

  static const double _portHitRadius = 48;

  /// Slack kept beyond the furthest node so the last card is not glued to the
  /// edge of the pannable scene.
  static const double _contentMargin = 240;

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
    final child = _transform.toScene(box.globalToLocal(global));
    return Offset(child.dx, child.dy - GraphViewport.sceneTopInset);
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

  void _armNodeDrag({
    required String nodeId,
    required Offset globalPosition,
  }) {
    if (_linkFromId != null) return;
    final node = _byId[nodeId];
    final scene = _scenePoint(globalPosition);
    if (node == null || scene == null) return;
    _dragNodeId = nodeId;
    _dragGrabOffset = Offset(scene.dx - node.x, scene.dy - node.y);
    if (!_draggingNode) {
      setState(() => _draggingNode = true);
    }
  }

  void _onCanvasPointerDown(PointerDownEvent event) {
    if (_dragNodeId != null) {
      _dragPointer = event.pointer;
    }
  }

  void _onCanvasPointerMove(PointerMoveEvent event) {
    if (event.pointer != _dragPointer) return;
    final id = _dragNodeId;
    final grab = _dragGrabOffset;
    if (id == null || grab == null) return;
    final scene = _scenePoint(event.position);
    if (scene == null) return;
    // The scene starts at its top-left corner and grows right / down, so a
    // card dragged past that corner would sit outside the pannable child and
    // stop responding to taps. Keep every node inside the scene.
    widget.onMove(
      id,
      math.max(0, scene.dx - grab.dx),
      math.max(0, scene.dy - grab.dy),
    );
  }

  /// Size of the pan/zoom child: the viewport plus every node, so a big graph
  /// stays reachable instead of ending at a fixed margin.
  Size _contentExtent(Size viewport) {
    var right = viewport.width;
    var bottom = viewport.height;
    for (final node in widget.nodes) {
      right = math.max(
        right,
        node.x + node.resolvedWidth + GraphNodeChip.horizontalPad,
      );
      bottom = math.max(bottom, node.y + node.resolvedHeight);
    }
    return Size(right + _contentMargin, bottom + _contentMargin);
  }

  void _endNodeDrag({required bool commit}) {
    final id = _dragNodeId;
    final wasDragging = _draggingNode;
    if (_draggingNode || _dragGrabOffset != null || id != null) {
      setState(() {
        _draggingNode = false;
        _dragNodeId = null;
        _dragPointer = null;
        _dragGrabOffset = null;
      });
    }
    if (commit && wasDragging) {
      widget.onNodeDragEnd?.call();
    }
    if (commit &&
        widget.focusSelected &&
        id != null &&
        id == widget.selectedId) {
      _focusCamera(animate: true);
    }
  }

  void _onCanvasPointerUp(PointerUpEvent event) {
    if (event.pointer != _dragPointer) return;
    _endNodeDrag(commit: true);
  }

  void _onCanvasPointerCancel(PointerCancelEvent event) {
    if (event.pointer != _dragPointer) return;
    _endNodeDrag(commit: false);
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
    final cy = node.y + nh / 2 + GraphViewport.sceneTopInset;
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
          // Camera listeners rebuild the overview map; resize arrives mid-build
          // so publish it after the frame instead of marking widgets dirty.
          final camera = widget.camera;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            camera?.setViewportSize(nextSize);
            if (widget.focusSelected) _focusCamera(animate: false);
          });
        }
        final camera = widget.camera;
        if (camera != null &&
            camera.sceneTopInset != GraphViewport.sceneTopInset) {
          camera.sceneTopInset = GraphViewport.sceneTopInset;
        }
        final showEndActions =
            widget.onAddNode != null || widget.onArrange != null;
        final inset = GraphViewport.sceneTopInset;
        final content = _contentExtent(nextSize);

        return Stack(
          fit: StackFit.expand,
          children: [
            if (widget.showGrid)
              Positioned.fill(
                child: IgnorePointer(
                  child: ListenableBuilder(
                    listenable: _transform,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: GraphGridPainter(
                          transform: _transform.value,
                          color: theme.colorScheme.outline,
                        ),
                      );
                    },
                  ),
                ),
              ),
            Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: _onCanvasPointerDown,
              onPointerMove: _onCanvasPointerMove,
              onPointerUp: _onCanvasPointerUp,
              onPointerCancel: _onCanvasPointerCancel,
              child: GestureDetector(
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
                  // One viewport of slack on each side: every node can be
                  // brought to the middle, and the view has nowhere to get
                  // lost in.
                  boundaryMargin: EdgeInsets.symmetric(
                    horizontal: width,
                    vertical: height,
                  ),
                  child: SizedBox(
                    width: content.width,
                    height: content.height + inset,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: 0,
                          top: inset,
                          width: content.width,
                          height: content.height,
                          child: CustomPaint(
                            painter: GraphEdgePainter(
                              nodes: byId,
                              edges: widget.edges,
                              strokeColor: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.55),
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
                            top: node.y + inset,
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
                              onPanDown: (details) => _armNodeDrag(
                                nodeId: node.id,
                                globalPosition: details.globalPosition,
                              ),
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
                      ],
                    ),
                  ),
                ),
              ),
            ),
              if (widget.selectedId != null &&
                  (widget.onOpenNode != null ||
                      widget.onCopyNode != null ||
                      widget.onDeleteNode != null))
                ListenableBuilder(
                  listenable: _transform,
                  builder: (context, _) {
                    final node = byId[widget.selectedId!];
                    if (node == null) return const SizedBox.shrink();
                    // Overlay in viewport space: fixed chrome size (same as
                    // undo/redo). Align first button to the card left edge
                    // (node.x — not the port pad outside the block).
                    final cardTopLeft = MatrixUtils.transformPoint(
                      _transform.value,
                      Offset(node.x, node.y + inset),
                    );
                    return Positioned(
                      left: cardTopLeft.dx,
                      top: cardTopLeft.dy -
                          AppCircleButton.diameter -
                          AppTheme.spaceXs,
                      child: _SelectionActionBar(
                        nodeId: node.id,
                        onOpen: widget.onOpenNode,
                        onCopy: widget.onCopyNode,
                        onDelete: widget.onDeleteNode,
                      ),
                    );
                  },
                ),
              if (showEndActions)
                Positioned(
                  right: AppBottomChromeMetrics.graphEndActionsRight(),
                  bottom: AppTheme.spaceMd,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.onArrange != null) ...[
                        AppCircleButton.fab(
                          icon: Icons.dashboard_customize_outlined,
                          tooltip: context.ui.tidyLayout,
                          variant: AppCircleButtonVariant.ghost,
                          onPressed: widget.onArrange,
                        ),
                        if (widget.onAddNode != null)
                          const SizedBox(width: AppTheme.spaceSm),
                      ],
                      if (widget.onAddNode != null)
                        AppCircleButton.fab(
                          icon: Icons.add,
                          tooltip: context.ui.addStation,
                          variant: AppCircleButtonVariant.ghost,
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

class _SelectionActionBar extends StatelessWidget {
  const _SelectionActionBar({
    required this.nodeId,
    this.onOpen,
    this.onCopy,
    this.onDelete,
  });

  final String nodeId;
  final ValueChanged<String>? onOpen;
  final ValueChanged<String>? onCopy;
  final ValueChanged<String>? onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onCopy != null) ...[
          AppCircleButton(
            icon: Icons.copy_outlined,
            tooltip: context.ui.copy,
            onPressed: () => onCopy!(nodeId),
          ),
          if (onOpen != null || onDelete != null)
            const SizedBox(width: AppTheme.spaceSm),
        ],
        if (onOpen != null) ...[
          AppCircleButton(
            icon: Icons.edit_outlined,
            tooltip: context.ui.edit,
            onPressed: () => onOpen!(nodeId),
          ),
          if (onDelete != null) const SizedBox(width: AppTheme.spaceSm),
        ],
        if (onDelete != null)
          AppCircleButton(
            icon: Icons.delete_outline,
            tooltip: context.ui.delete,
            variant: AppCircleButtonVariant.danger,
            onPressed: () => onDelete!(nodeId),
          ),
      ],
    );
  }
}
