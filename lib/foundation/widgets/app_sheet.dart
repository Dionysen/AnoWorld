import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_ui_tokens.dart';
import 'app_button.dart';
import 'app_text.dart';

/// Default open height for [showAppSheet].
enum AppSheetSize {
  /// Shrink-wrap to content (menus, confirms). Capped at
  /// [AppTheme.sheetFullHeightFactor].
  compact,

  /// About half the screen; draggable up to [AppTheme.sheetFullHeightFactor].
  half,

  /// Nearly fill the screen (long lists).
  full,
}

/// App modal sheet — inset floating card used for every drawer.
///
/// Use [size] for the initial height: [AppSheetSize.half] / [AppSheetSize.full]
/// for fixed panes, [AppSheetSize.compact] for content-sized menus.
///
/// [AppSheetSize.half] opens at half height and can be dragged up to near-full
/// (same cap as [AppSheetSize.full]); snaps at half and full extents.
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
  final canExpand = heightFactor != null &&
      enableDrag &&
      heightFactor < AppTheme.sheetFullHeightFactor - 0.001;

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: enableDrag && !canExpand,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (sheetContext) {
      final dismissHostKey = GlobalKey<_AppSheetDismissHostState>();
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
      final horizontalInset = math.max(0.0, (screenW - cardWidth) / 2);

      Widget handle = const AppSheetDragHandle();
      if (!enableDrag) {
        handle = AppSheetDragToDismiss(child: handle);
      }

      Widget sheetBody;
      if (canExpand) {
        sheetBody = _ExpandableAppSheet(
          onRequestDismiss: () => dismissHostKey.currentState?.dismiss(),
          initialExtent: heightFactor!,
          maxExtent: AppTheme.sheetFullHeightFactor,
          horizontalInset: horizontalInset,
          bottomPad: bottomPad,
          screenHeight: screenH,
          theme: theme,
          tokens: tokens,
          cardWidth: cardWidth,
          handle: handle,
          builder: builder,
        );
      } else {
        final cardHeight =
            heightFactor == null ? null : screenH * heightFactor;

        sheetBody = Positioned(
          left: 0,
          right: 0,
          bottom: bottomPad,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: () {},
              child: _AppSheetCard(
                theme: theme,
                tokens: tokens,
                cardWidth: cardWidth,
                cardHeight: cardHeight,
                handle: handle,
                expandBody: cardHeight != null,
                child: builder(sheetContext),
              ),
            ),
          ),
        );
      }

      return AppSheetDismissHost(
        key: dismissHostKey,
        sheetContext: sheetContext,
        child: SizedBox(
          width: screenW,
          height: screenH,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => dismissHostKey.currentState?.dismiss(),
                ),
              ),
              sheetBody,
            ],
          ),
        ),
      );
    },
  );
}

/// Coordinates sheet dismiss (barrier, drag, back) with [AppSheetEditForm].
class AppSheetDismissHost extends StatefulWidget {
  const AppSheetDismissHost({
    super.key,
    required this.sheetContext,
    required this.child,
  });

  final BuildContext sheetContext;
  final Widget child;

  static _AppSheetDismissHostState? _stateOf(BuildContext context) =>
      context.findAncestorStateOfType<_AppSheetDismissHostState>();

  @override
  State<AppSheetDismissHost> createState() => _AppSheetDismissHostState();
}

class _DismissGuard {
  const _DismissGuard({
    this.blockPop = false,
    this.confirmDiscard,
  });

  final bool blockPop;
  final Future<bool> Function()? confirmDiscard;
}

class _AppSheetDismissHostState extends State<AppSheetDismissHost> {
  final ValueNotifier<_DismissGuard> _guard =
      ValueNotifier(const _DismissGuard());

  @override
  void dispose() {
    _guard.dispose();
    super.dispose();
  }

  void bindDismissGuard({
    required bool blockPop,
    required Future<bool> Function() confirmDiscard,
  }) {
    _guard.value = _DismissGuard(
      blockPop: blockPop,
      confirmDiscard: confirmDiscard,
    );
  }

  void unbindDismissGuard() {
    if (!_guard.value.blockPop && _guard.value.confirmDiscard == null) return;
    _guard.value = const _DismissGuard();
  }

