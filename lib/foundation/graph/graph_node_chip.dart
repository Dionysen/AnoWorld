import 'package:anoworld/foundation/graph/graph_edge_geometry.dart';
import 'package:anoworld/foundation/graph/graph_models.dart';
import 'package:anoworld/foundation/graph/graph_node_card.dart';
import 'package:anoworld/foundation/graph/graph_port.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Selectable / draggable chip wrapping [GraphNodeCard] for the canvas.
///
/// UE-style: colored header with title; ports live in the body with labels
/// horizontally aligned to each pin.
class GraphNodeChip extends StatelessWidget {
  const GraphNodeChip({
    super.key,
    required this.data,
    required this.selected,
    required this.onTap,
    required this.onPanUpdate,
    required this.onPanEnd,
    this.highlightPorts = false,
    this.onOutputDragStart,
    this.onOutputDragUpdate,
    this.onOutputDragEnd,
    this.onAddOutput,
  });

  final GraphNodeData data;
  final bool selected;
  final bool highlightPorts;
  final VoidCallback onTap;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;
  final void Function(String portId)? onOutputDragStart;
  final GestureDragUpdateCallback? onOutputDragUpdate;
  final GestureDragEndCallback? onOutputDragEnd;
  final VoidCallback? onAddOutput;

  static double get horizontalPad => GraphPort.hitSize / 2;

  @override
  Widget build(BuildContext context) {
    final height = data.resolvedHeight;
    final outputs = data.outputs.isEmpty
        ? const [GraphOutputPort.pendingPort]
        : data.outputs;
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.82),
      height: 1.1,
    );

    return SizedBox(
      width: data.width + GraphPort.hitSize,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: horizontalPad,
            top: 0,
            width: data.width,
            height: height,
            child: RawGestureDetector(
              behavior: HitTestBehavior.opaque,
              gestures: <Type, GestureRecognizerFactory>{
                TapGestureRecognizer: GestureRecognizerFactoryWithHandlers<
                    TapGestureRecognizer>(
                  TapGestureRecognizer.new,
                  (instance) => instance.onTap = onTap,
                ),
                _EagerPanGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                        _EagerPanGestureRecognizer>(
                  _EagerPanGestureRecognizer.new,
                  (instance) {
                    instance
                      ..onUpdate = onPanUpdate
                      ..onEnd = onPanEnd;
                  },
                ),
              },
              child: GraphNodeCard(
                title: data.label,
                subtitle: data.subtitle,
                badgeLabel: data.badgeLabel,
                badgeColor: data.badgeColor,
                selected: selected,
                elevated: true,
                width: data.width,
                minHeight: height,
                body: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: GraphEdgeGeometry.bodyPadV,
                    horizontal: AppTheme.spaceSm,
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < outputs.length; i++)
                        SizedBox(
                          height: GraphEdgeGeometry.portRowHeight,
                          child: Row(
                            children: [
                              Expanded(
                                child: i == 0 &&
                                        data.inputLabel != null &&
                                        data.inputLabel!.isNotEmpty
                                    ? Text(
                                        data.inputLabel!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: labelStyle,
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              const SizedBox(width: AppTheme.spaceXs),
                              Expanded(
                                child: Text(
                                  outputs[i].label ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                  style: labelStyle,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: GraphEdgeGeometry.inputPortLocalY(
                  headerSubtitle: data.hasHeaderSubtitle,
                ) -
                GraphPort.hitSize / 2,
            child: GraphPort(
              side: GraphPortSide.input,
              emphasized: highlightPorts || selected,
            ),
          ),
          for (var i = 0; i < outputs.length; i++)
            Positioned(
              right: 0,
              top: GraphEdgeGeometry.outputPortLocalY(
                    index: i,
                    count: outputs.length,
                    headerSubtitle: data.hasHeaderSubtitle,
                  ) -
                  GraphPort.hitSize / 2,
              child: GraphPort(
                key: ValueKey('graph_port_out_${data.id}_${outputs[i].id}'),
                side: GraphPortSide.output,
                pending: outputs[i].pending,
                emphasized: selected || highlightPorts,
                onDragStart: onOutputDragStart == null
                    ? null
                    : () => onOutputDragStart!(outputs[i].id),
                onDragUpdate: onOutputDragUpdate,
                onDragEnd: onOutputDragEnd,
                onTap: outputs[i].pending ? onAddOutput : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _EagerPanGestureRecognizer extends PanGestureRecognizer {
  @override
  void rejectGesture(int pointer) {
    acceptGesture(pointer);
  }

  @override
  String get debugDescription => 'eager pan';
}
