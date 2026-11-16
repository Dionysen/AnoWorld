import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_ui_tokens.dart';

/// App modal sheet — inset floating card used for every drawer.
///
/// Pass [heightFactor] for scrollable lists (fixed fraction of screen height).
/// Omit it for compact menus / confirms (shrink-wrap, capped at
/// [AppTheme.sheetMaxHeightFactor]).
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double? heightFactor,
}) {
  assert(
    heightFactor == null || (heightFactor > 0 && heightFactor <= 1),
  );

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (sheetContext) {
      final media = MediaQuery.of(sheetContext);
      final theme = Theme.of(sheetContext);
      final tokens = AppUiTokens.of(sheetContext);
      final bottomPad = media.padding.bottom +
          AppTheme.sheetInset +
          media.viewInsets.bottom;
      final maxHeight = media.size.height *
          (heightFactor ?? AppTheme.sheetMaxHeightFactor);
      final fixedHeight =
          heightFactor == null ? null : media.size.height * heightFactor;

      final card = Material(
        color: theme.colorScheme.surfaceContainerHigh,
        elevation: 0,
        shape: tokens.shape(
          side: BorderSide(color: theme.colorScheme.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: fixedHeight == null
            ? ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _AppSheetDragHandle(),
                    Flexible(child: builder(sheetContext)),
                  ],
                ),
              )
            : SizedBox(
                height: fixedHeight,
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _AppSheetDragHandle(),
                    Expanded(child: builder(sheetContext)),
                  ],
                ),
              ),
      );

      return Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.pop(sheetContext),
            child: const SizedBox.expand(),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppTheme.sheetInset,
              0,
              AppTheme.sheetInset,
              bottomPad,
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppTheme.sheetMaxWidth,
                ),
                child: GestureDetector(
                  onTap: () {},
                  child: card,
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _AppSheetDragHandle extends StatelessWidget {
  const _AppSheetDragHandle();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.spaceSm),
      child: Center(
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
            shape: AppUiTokens.of(context).shape(),
          ),
          child: const SizedBox(width: 36, height: 4),
        ),
      ),
    );
  }
}
