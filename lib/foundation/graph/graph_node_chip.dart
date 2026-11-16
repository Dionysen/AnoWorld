import 'package:anoworld/foundation/graph/graph_models.dart';
import 'package:anoworld/foundation/graph/graph_node_card.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Selectable / draggable chip wrapping [GraphNodeCard] for the canvas.
class GraphNodeChip extends StatelessWidget {
  const GraphNodeChip({
    super.key,
    required this.data,
    required this.selected,
    required this.onTap,
    required this.onPanUpdate,
    required this.onPanEnd,
    this.onLinkStart,
  });

  final GraphNodeData data;
  final bool selected;
  final VoidCallback onTap;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;
  final VoidCallback? onLinkStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: <Type, GestureRecognizerFactory>{
        TapGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
          TapGestureRecognizer.new,
          (instance) => instance.onTap = onTap,
        ),
        _EagerPanGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<_EagerPanGestureRecognizer>(
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
        overlay: onLinkStart == null
            ? null
            : Positioned(
                right: 4,
                bottom: 4,
                child: GestureDetector(
                  onTap: onLinkStart,
                  child: Icon(
                    Icons.south_east,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
      ),
    );
  }
}

/// Wins the arena against [InteractiveViewer] so node drag works.
class _EagerPanGestureRecognizer extends PanGestureRecognizer {
  @override
  void rejectGesture(int pointer) {
    acceptGesture(pointer);
  }

  @override
  String get debugDescription => 'eager pan';
}
