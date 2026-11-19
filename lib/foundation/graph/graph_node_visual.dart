import 'package:anoworld/foundation/graph/graph_edge_geometry.dart';
import 'package:anoworld/foundation/graph/graph_models.dart';
import 'package:anoworld/foundation/graph/graph_node_card.dart';
import 'package:anoworld/foundation/graph/graph_port.dart';
import 'package:anoworld/foundation/l10n/app_localizations.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/theme/app_ui_tokens.dart';
import 'package:flutter/material.dart';

/// UE-style node appearance shared by the canvas chip, overview map, and
/// raster thumbnails (no gestures).
class GraphNodeVisual extends StatelessWidget {
  const GraphNodeVisual({
    super.key,
    required this.data,
    this.selected = false,
    this.highlightPorts = false,
    this.highlightInput = false,
    this.highlightOutputPortId,
    this.showPortTitles = true,
    this.showPortSockets = true,
  });

  final GraphNodeData data;
  final bool selected;
  final bool highlightPorts;
  final bool highlightInput;
  final String? highlightOutputPortId;

  /// Canvas chip draws its own interactive titles / sockets on top.
  final bool showPortTitles;
  final bool showPortSockets;

  static double get horizontalPad => GraphPort.hitSize / 2;

  static Size chipSize(GraphNodeData data) => Size(
        data.resolvedWidth + GraphPort.hitSize,
        data.resolvedHeight,
      );

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
          if (showPortTitles)
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
                  child: _PortTitleChip(
                    label: outputs[i].displayLabel(
                      emptyWired: context.ui.unnamed,
                      emptyPending: context.ui.add,
                    ),
                    pending: outputs[i].pending,
                  ),
                ),
              ),
          if (showPortSockets) ...[
            Positioned(
              left: 0,
              top: GraphEdgeGeometry.inputPortLocalY(
                    headerSubtitle: data.hasHeaderSubtitle,
                  ) -
                  GraphPort.hitSize / 2,
              child: IgnorePointer(
                child: GraphPort(
                  side: GraphPortSide.input,
                  emphasized: highlightPorts || highlightInput || selected,
                ),
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
                child: IgnorePointer(
                  child: GraphPort(
                    side: GraphPortSide.output,
                    pending: outputs[i].pending,
                    emphasized: selected ||
                        highlightPorts ||
                        outputs[i].id == highlightOutputPortId,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _PortTitleChip extends StatelessWidget {
  const _PortTitleChip({required this.label, required this.pending});

  final String label;
  final bool pending;

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
    );
  }
}