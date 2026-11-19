import 'dart:ui' show Color, Offset;

import 'package:anoworld/foundation/graph/graph_edge_geometry.dart';
import 'package:anoworld/foundation/graph/graph_port_title.dart';

/// One output socket on a node (may map to an existing edge, or a pending add).
class GraphOutputPort {
  const GraphOutputPort({
    required this.id,
    this.label,
    this.pending = false,
  });

  /// Stable id: edge id for wired sockets, [pendingId] for the add socket.
  final String id;
  final String? label;
  final bool pending;

  static const String pendingId = '__pending__';

  static const GraphOutputPort pendingPort = GraphOutputPort(
    id: pendingId,
    pending: true,
  );

  /// Neutral placeholder used only to measure unlabeled port width.
  static const String measureLabel = '0000';

  /// Canvas button text (max [GraphPortTitle.maxChars], then ellipsis).
  String displayLabel({
    required String emptyWired,
    required String emptyPending,
  }) {
    return GraphPortTitle.display(
      label,
      pending: pending,
      emptyWired: emptyWired,
      emptyPending: emptyPending,
    );
  }
}

/// Portable graph node placement (no product/business fields).
class GraphNodeData {
  const GraphNodeData({
    required this.id,
    required this.label,
    required this.x,
    required this.y,
    this.subtitle,
    this.badgeLabel,
    this.badgeColor,
    this.inputLabel,
    this.width,
    this.height,
    this.outputs = const [GraphOutputPort.pendingPort],
  });

  final String id;
  final String label;
  final String? subtitle;
  final String? badgeLabel;
  final Color? badgeColor;

  /// Label for the left input pin (shown in the first content row).
  final String? inputLabel;
  final double x;
  final double y;

  /// Explicit width; when null, derived from port title lengths.
  final double? width;
  final List<GraphOutputPort> outputs;

  /// Explicit height, or derived from [outputs] count.
  final double? height;

  bool get hasHeaderSubtitle =>
      subtitle != null && subtitle!.trim().isNotEmpty;

  double get resolvedHeight =>
      height ??
      GraphEdgeGeometry.heightForOutputCount(
        outputs.length,
        headerSubtitle: hasHeaderSubtitle,
      );

  double get resolvedWidth =>
      width ??
      GraphPortTitle.widthForTitles(
        [
          for (final port in (outputs.isEmpty
              ? const [GraphOutputPort.pendingPort]
              : outputs))
            port.displayLabel(
              emptyWired: GraphOutputPort.measureLabel,
              emptyPending: GraphOutputPort.measureLabel,
            ),
        ],
        hasInputLabel:
            inputLabel != null && inputLabel!.trim().isNotEmpty,
      );

  Offset get center =>
      Offset(x + resolvedWidth / 2, y + resolvedHeight / 2);

  GraphNodeData copyWith({
    String? label,
    String? subtitle,
    String? badgeLabel,
    Color? badgeColor,
    String? inputLabel,
    double? x,
    double? y,
    double? width,
    double? height,
    List<GraphOutputPort>? outputs,
    bool clearBadge = false,
    bool clearWidth = false,
  }) {
    return GraphNodeData(
      id: id,
      label: label ?? this.label,
      subtitle: subtitle ?? this.subtitle,
      badgeLabel: clearBadge ? null : (badgeLabel ?? this.badgeLabel),
      badgeColor: clearBadge ? null : (badgeColor ?? this.badgeColor),
      inputLabel: inputLabel ?? this.inputLabel,
      x: x ?? this.x,
      y: y ?? this.y,
      width: clearWidth ? null : (width ?? this.width),
      height: height ?? this.height,
      outputs: outputs ?? this.outputs,
    );
  }
}

/// Edge between two node ids.
class GraphEdgeData {
  const GraphEdgeData({
    required this.id,
    required this.fromId,
    required this.toId,
    this.fromPortId,
    this.label,
    this.emphasized = false,
  });

  final String id;
  final String fromId;
  final String toId;

  /// Which output socket on [fromId]; defaults to first / single port.
  final String? fromPortId;
  final String? label;
  final bool emphasized;
}
