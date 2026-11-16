import 'dart:math' as math;

import 'package:flutter/gestures.dart';
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
///
/// Set [enableDrag] to false when the body needs vertical pan (e.g. map).
/// Then only [AppSheetDragToDismiss] regions (top handle, and any wrapped
/// title) can drag the sheet closed; system back / barrier tap still work.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  AppSheetSize size = AppSheetSize.compact,
  bool enableDrag = true,
}) {
  final heightFactor = switch (size) {
    AppSheetSize.compact => null,
    AppSheetSize.half => AppTheme.sheetHalfHeightFactor,
    AppSheetSize.full => AppTheme.sheetFullHeightFactor,
  };

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    enableDrag: enableDrag,
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
      final cardHeight =
          heightFactor == null ? null : screenH * heightFactor;

      Widget handle = const AppSheetDragHandle();
      if (!enableDrag) {
        handle = AppSheetDragToDismiss(child: handle);
      }

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
                    handle,
                    builder(sheetContext),
                  ],
                ),
              )
            : SizedBox(
                width: cardWidth,
                height: cardHeight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    handle,
                    Expanded(child: builder(sheetContext)),
                  ],
                ),
              ),
      );

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

/// Top grabber shared by modal sheets and [AppDockedPanel].
class AppSheetDragHandle extends StatelessWidget {
  const AppSheetDragHandle({super.key});

  static const double hitHeight = 28;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: hitHeight,
      width: double.infinity,
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

/// Vertical drag-down dismisses via [onDismiss], or pops the route if null.
///
/// Uses an eager vertical-drag recognizer so competing pans (map, scroll)
/// do not steal the handle / title chrome.
class AppSheetDragToDismiss extends StatefulWidget {
  const AppSheetDragToDismiss({
    super.key,
    required this.child,
    this.onDismiss,
  });

  final Widget child;
  final VoidCallback? onDismiss;

  @override
  State<AppSheetDragToDismiss> createState() => _AppSheetDragToDismissState();
}

class _AppSheetDragToDismissState extends State<AppSheetDragToDismiss> {
  double _dy = 0;

  void _dismiss() {
    final custom = widget.onDismiss;
    if (custom != null) {
      custom();
      return;
    }
    final nav = Navigator.of(context);
    if (nav.canPop()) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: <Type, GestureRecognizerFactory>{
        _EagerVerticalDragGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<
                _EagerVerticalDragGestureRecognizer>(
          _EagerVerticalDragGestureRecognizer.new,
          (instance) {
            instance
              ..onStart = (_) {
                _dy = 0;
              }
              ..onUpdate = (details) {
                _dy += details.delta.dy;
              }
              ..onEnd = (details) {
                final fling = details.primaryVelocity ?? 0;
                final shouldClose = _dy > 40 || fling > 600;
                _dy = 0;
                if (shouldClose) _dismiss();
              }
              ..onCancel = () {
                _dy = 0;
              };
          },
        ),
      },
      child: widget.child,
    );
  }
}

class _EagerVerticalDragGestureRecognizer
    extends VerticalDragGestureRecognizer {
  @override
  void rejectGesture(int pointer) {
    acceptGesture(pointer);
  }

  @override
  String get debugDescription => 'eager vertical drag';
}
