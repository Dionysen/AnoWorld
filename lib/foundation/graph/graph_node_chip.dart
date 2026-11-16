import 'package:anoworld/foundation/graph/graph_models.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/theme/app_ui_tokens.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Selectable / draggable chip for a graph node.
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
    final tokens = AppUiTokens.of(context);
    final border = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.outline;
    return SizedBox(
      width: data.width,
      height: data.height,
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        shape: tokens.shape(
          side: BorderSide(color: border, width: selected ? 2 : 1),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: RawGestureDetector(
                behavior: HitTestBehavior.opaque,
                gestures: <Type, GestureRecognizerFactory>{
                  TapGestureRecognizer:
                      GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                    TapGestureRecognizer.new,
                    (instance) => instance.onTap = onTap,
                  ),
                  _EagerPanGestureRecognizer: GestureRecognizerFactoryWithHandlers<
                      _EagerPanGestureRecognizer>(
                    _EagerPanGestureRecognizer.new,
                    (instance) {
                      instance
                        ..onUpdate = onPanUpdate
                        ..onEnd = onPanEnd;
                    },
                  ),
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spaceSm,
                    AppTheme.spaceXs,
                    AppTheme.spaceSm,
                    AppTheme.spaceXs,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        data.label,
                        role: AppTextRole.subtitle,
                        maxLines: 1,
                      ),
                      if (data.subtitle != null && data.subtitle!.isNotEmpty)
                        AppText(
                          data.subtitle!,
                          role: AppTextRole.caption,
                          maxLines: 2,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (onLinkStart != null)
              Positioned(
                right: 2,
                bottom: 2,
                child: GestureDetector(
                  onTap: onLinkStart,
                  child: Icon(
                    Icons.south_east,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
          ],
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
