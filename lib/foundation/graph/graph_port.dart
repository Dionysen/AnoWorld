import 'package:flutter/material.dart';

enum GraphPortSide { input, output }

/// Visible socket on a graph node (UE-style pin with direction arrow).
class GraphPort extends StatelessWidget {
  const GraphPort({
    super.key,
    required this.side,
    this.emphasized = false,
    this.pending = false,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
    this.onTap,
  });

  final GraphPortSide side;
  final bool emphasized;
  final bool pending;
  final VoidCallback? onDragStart;
  final GestureDragUpdateCallback? onDragUpdate;
  final GestureDragEndCallback? onDragEnd;
  final VoidCallback? onTap;

  static const double size = 16;
  static const double hitSize = 28;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final muted = theme.colorScheme.outline;
    final fill = pending
        ? theme.colorScheme.surfaceContainerHighest
        : side == GraphPortSide.output
            ? (emphasized ? accent : accent.withValues(alpha: 0.9))
            : (emphasized
                ? accent.withValues(alpha: 0.4)
                : theme.colorScheme.surfaceContainerHighest);
    final border = emphasized || pending ? accent : muted;
    final iconColor = pending
        ? accent
        : side == GraphPortSide.output
            ? Colors.white
            : (emphasized ? accent : muted);

    final pin = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: Border.all(color: border, width: 2),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.35),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(
        pending ? Icons.add : Icons.play_arrow_rounded,
        size: pending ? 11 : 12,
        color: iconColor,
      ),
    );

    final canDrag =
        onDragStart != null || onDragUpdate != null || onDragEnd != null;

    Widget child = Center(child: pin);
    if (canDrag) {
      child = Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => onDragStart?.call(),
        onPointerMove: (event) {
          onDragUpdate?.call(
            DragUpdateDetails(
              globalPosition: event.position,
              delta: event.delta,
              localPosition: event.localPosition,
            ),
          );
        },
        onPointerUp: (_) => onDragEnd?.call(DragEndDetails()),
        onPointerCancel: (_) => onDragEnd?.call(DragEndDetails()),
        child: child,
      );
    } else if (onTap != null) {
      child = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: child,
      );
    }

    return SizedBox(width: hitSize, height: hitSize, child: child);
  }
}
