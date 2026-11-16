import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_ui_tokens.dart';

/// Default open height for [showAppSheet].
enum AppSheetSize {
  /// Shrink-wrap to content (menus, confirms). Capped at
  /// [AppTheme.sheetFullHeightFactor].
  compact,

  /// About half the screen.
  half,

  /// Nearly fill the screen (long lists).
  full,
}

/// App modal sheet — inset floating card used for every drawer.
///
/// Use [size] for the initial height: [AppSheetSize.half] / [AppSheetSize.full]
/// for fixed panes, [AppSheetSize.compact] for content-sized menus.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  AppSheetSize size = AppSheetSize.compact,
}) {
  final heightFactor = switch (size) {
    AppSheetSize.compact => null,
    AppSheetSize.half => AppTheme.sheetHalfHeightFactor,
    AppSheetSize.full => AppTheme.sheetFullHeightFactor,
  };

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
      final screenH = media.size.height;
      final screenW = media.size.width;
      final cardWidth = math.min(
        AppTheme.sheetMaxWidth,
        screenW - AppTheme.sheetInset * 2,
      );
      final cardHeight = heightFactor == null
          ? null
          : screenH * heightFactor;

      final card = Material(
        key: const ValueKey('app_sheet_card'),
        color: theme.colorScheme.surfaceContainerHigh,
        elevation: 0,
        shape: tokens.shape(
          side: BorderSide(color: theme.colorScheme.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: cardHeight == null
            ? ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: screenH * AppTheme.sheetFullHeightFactor,
                  maxWidth: cardWidth,
                ),
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
                width: cardWidth,
                height: cardHeight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _AppSheetDragHandle(),
                    Expanded(child: builder(sheetContext)),
                  ],
                ),
              ),
      );

      // Explicit full-screen host so half/full card heights are not collapsed
      // by the modal sheet's intrinsic sizing.
      return SizedBox(
        width: screenW,
        height: screenH,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.pop(sheetContext),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomPad,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: GestureDetector(
                  onTap: () {},
                  child: card,
                ),
              ),
            ),
          ],
        ),
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
