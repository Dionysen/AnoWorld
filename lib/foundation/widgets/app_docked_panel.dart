import 'dart:math' as math;

import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/theme/app_ui_tokens.dart';
import 'package:anoworld/foundation/widgets/app_sheet.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Floating card docked above the compact bottom nav (not a modal route).
///
/// Drag the handle (and optional [header]) to slide the panel; release past a
/// threshold or with a fling to dismiss, otherwise it springs back.
class AppDockedPanel extends StatefulWidget {
  const AppDockedPanel({
    super.key,
    required this.child,
    this.header,
    this.onDismiss,
    this.heightFactor = AppTheme.sheetHalfHeightFactor,
  });

  final Widget child;

  /// Optional title / chrome under the handle; also participates in drag.
  final Widget? header;
  final VoidCallback? onDismiss;
  final double heightFactor;

  @override
  State<AppDockedPanel> createState() => _AppDockedPanelState();
}

class _AppDockedPanelState extends State<AppDockedPanel>
    with SingleTickerProviderStateMixin {
  double _drag = 0;
  double _panelHeight = 0;
  late final AnimationController _settle;
  Animation<double>? _tween;

  @override
  void initState() {
    super.initState();
    _settle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    )..addListener(() {
        final tween = _tween;
        if (tween != null) {
          setState(() => _drag = tween.value);
        }
      });
  }

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  void _onDragStart() {
    _settle.stop();
    _tween = null;
  }

  void _onDragUpdate(double dy) {
    setState(() => _drag = math.max(0, _drag + dy));
  }

  Future<void> _animateTo(double target, {VoidCallback? onDone}) async {
    _tween = Tween<double>(begin: _drag, end: target).animate(
      CurvedAnimation(parent: _settle, curve: Curves.easeOutCubic),
    );
    await _settle.forward(from: 0);
    if (!mounted) return;
    setState(() => _drag = target);
    onDone?.call();
  }

  void _onDragEnd(double velocity) {
    final dismissible = widget.onDismiss != null;
    final h = _panelHeight > 0 ? _panelHeight : 280.0;
    final shouldDismiss =
        dismissible && (_drag > h * 0.28 || velocity > 700);
    if (shouldDismiss) {
      // ignore: unawaited_futures
      _animateTo(h + 48, onDone: widget.onDismiss);
    } else {
      // ignore: unawaited_futures
      _animateTo(0);
    }
  }

  Map<Type, GestureRecognizerFactory> _dragGestures() {
    return <Type, GestureRecognizerFactory>{
      _EagerVerticalDragGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<
              _EagerVerticalDragGestureRecognizer>(
        _EagerVerticalDragGestureRecognizer.new,
        (instance) {
          instance
            ..onStart = (_) {
              _onDragStart();
            }
            ..onUpdate = (details) {
              _onDragUpdate(details.delta.dy);
            }
            ..onEnd = (details) {
              _onDragEnd(details.primaryVelocity ?? 0);
            }
            ..onCancel = () {
              // ignore: unawaited_futures
              _animateTo(0);
            };
        },
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AppUiTokens.of(context);
    final media = MediaQuery.sizeOf(context);
    final width = math.min(
      AppTheme.sheetMaxWidth,
      media.width - AppTheme.sheetInset * 2,
    );
    final height = media.height * widget.heightFactor;
    _panelHeight = height;

    final fade = (1.0 - (_drag / math.max(height, 1)) * 0.35).clamp(0.55, 1.0);

    return Opacity(
      opacity: fade,
      child: Transform.translate(
        offset: Offset(0, _drag),
        child: Material(
          key: const ValueKey('app_docked_panel'),
          color: theme.colorScheme.surfaceContainerHigh,
          elevation: 0,
          shape: tokens.shape(
            side: BorderSide(color: theme.colorScheme.outline),
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: width,
            height: height,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RawGestureDetector(
                  behavior: HitTestBehavior.opaque,
                  gestures: _dragGestures(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AppSheetDragHandle(),
                      if (widget.header != null) widget.header!,
                    ],
                  ),
                ),
                Expanded(child: widget.child),
              ],
            ),
          ),
        ),
      ),
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
