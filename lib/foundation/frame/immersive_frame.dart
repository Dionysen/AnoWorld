import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'window_channel.dart';
import 'window_controls.dart';

/// Makes system bars transparent so page content can extend into them.
void installImmersiveSystemUi() {
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );
}

/// Layout numbers the page shell reads. Platform checks stay in [ImmersiveFrame].
@immutable
final class ImmersiveMetrics {
  const ImmersiveMetrics({
    required this.active,
    required this.titleBarHeight,
    this.statusInset = 0,
    this.leadingInset = 0,
    this.trailingInset = 0,
    this.showsWindowControls = false,
    this.maximized = false,
  });

  /// System title bar is still present. The page draws a normal toolbar.
  static const ImmersiveMetrics system = ImmersiveMetrics(
    active: false,
    titleBarHeight: kToolbarHeight,
  );

  final bool active;
  final double titleBarHeight;
  final double statusInset;
  final double leadingInset;
  final double trailingInset;
  final bool showsWindowControls;
  final bool maximized;

  double get barHeight => statusInset + titleBarHeight;

  @override
  bool operator ==(Object other) {
    return other is ImmersiveMetrics &&
        active == other.active &&
        titleBarHeight == other.titleBarHeight &&
        statusInset == other.statusInset &&
        leadingInset == other.leadingInset &&
        trailingInset == other.trailingInset &&
        showsWindowControls == other.showsWindowControls &&
        maximized == other.maximized;
  }

  @override
  int get hashCode => Object.hash(
    active,
    titleBarHeight,
    statusInset,
    leadingInset,
    trailingInset,
    showsWindowControls,
    maximized,
  );
}

class ImmersiveScope extends InheritedWidget {
  const ImmersiveScope({
    super.key,
    required this.metrics,
    required super.child,
  });

  final ImmersiveMetrics metrics;

  static ImmersiveScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ImmersiveScope>();
  }

  static ImmersiveMetrics metricsOf(BuildContext context) {
    return maybeOf(context)?.metrics ??
        ImmersiveMetrics(
          active: false,
          titleBarHeight: kToolbarHeight,
          statusInset: MediaQuery.paddingOf(context).top,
        );
  }

  @override
  bool updateShouldNotify(ImmersiveScope oldWidget) =>
      metrics != oldWidget.metrics;
}

/// Hosts one immersive title band on every platform.
///
/// Mobile extends into the status bar. Desktop asks the runner to remove the
/// system title bar, then draws drag space and, on Windows and Linux, window
/// buttons. A missing channel keeps the system title bar.
class ImmersiveFrame extends StatefulWidget {
  const ImmersiveFrame({super.key, required this.child});

  final Widget child;

  @override
  State<ImmersiveFrame> createState() => _ImmersiveFrameState();
}

class _ImmersiveFrameState extends State<ImmersiveFrame> {
  static const _dragSlop = 4.0;

  bool _active = false;
  bool _maximized = false;
  double _titleBarHeight = kToolbarHeight;
  double _leadingInset = 0;
  int? _pointer;
  Offset? _down;
  bool _dragging = false;
  DateTime? _lastTapAt;
  Offset? _lastTapPosition;

  bool get _windows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  bool get _macOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  bool get _linux => !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;

  bool get _desktop => _windows || _macOS || _linux;

  @override
  void initState() {
    super.initState();
    if (!_desktop) {
      return;
    }
    WindowChannel.setHandler(_onMethodCall);
    _enable();
  }

  @override
  void dispose() {
    if (_desktop) {
      WindowChannel.setHandler(null);
    }
    super.dispose();
  }

  Future<Object?> _onMethodCall(MethodCall call) async {
    if (call.method == 'windowState' && mounted) {
      setState(() => _maximized = call.arguments == true);
    }
    return null;
  }

  Future<void> _enable() async {
    final enabled = await WindowChannel.immersiveTitleBar();
    if (!mounted || !enabled) {
      return;
    }
    if (_macOS) {
      final metrics = await WindowChannel.metrics();
      if (!mounted) {
        return;
      }
      final centerY = metrics?.centerY;
      if (centerY != null && centerY > 0) {
        _titleBarHeight = math.max(kToolbarHeight, centerY * 2);
      }
      final leading = metrics?.leading;
      _leadingInset = leading != null && leading > 0 ? leading : 80;
    }
    setState(() => _active = true);
  }

  ImmersiveMetrics _metrics(BuildContext context) {
    if (!_desktop) {
      return ImmersiveMetrics(
        active: true,
        titleBarHeight: kToolbarHeight,
        statusInset: MediaQuery.paddingOf(context).top,
      );
    }
    if (!_active) {
      return ImmersiveMetrics.system;
    }
    final controls = _windows || _linux;
    return ImmersiveMetrics(
      active: true,
      titleBarHeight: _titleBarHeight,
      leadingInset: _macOS ? _leadingInset : 0,
      trailingInset: controls ? WindowControlMetrics.stripWidth : 0,
      showsWindowControls: controls,
      maximized: _maximized,
    );
  }

  bool _onControl(Offset global) {
    try {
      final result = HitTestResult();
      GestureBinding.instance.hitTestInView(
        result,
        global,
        View.of(context).viewId,
      );
      for (final entry in result.path) {
        final target = entry.target;
        if (target is RenderEditable) {
          return true;
        }
        if (target is RenderSemanticsAnnotations) {
          final props = target.properties;
          if (props.button == true ||
              props.link == true ||
              props.textField == true ||
              props.slider == true) {
            return true;
          }
        }
      }
    } catch (_) {
      return false;
    }
    return false;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (!_active || event.position.dy >= _titleBarHeight) {
      return;
    }
    if (event.buttons != kPrimaryButton) {
      return;
    }
    if (_onControl(event.position)) {
      return;
    }
    _pointer = event.pointer;
    _down = event.position;
    _dragging = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    final down = _down;
    if (!_active || event.pointer != _pointer || down == null || _dragging) {
      return;
    }
    if ((event.position - down).distance < _dragSlop) {
      return;
    }
    _dragging = true;
    _lastTapAt = null;
    WindowChannel.startDragging();
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer != _pointer) {
      return;
    }
    final down = _down;
    final dragged = _dragging;
    _pointer = null;
    _down = null;
    _dragging = false;
    if (!_active || down == null || dragged) {
      return;
    }
    final now = DateTime.now();
    final last = _lastTapAt;
    final lastPosition = _lastTapPosition;
    if (last != null &&
        lastPosition != null &&
        now.difference(last) < const Duration(milliseconds: 350) &&
        (event.position - lastPosition).distance < 8) {
      _lastTapAt = null;
      _lastTapPosition = null;
      WindowChannel.toggleMaximize();
      return;
    }
    _lastTapAt = now;
    _lastTapPosition = event.position;
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer != _pointer) {
      return;
    }
    _pointer = null;
    _down = null;
    _dragging = false;
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _metrics(context);
    Widget child = widget.child;
    if (_active && _desktop) {
      child = Listener(
        behavior: HitTestBehavior.deferToChild,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        child: child,
      );
    }

    return ImmersiveScope(
      metrics: metrics,
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          if (metrics.showsWindowControls)
            Positioned(
              top: 0,
              right: 0,
              child: WindowControls(
                maximized: metrics.maximized,
                height: metrics.titleBarHeight,
                onMinimize: WindowChannel.minimize,
                onMaximize: WindowChannel.toggleMaximize,
                onClose: WindowChannel.close,
              ),
            ),
        ],
      ),
    );
  }
}
