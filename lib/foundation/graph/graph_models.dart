import 'dart:ui' show Color, Offset;

import 'package:anoworld/foundation/graph/graph_node_card.dart';

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
    this.width = GraphNodeCard.defaultWidth,
    this.height = 104,
  });

  final String id;
  final String label;
  final String? subtitle;
  final String? badgeLabel;
  final Color? badgeColor;
  final double x;
  final double y;
  final double width;
  final double height;

  Offset get center => Offset(x + width / 2, y + height / 2);

  GraphNodeData copyWith({
    String? label,
    String? subtitle,
    String? badgeLabel,
    Color? badgeColor,
    double? x,
    double? y,
    double? width,
    double? height,
    bool clearBadge = false,
  }) {
    return GraphNodeData(
      id: id,
      label: label ?? this.label,
      subtitle: subtitle ?? this.subtitle,
      badgeLabel: clearBadge ? null : (badgeLabel ?? this.badgeLabel),
      badgeColor: clearBadge ? null : (badgeColor ?? this.badgeColor),
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }
}

/// Edge between two node ids.
class GraphEdgeData {
  const GraphEdgeData({
    required this.id,
    required this.fromId,
    required this.toId,
    this.label,
    this.emphasized = false,
  });

  final String id;
  final String fromId;
  final String toId;
  final String? label;
  final bool emphasized;
}
