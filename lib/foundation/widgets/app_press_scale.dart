import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';

/// Smooth press-in scale (sink) for tappable chrome.
///
/// Wrap a button / nav item so pointer down shrinks it to
/// [AppTheme.pressScale] and release restores 1.0. Does not consume gestures;
/// child [InkWell] / [GestureDetector] still receive taps.
class AppPressScale extends StatefulWidget {
  const AppPressScale({
    super.key,
    required this.child,
    this.enabled = true,
    this.scale = AppTheme.pressScale,
    this.duration = AppTheme.pressScaleDuration,
  });

  final Widget child;
  final bool enabled;

  /// Scale while pressed. Defaults to [AppTheme.pressScale].
  final double scale;

  final Duration duration;

  @override
  State<AppPressScale> createState() => _AppPressScaleState();
}

class _AppPressScaleState extends State<AppPressScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted || !widget.enabled || _pressed == value) return;
    setState(() => _pressed = value);
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
    return Listener(
      behavior: HitTestBehavior.deferToChild,
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: widget.enabled && _pressed ? widget.scale : 1,
        duration: widget.duration,
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
