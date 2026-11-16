import 'package:anoworld/foundation/graph/graph_edge_geometry.dart';
import 'package:anoworld/foundation/graph/graph_models.dart';
import 'package:anoworld/foundation/graph/graph_node_card.dart';
import 'package:anoworld/foundation/graph/graph_port.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/theme/app_ui_tokens.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Selectable / draggable chip wrapping [GraphNodeCard] for the canvas.
///
/// UE-style: colored header with title; ports live in the body with labels
/// horizontally aligned to each pin. Output titles are tappable buttons.
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
    this.onOutputTap,
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

  /// Wired output title button (not pending).
  final void Function(String portId)? onOutputTap;
  final VoidCallback? onAddOutput;

  static double get horizontalPad => GraphPort.hitSize / 2;

  @override
  Widget build(BuildContext context) {
    final height = data.resolvedHeight;
    final width = data.resolvedWidth;
    final outputs = data.outputs.isEmpty
        ? const [GraphOutputPort.pendingPort]
        : data.outputs;
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.82),
      height: 1.1,
    );

    return SizedBox(
      width: width + GraphPort.hitSize,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: horizontalPad,
            top: 0,
            width: width,
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
                width: width,
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
                          child: Align(
                            alignment: Alignment.centerLeft,
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
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Title buttons sit above the card so taps are not stolen by pan.
          for (var i = 0; i < outputs.length; i++)
            Positioned(
              left: horizontalPad + AppTheme.spaceSm,
              right: GraphPort.hitSize * 0.55,
              top: GraphEdgeGeometry.outputPortLocalY(
                    index: i,
                    count: outputs.length,
                    headerSubtitle: data.hasHeaderSubtitle,
                  ) -
                  GraphEdgeGeometry.portRowHeight / 2,
              height: GraphEdgeGeometry.portRowHeight,
              child: Align(
                alignment: Alignment.centerRight,
                child: _PortTitleButton(
                  key: ValueKey(
                    'graph_port_title_${data.id}_${outputs[i].id}',
                  ),
                  label: outputs[i].displayLabel,
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

class _PortTitleButton extends StatelessWidget {
  const _PortTitleButton({
    super.key,
    required this.label,
    required this.pending,
    this.onPressed,
  });

  /// Already truncated via [GraphPortTitle.display].
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
            horizontal: AppTheme.spaceSm,
            vertical: AppTheme.spaceXs,
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

class _EagerPanGestureRecognizer extends PanGestureRecognizer {
  @override
  void rejectGesture(int pointer) {
    acceptGesture(pointer);
  }

  @override
  String get debugDescription => 'eager pan';
}
