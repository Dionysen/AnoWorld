import 'package:anoworld/foundation/graph/graph_edge_geometry.dart';
import 'package:anoworld/foundation/graph/graph_models.dart';
import 'package:anoworld/foundation/graph/graph_node_visual.dart';
import 'package:anoworld/foundation/graph/graph_port.dart';
import 'package:anoworld/foundation/l10n/app_localizations.dart';
import 'package:anoworld/foundation/theme/app_ui_tokens.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Selectable / draggable chip wrapping [GraphNodeVisual] for the canvas.
///
/// Body drag is armed here on pointer-down; [GraphViewport] tracks move/up at
/// the canvas layer so follow-hand survives chip rebuilds while the node moves.
class GraphNodeChip extends StatelessWidget {
  const GraphNodeChip({
    super.key,
    required this.data,
    required this.selected,
    required this.onTap,
    required this.onPanDown,
    this.highlightPorts = false,
    this.highlightInput = false,
    this.highlightOutputPortId,
    this.onOutputDragStart,
    this.onOutputDragUpdate,
    this.onOutputDragEnd,
    this.onOutputTap,
    this.onAddOutput,
  });

  final GraphNodeData data;
  final bool selected;
  final bool highlightPorts;
  final bool highlightInput;
  final String? highlightOutputPortId;
  final VoidCallback onTap;

  /// Pointer down on the card (before any slop) so the canvas can lock pan
  /// and take over move tracking.
  final GestureDragDownCallback onPanDown;
  final void Function(String portId)? onOutputDragStart;
  final GestureDragUpdateCallback? onOutputDragUpdate;
  final GestureDragEndCallback? onOutputDragEnd;
  final void Function(String portId)? onOutputTap;
  final VoidCallback? onAddOutput;

  static double get horizontalPad => GraphNodeVisual.horizontalPad;

  @override
  Widget build(BuildContext context) {
    final height = data.resolvedHeight;
    final width = data.resolvedWidth;
    final outputs = data.outputs.isEmpty
        ? const [GraphOutputPort.pendingPort]
        : data.outputs;

    final cardGestures = <Type, GestureRecognizerFactory>{
      TapGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
        TapGestureRecognizer.new,
        (instance) => instance.onTap = onTap,
      ),
    };

    return SizedBox(
      width: width + GraphPort.hitSize,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GraphNodeVisual(
            data: data,
            selected: selected,
            highlightPorts: highlightPorts,
            highlightInput: highlightInput,
            highlightOutputPortId: highlightOutputPortId,
            showPortTitles: false,
            showPortSockets: false,
          ),
          Positioned(
            left: horizontalPad,
            top: 0,
            width: width,
            height: height,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) {
                onPanDown(
                  DragDownDetails(
                    globalPosition: event.position,
                    localPosition: event.localPosition,
                  ),
                );
              },
              child: RawGestureDetector(
                behavior: HitTestBehavior.opaque,
                gestures: cardGestures,
                child: const ColoredBox(color: Color(0x00000000)),
              ),
            ),
          ),
          for (var i = 0; i < outputs.length; i++)
            Positioned(
              right: GraphPort.hitSize * 0.55,
              top: GraphEdgeGeometry.outputPortLocalY(
                    index: i,
                    count: outputs.length,
                    headerSubtitle: data.hasHeaderSubtitle,
                  ) -
                  GraphEdgeGeometry.portRowHeight / 2,
              height: GraphEdgeGeometry.portRowHeight,
              child: Center(
                child: _PortTitleButton(
                  key: ValueKey(
                    'graph_port_title_${data.id}_${outputs[i].id}',
                  ),
                  label: outputs[i].displayLabel(
                    emptyWired: context.ui.unnamed,
                    emptyPending: context.ui.add,
                  ),
                  pending: outputs[i].pending,
                  onPressed: outputs[i].pending
                      ? onAddOutput
                      : (onOutputTap == null
                          ? null
                          : () => onOutputTap!(outputs[i].id)),
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
              emphasized: highlightPorts || highlightInput || selected,
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
                emphasized: selected ||
                    highlightPorts ||
                    outputs[i].id == highlightOutputPortId,
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

class _PortTitleButton extends StatelessWidget {
  const _PortTitleButton({
    super.key,
    required this.label,
    required this.pending,
    this.onPressed,
  });

  final String label;
  final bool pending;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AppUiTokens.of(context);
    return Material(
      color: pending
          ? theme.colorScheme.surfaceContainerHigh
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.92),
      shape: tokens.shape(
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.45),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.clip,
            textAlign: TextAlign.right,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
          ),
        ),
      ),
    );
  }
}