  Future<void> dismiss() async {
    final guard = _guard.value;
    if (!guard.blockPop) {
      if (mounted) Navigator.of(widget.sheetContext).pop();
      return;
    }
    final confirm = guard.confirmDiscard;
    if (confirm == null) return;
    final discard = await confirm();
    if (discard && mounted) {
      Navigator.of(widget.sheetContext).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<_DismissGuard>(
      valueListenable: _guard,
      builder: (context, guard, child) {
        return PopScope(
          canPop: !guard.blockPop,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            dismiss();
          },
          child: child!,
        );
      },
      child: widget.child,
    );
  }
}

/// Half-height sheets: drag the handle to resize (desktop-friendly).
class _ExpandableAppSheet extends StatefulWidget {
  const _ExpandableAppSheet({
    required this.onRequestDismiss,
    required this.initialExtent,
    required this.maxExtent,
    required this.horizontalInset,
    required this.bottomPad,
    required this.screenHeight,
    required this.theme,
    required this.tokens,
    required this.cardWidth,
    required this.handle,
    required this.builder,
  });

  final VoidCallback? onRequestDismiss;
  final double initialExtent;
  final double maxExtent;
  final double horizontalInset;
  final double bottomPad;
  final double screenHeight;
  final ThemeData theme;
  final AppUiTokens tokens;
  final double cardWidth;
  final Widget handle;
  final WidgetBuilder builder;

  @override
  State<_ExpandableAppSheet> createState() => _ExpandableAppSheetState();
}

class _ExpandableAppSheetState extends State<_ExpandableAppSheet>
    with SingleTickerProviderStateMixin {
  static const double _minDismissExtent = 0.18;

  late double _extent;
  late final AnimationController _snapController;
  Animation<double>? _snapAnimation;

  @override
  void initState() {
    super.initState();
    _extent = widget.initialExtent;
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void dispose() {
    _snapAnimation?.removeListener(_onSnapTick);
    _snapController.dispose();
    super.dispose();
  }

  void _onSnapTick() {
    if (!mounted) return;
    final anim = _snapAnimation;
    if (anim == null) return;
    setState(() => _extent = anim.value);
  }

  double get _sheetHeight => widget.screenHeight * _extent;

  void _beginDrag() {
    _snapController.stop();
    _snapAnimation?.removeListener(_onSnapTick);
    _snapController.reset();
  }

  void _updateDrag(double deltaDy) {
    final delta = -deltaDy / widget.screenHeight;
    setState(() {
      _extent = (_extent + delta)
          .clamp(_minDismissExtent, widget.maxExtent);
    });
  }

  void _endDrag({double? flingVelocity}) {
    if (!mounted) return;
    final current = _extent;
    if (flingVelocity != null && flingVelocity < -700) {
      _snapTo(widget.maxExtent);
      return;
    }
    if (current < widget.initialExtent * 0.72 ||
        (flingVelocity != null && flingVelocity > 700)) {
      widget.onRequestDismiss?.call();
      return;
    }
    final snapTargets = [widget.initialExtent, widget.maxExtent];
    var nearest = snapTargets.first;
    var best = (current - nearest).abs();
    for (final target in snapTargets.skip(1)) {
      final delta = (current - target).abs();
      if (delta < best) {
        best = delta;
        nearest = target;
      }
    }
    if ((current - nearest).abs() < 0.015) {
      setState(() => _extent = nearest);
      return;
    }
    _snapTo(nearest);
  }

  void _snapTo(double target) {
    if (!mounted) return;
    if ((_extent - target).abs() < 0.01) {
      setState(() => _extent = target);
      return;
    }
    _snapController.stop();
    _snapAnimation?.removeListener(_onSnapTick);
    _snapAnimation = Tween<double>(begin: _extent, end: target).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.easeOutCubic),
    )..addListener(_onSnapTick);
    _snapController.forward(from: 0);
  }

  Widget _resizeHandle() {
    return _AppSheetVerticalDragChrome(
      onDragStart: _beginDrag,
      onDragUpdate: _updateDrag,
      onDragEnd: _endDrag,
      child: widget.handle,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.horizontalInset,
      right: widget.horizontalInset,
      bottom: widget.bottomPad,
      height: _sheetHeight,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          onTap: () {},
          child: _AppSheetCard(
            theme: widget.theme,
            tokens: widget.tokens,
            cardWidth: widget.cardWidth,
            handle: _resizeHandle(),
            expandBody: true,
            child: widget.builder(context),
          ),
        ),
      ),
    );
  }
}

