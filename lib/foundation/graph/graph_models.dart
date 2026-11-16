import 'dart:ui' show Offset;

/// Portable graph node placement (no product/business fields).
class GraphNodeData {
  const GraphNodeData({
    required this.id,
    required this.label,
    required this.x,
    required this.y,
    this.subtitle,
    this.width = 148,
    this.height = 64,
  });

  final String id;
  final String label;
  final String? subtitle;
  final double x;
  final double y;
  final double width;
  final double height;

  Offset get center => Offset(x + width / 2, y + height / 2);

  GraphNodeData copyWith({
    String? label,
    String? subtitle,
    double? x,
    double? y,
    double? width,
    double? height,
  }) {
    return GraphNodeData(
      id: id,
      label: label ?? this.label,
      subtitle: subtitle ?? this.subtitle,
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
