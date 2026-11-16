import 'dart:math' as math;

import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/theme/app_ui_tokens.dart';
import 'package:anoworld/foundation/widgets/app_sheet.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Floating card docked above the compact bottom nav (not a modal route).
///
/// Slides up quickly on open (no overshoot). Drag the handle / [header] to
/// follow the finger; release past a threshold or call [AppDockedPanelState.dismiss]
/// to slide down and then invoke [onDismiss].
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
  State<AppDockedPanel> createState() => AppDockedPanelState();
}

class AppDockedPanelState extends State<AppDockedPanel>
    with TickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 180);

  /// 0 = hidden below, 1 = fully shown.
  late final AnimationController _reveal;
  double _drag = 0;
  double _panelHeight = 0;
  bool _closing = false;
  bool _enterStarted = false;

  late final AnimationController _settle;
  Animation<double>? _dragTween;

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(
      vsync: this,
      duration: _duration,
      value: 0,
    )..addListener(() {
        if (mounted) setState(() {});
      });
    _settle = AnimationController(
      vsync: this,
      duration: _duration,
    )..addListener(() {
        final tween = _dragTween;
        if (tween != null && mounted) {
          setState(() => _drag = tween.value);
        }
      });
    WidgetsBinding.instance.addPostFrameCallback((_) => _startEnter());
  }

  @override
  void dispose() {
    _reveal.dispose();
    _settle.dispose();
    super.dispose();
  }

  void _startEnter() {
    if (!mounted || _enterStarted || _closing) return;
    _enterStarted = true;
    _reveal.animateTo(1, curve: Curves.easeOut);
  }

  double get _height {
    if (_panelHeight > 0) return _panelHeight;
    return MediaQuery.sizeOf(context).height * widget.heightFactor;
  }

  double get _offset => (1.0 - _reveal.value) * _height + _drag;

  /// Slides down, then calls [AppDockedPanel.onDismiss].
  Future<void> dismiss() async {
    if (_closing) return;
    _closing = true;
    _settle.stop();
    _dragTween = null;

    final h = _height;
    final visual = _offset.clamp(0.0, h + 48);
    _drag = 0;
    if (h > 0) {
      _reveal.value = (1.0 - visual / h).clamp(0.0, 1.0);
    }
    await _reveal.animateBack(0, curve: Curves.easeOut);
    if (!mounted) return;
    widget.onDismiss?.call();
  }

  void _onDragStart() {
    if (_closing) return;
    _settle.stop();
    _dragTween = null;
  }

  void _onDragUpdate(double dy) {
    if (_closing) return;
    setState(() => _drag = math.max(0, _drag + dy));
  }

  Future<void> _animateDragTo(double target, {VoidCallback? onDone}) async {
    _dragTween = Tween<double>(begin: _drag, end: target).animate(
      CurvedAnimation(parent: _settle, curve: Curves.easeOut),
    );
    await _settle.forward(from: 0);
    if (!mounted) return;
    setState(() => _drag = target);
    onDone?.call();
  }

  void _onDragEnd(double velocity) {
    if (_closing) return;
    final dismissible = widget.onDismiss != null;
    final h = _height;
    final shouldDismiss =
        dismissible && (_offset > h * 0.28 || velocity > 700);
    if (shouldDismiss) {
      // ignore: unawaited_futures
      dismiss();
    } else {
      // ignore: unawaited_futures
      _animateDragTo(0);
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
              _animateDragTo(0);
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

    final fade = (1.0 - (_offset / math.max(height, 1)) * 0.25).clamp(0.6, 1.0);

    return Opacity(
      opacity: fade,
      child: Transform.translate(
        offset: Offset(0, _offset),
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