/// Vertical drag chrome for expandable sheets (mouse / touch / trackpad).
///
/// Uses [Listener] so desktop mouse moves always reach the sheet, plus an
/// eager vertical recognizer when the platform provides drag events.
class _AppSheetVerticalDragChrome extends StatefulWidget {
  const _AppSheetVerticalDragChrome({
    required this.child,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final Widget child;
  final VoidCallback onDragStart;
  final ValueChanged<double> onDragUpdate;
  final void Function({double? flingVelocity}) onDragEnd;

  @override
  State<_AppSheetVerticalDragChrome> createState() =>
      _AppSheetVerticalDragChromeState();
}

class _AppSheetVerticalDragChromeState extends State<_AppSheetVerticalDragChrome> {
  static const double _minHitHeight = 48;

  int? _activePointer;
  double _lastPointerY = 0;
  double _flingSampleDy = 0;
  Duration? _flingSampleAt;

  void _pointerDown(PointerDownEvent event) {
    if (_activePointer != null) return;
    _activePointer = event.pointer;
    _lastPointerY = event.position.dy;
    _flingSampleDy = 0;
    _flingSampleAt = event.timeStamp;
    widget.onDragStart();
  }

  void _pointerMove(PointerMoveEvent event) {
    if (_activePointer != event.pointer) return;
    final dy = event.position.dy - _lastPointerY;
    _lastPointerY = event.position.dy;
    widget.onDragUpdate(dy);

    final now = event.timeStamp;
    final prev = _flingSampleAt;
    if (prev != null) {
      final dtMs = (now - prev).inMicroseconds / 1000.0;
      if (dtMs > 8) {
        _flingSampleDy = dy;
        _flingSampleAt = now;
      }
    } else {
      _flingSampleAt = now;
    }
  }

  void _pointerEnd(PointerEvent event) {
    if (_activePointer != event.pointer) return;
    _activePointer = null;
    final dtMs = _flingSampleAt == null
        ? 1.0
        : (event.timeStamp - _flingSampleAt!).inMicroseconds / 1000.0;
    final velocity =
        dtMs <= 0 ? 0.0 : (_flingSampleDy / dtMs) * 1000.0;
    widget.onDragEnd(flingVelocity: velocity);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      key: const ValueKey('app_sheet_resize'),
      behavior: HitTestBehavior.opaque,
      onPointerDown: _pointerDown,
      onPointerMove: _pointerMove,
      onPointerUp: _pointerEnd,
      onPointerCancel: _pointerEnd,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _minHitHeight),
        child: widget.child,
      ),
    );
  }
}

class _AppSheetCard extends StatelessWidget {
  const _AppSheetCard({
    required this.theme,
    required this.tokens,
    required this.cardWidth,
    required this.handle,
    required this.child,
    this.cardHeight,
    this.expandBody = false,
  });

  final ThemeData theme;
  final AppUiTokens tokens;
  final double cardWidth;
  final double? cardHeight;
  final Widget handle;
  final Widget child;
  final bool expandBody;

  @override
  Widget build(BuildContext context) {
    final stretchBody = expandBody || cardHeight != null;
    final column = Column(
      mainAxisSize: stretchBody ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        handle,
        if (stretchBody) Expanded(child: child) else child,
      ],
    );

    final surface = Material(
      key: const ValueKey('app_sheet_card'),
      color: theme.colorScheme.surfaceContainerHigh,
      elevation: 0,
      shape: tokens.shape(
        side: BorderSide(color: theme.colorScheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: column,
    );

    if (!stretchBody) {
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight:
              MediaQuery.sizeOf(context).height *
                  AppTheme.sheetFullHeightFactor,
          maxWidth: cardWidth,
        ),
        child: surface,
      );
    }
    if (cardHeight != null) {
      return SizedBox(
        width: cardWidth,
        height: cardHeight,
        child: surface,
      );
    }
    return SizedBox(width: cardWidth, height: double.infinity, child: surface);
  }
}

/// Body for resizable sheets ([AppSheetSize.half] / [AppSheetSize.full]).
///
/// With [footer], actions stay pinned at the bottom while the viewport is tall
/// enough; when the drawer is compressed, [footer] is appended to the list and
/// scrolls with [children].
class AppSheetScrollBody extends StatelessWidget {
  const AppSheetScrollBody({
    super.key,
    this.padding,
    required this.children,
    this.footer,
  });

  final EdgeInsetsGeometry? padding;
  final List<Widget> children;
  final List<Widget>? footer;

