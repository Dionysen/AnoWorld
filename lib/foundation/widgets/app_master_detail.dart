import 'package:flutter/material.dart';

import '../layout/app_layout.dart';
import '../layout/app_pane_width.dart';
import '../theme/app_theme.dart';
import 'app_detail_pane.dart';
import 'app_text.dart';

/// List | detail host for wide windows.
///
/// - Narrower than [AppLayout.masterDetailContentMinWidth]: only [primary], so
///   the caller keeps its single-column behaviour (push a route on tap).
/// - Wide enough: [primary] + draggable divider + [detail]. A null [detail]
///   shows a faint [emptyLabel] watermark instead of dropping the pane, so the
///   list never jumps width while the selection changes.
///
/// [primary] is a widget instance rather than a builder: this widget listens to
/// [paneWidth] itself, and an unchanged `primary` lets Flutter skip rebuilding
/// the list on every drag frame. Callers decide wide/narrow with
/// [AppLayout.useMasterDetail] on the same constraints to pick tap behaviour.
///
/// [detail] is the selected item's **real page** — the same one a narrow window
/// would push — hosted in an [AppDetailPane], so pages opened from it stay in
/// the column and the list beside it is the way back.
///
/// [detail] must carry a key that identifies the selection ([detailKey]); the
/// pane uses it to remount, which is what drops a stack opened on the previous
/// item.
class AppMasterDetail extends StatelessWidget {
  const AppMasterDetail({
    super.key,
    required this.primary,
    required this.detail,
    required this.emptyLabel,
    required this.paneWidth,
    required this.detailController,
  });

  final Widget primary;

  /// Detail for the current selection; null shows [emptyLabel].
  final Widget? detail;

  final String emptyLabel;

  /// Shared divider position; dragged here, persisted on drag end.
  final AppPaneWidthController paneWidth;

  /// Owns the detail column's stack (back handling lives with the tab).
  final AppDetailPaneController detailController;

  @override
  Widget build(BuildContext context) {
    assert(
      detail == null || detail!.key != null,
      'AppMasterDetail.detail needs a key per selection, so switching items '
      'resets the detail column stack.',
    );
    return ListenableBuilder(
      listenable: paneWidth,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          final contentWidth = constraints.maxWidth;
          if (!AppLayout.useMasterDetail(contentWidth)) return primary;

          final theme = Theme.of(context);
          final scheme = theme.colorScheme;
          final width = AppLayout.clampMasterPaneWidth(
            desired: paneWidth.masterPaneWidth,
            contentWidth: contentWidth,
          );
          final dividerColor = theme.dividerColor.withValues(alpha: 0.5);

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ColoredBox(
                color: scheme.surfaceContainerLow,
                child: SizedBox(width: width, child: primary),
              ),
              _PaneResizeHandle(
                width: width,
                contentWidth: contentWidth,
                color: dividerColor,
                onChanged: paneWidth.setMasterPaneWidth,
                onSettled: paneWidth.persist,
              ),
              Expanded(
                child: ColoredBox(
                  color: scheme.surface,
                  child: detail == null
                      ? _EmptyDetailPane(message: emptyLabel)
                      : AppDetailPane(
                          key: detail!.key,
                          root: detail!,
                          controller: detailController,
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Faint centered watermark for an empty detail pane (not a blocking state).
class _EmptyDetailPane extends StatelessWidget {
  const _EmptyDetailPane({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.pagePadding,
          ),
          child: AppText(
            message,
            role: AppTextRole.title,
            textAlign: TextAlign.center,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.16),
          ),
        ),
      ),
    );
  }
}

/// 6px drag target with a hairline down its middle (a 1px divider is far too
/// thin to grab with a mouse).
class _PaneResizeHandle extends StatefulWidget {
  const _PaneResizeHandle({
    required this.width,
    required this.contentWidth,
    required this.color,
    required this.onChanged,
    this.onSettled,
  });

  final double width;
  final double contentWidth;
  final Color color;
  final ValueChanged<double> onChanged;
  final VoidCallback? onSettled;

  @override
  State<_PaneResizeHandle> createState() => _PaneResizeHandleState();
}

class _PaneResizeHandleState extends State<_PaneResizeHandle> {
  double? _startGlobalX;
  double? _startWidth;
  bool _hovered = false;

  void _endDrag() {
    _startGlobalX = null;
    _startWidth = null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        key: const ValueKey<String>('app_master_detail_handle'),
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (details) {
          _startGlobalX = details.globalPosition.dx;
          _startWidth = widget.width;
        },
        onHorizontalDragUpdate: (details) {
          final startX = _startGlobalX;
          final startWidth = _startWidth;
          if (startX == null || startWidth == null) return;
          widget.onChanged(
            AppLayout.clampMasterPaneWidth(
              desired: startWidth + (details.globalPosition.dx - startX),
              contentWidth: widget.contentWidth,
            ),
          );
        },
        onHorizontalDragEnd: (_) {
          _endDrag();
          widget.onSettled?.call();
        },
        onHorizontalDragCancel: _endDrag,
        child: SizedBox(
          width: AppLayout.paneResizeHandleWidth,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: _hovered ? 2 : 1,
              height: double.infinity,
              color: _hovered ? scheme.primary : widget.color,
            ),
          ),
        ),
      ),
    );
  }
}
