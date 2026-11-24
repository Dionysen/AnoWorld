import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';

/// Smooth press-in scale (sink) for tappable chrome.
///
/// Wrap a button / nav item so pointer down shrinks it and release restores
/// 1.0. Does not consume gestures; child [InkWell] / [GestureDetector] still
/// receive taps.
///
/// For wide list rows, pass a gentler [scaleX] (see
/// [AppTheme.pressScaleWideX]) so left/right gaps stay only slightly larger
/// than top/bottom instead of blowing out with a uniform scale.
class AppPressScale extends StatefulWidget {
  const AppPressScale({
    super.key,
    required this.child,
    this.enabled = true,
    this.scale = AppTheme.pressScale,
    this.scaleX,
    this.duration = AppTheme.pressScaleDuration,
  });

  final Widget child;
  final bool enabled;

  /// Vertical (and default horizontal) scale while pressed.
  final double scale;

  /// Horizontal scale while pressed. Defaults to [scale].
  final double? scaleX;

  final Duration duration;

  /// Key of the press [Transform] (for tests).
  static const transformKey = ValueKey<String>('app_press_scale_transform');

  @override
  State<AppPressScale> createState() => _AppPressScaleState();
}

class _AppPressScaleState extends State<AppPressScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!widget.enabled || _pressed == value) return;
    _pressed = value;
    if (!mounted) return;
    setState(() {});
  }

  @override
  void didUpdateWidget(covariant AppPressScale oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _pressed) {
      _pressed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pressed = widget.enabled && _pressed;
    final scaleY = widget.scale;
    final scaleX = widget.scaleX ?? scaleY;
    return Listener(
      behavior: HitTestBehavior.deferToChild,
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: TweenAnimationBuilder<double>(
        duration: widget.duration,
        curve: Curves.easeOutCubic,
        tween: Tween<double>(begin: 0, end: pressed ? 1 : 0),
        builder: (context, t, child) {
          return Transform.scale(
            key: AppPressScale.transformKey,
            scaleX: 1 + (scaleX - 1) * t,
            scaleY: 1 + (scaleY - 1) * t,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