  static EdgeInsets defaultPadding() => const EdgeInsets.fromLTRB(
        AppTheme.pagePadding,
        AppTheme.spaceXs,
        AppTheme.pagePadding,
        AppTheme.spaceMd,
      );

  static EdgeInsets get pinnedListPadding => const EdgeInsets.fromLTRB(
        AppTheme.pagePadding,
        AppTheme.spaceXs,
        AppTheme.pagePadding,
        0,
      );

  static EdgeInsets get pinnedFooterPadding => const EdgeInsets.fromLTRB(
        AppTheme.pagePadding,
        AppTheme.spaceMd,
        AppTheme.pagePadding,
        AppTheme.spaceMd,
      );

  /// Tall enough to show [footer] pinned under a scrolling form region.
  static bool pinsFooter(BuildContext context, double viewportHeight) {
    final screenH = MediaQuery.sizeOf(context).height;
    return viewportHeight >=
        screenH * AppTheme.sheetHalfHeightFactor * 0.72;
  }

  @override
  Widget build(BuildContext context) {
    final footer = this.footer;
    if (footer == null || footer.isEmpty) {
      return ListView(
        padding: padding ?? defaultPadding(),
        children: children,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (pinsFooter(context, constraints.maxHeight)) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  padding: padding ?? pinnedListPadding,
                  children: children,
                ),
              ),
              Padding(
                padding: pinnedFooterPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: footer,
                ),
              ),
            ],
          );
        }
        return ListView(
          padding: padding ?? defaultPadding(),
          children: [
            ...children,
            const SizedBox(height: AppTheme.spaceMd),
            ...footer,
          ],
        );
      },
    );
  }
}

/// Half-sheet editor: title + top-right **保存**, dirty guard via
/// [AppSheetDismissHost].
class AppSheetEditForm extends StatefulWidget {
  const AppSheetEditForm({
    super.key,
    required this.title,
    required this.isDirty,
    required this.onSave,
    required this.body,
  });

  final String title;
  final bool isDirty;
  final VoidCallback onSave;
  final Widget body;

  @override
  State<AppSheetEditForm> createState() => _AppSheetEditFormState();
}

class _AppSheetEditFormState extends State<AppSheetEditForm> {
  _AppSheetDismissHostState? _dismissHost;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _dismissHost = AppSheetDismissHost._stateOf(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncDismissGuard();
    });
  }

  @override
  void didUpdateWidget(covariant AppSheetEditForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDirty != widget.isDirty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncDismissGuard();
      });
    }
  }

  @override
  void dispose() {
    _dismissHost?.unbindDismissGuard();
    super.dispose();
  }

  void _syncDismissGuard() {
    _dismissHost?.bindDismissGuard(
      blockPop: widget.isDirty,
      confirmDiscard: _confirmDiscard,
    );
  }

  Future<bool> _confirmDiscard() async {
    if (!widget.isDirty) return true;
    return showAppSheetDiscardEditsConfirm(context);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pagePadding,
            AppTheme.spaceXs,
            AppTheme.spaceSm,
            AppTheme.spaceSm,
          ),
          child: Row(
            children: [
              Expanded(
                child: AppText(widget.title, role: AppTextRole.subtitle),
              ),
              AppButton(
                label: '保存',
                variant: AppButtonVariant.ghost,
                onPressed: widget.isDirty ? widget.onSave : null,
              ),
            ],
          ),
        ),
        Expanded(child: widget.body),
      ],
    );
  }
}

/// Confirm discarding unsaved edits (compact sheet).
Future<bool> showAppSheetDiscardEditsConfirm(BuildContext context) async {
  return await showAppSheet<bool>(
        context: context,
        size: AppSheetSize.compact,
        builder: (sheetContext) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.pagePadding,
              AppTheme.spaceMd,
              AppTheme.pagePadding,
              AppTheme.spaceMd,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AppText('放弃这次修改？', role: AppTextRole.subtitle),
                const SizedBox(height: AppTheme.spaceSm),
                const AppText(
                  '还没保存的改动会丢掉',
                  role: AppTextRole.caption,
                ),
                const SizedBox(height: AppTheme.spaceMd),
                AppButton(
                  label: '继续编辑',
                  expanded: true,
                  onPressed: () => Navigator.of(sheetContext).pop(false),
                ),
                const SizedBox(height: AppTheme.spaceSm),
                AppButton(
                  label: '放弃',
                  expanded: true,
                  variant: AppButtonVariant.ghost,
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                ),
              ],
            ),
          );
        },
      ) ??
      false;
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