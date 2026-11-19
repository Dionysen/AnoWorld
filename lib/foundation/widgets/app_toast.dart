import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../frame/immersive_frame.dart';
import '../theme/app_theme.dart';
import '../theme/app_ui_tokens.dart';
import 'app_text.dart';

/// Top-centered floating notice (theme surface, clear of the chrome title band).
///
/// Not tappable. Swipe **left / right** to dismiss early. A new call
/// replaces any toast still showing on the same [Overlay].
void showAppToast(
  BuildContext context,
  String message, {
  Duration duration = AppTheme.toastDuration,
}) {
  final text = message.trim();
  if (text.isEmpty) return;

  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  _AppToastHost.show(
    overlay: overlay,
    message: text,
    duration: duration,
    theme: Theme.of(context),
    tokens: AppUiTokens.of(context),
    topInset: _toastTopInset(context),
  );
}

/// Chrome height without [dependOnInheritedWidget] (safe outside [build]).
double _toastTopInset(BuildContext context) {
  final scope = context.getInheritedWidgetOfExactType<ImmersiveScope>();
  final barHeight = scope?.metrics.barHeight ??
      MediaQuery.paddingOf(context).top +
          (Theme.of(context).appBarTheme.toolbarHeight ??
              AppTheme.titleBandHeight);
  return barHeight + AppTheme.toastTopGap;
}

/// Owns at most one toast [OverlayEntry] per [OverlayState].
final class _AppToastHost {
  _AppToastHost._();

  static final Expando<OverlayEntry> _entryByOverlay = Expando<OverlayEntry>();

  static void show({
    required OverlayState overlay,
    required String message,
    required Duration duration,
    required ThemeData theme,
    required AppUiTokens tokens,
    required double topInset,
  }) {
    _entryByOverlay[overlay]?.remove();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) {
        return _AppToastBanner(
          message: message,
          duration: duration,
          theme: theme,
          tokens: tokens,
          topInset: topInset,
          onDone: () {
            entry.remove();
            if (_entryByOverlay[overlay] == entry) {
              _entryByOverlay[overlay] = null;
            }
          },
        );
      },
    );
    _entryByOverlay[overlay] = entry;
    overlay.insert(entry);
  }
}

class _AppToastBanner extends StatefulWidget {
  const _AppToastBanner({
    required this.message,
    required this.duration,
    required this.theme,
    required this.tokens,
    required this.topInset,
    required this.onDone,
  });

  final String message;
  final Duration duration;
  final ThemeData theme;
  final AppUiTokens tokens;
  final double topInset;
  final VoidCallback onDone;

  @override
  State<_AppToastBanner> createState() => _AppToastBannerState();
}

class _AppToastBannerState extends State<_AppToastBanner>
    with TickerProviderStateMixin {
  static const _inDuration = Duration(milliseconds: 180);
  static const _outDuration = Duration(milliseconds: 160);
  static const _dismissDistance = 56.0;
  static const _flingSpeed = 700.0;

  late final AnimationController _enter;
  late final AnimationController _dragBack;
  late final Animation<double> _opacity;
  late final Animation<Offset> _enterSlide;

  Offset _drag = Offset.zero;
  Offset _dragFrom = Offset.zero;
  Timer? _hold;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(vsync: this, duration: _inDuration);
    _dragBack = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    _opacity = CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic);
    _enterSlide = Tween<Offset>(
      begin: const Offset(0, -0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic));
    _dragBack.addListener(() {
      if (!mounted) return;
      setState(() {
        _drag = Offset.lerp(_dragFrom, Offset.zero, _dragBack.value)!;
      });
    });
    _enter.forward();
    _armHold();
  }

  void _armHold() {
    _hold?.cancel();
    _hold = Timer(
      widget.duration,
      () => _dismiss(direction: const Offset(1, 0)),
    );
  }

  void _onPanStart(DragStartDetails _) {
    if (_closing) return;
    _hold?.cancel();
    _hold = null;
    _dragBack.stop();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_closing) return;
    // Horizontal only — ignore vertical drag.
    setState(() {
      _drag = Offset(_drag.dx + details.delta.dx, 0);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_closing) return;
    final vx = details.velocity.pixelsPerSecond.dx;
    final dismissLeft = _drag.dx <= -_dismissDistance || vx <= -_flingSpeed;
    final dismissRight = _drag.dx >= _dismissDistance || vx >= _flingSpeed;

    if (dismissLeft) {
      unawaited(_dismiss(direction: const Offset(-1, 0)));
      return;
    }
    if (dismissRight) {
      unawaited(_dismiss(direction: const Offset(1, 0)));
      return;
    }

    _dragFrom = _drag;
    _dragBack.forward(from: 0).whenComplete(() {
      if (mounted && !_closing) _armHold();
    });
  }

  Future<void> _dismiss({required Offset direction}) async {
    if (_closing) return;
    _closing = true;
    _hold?.cancel();
    _hold = null;
    _dragBack.stop();

    if (!mounted) {
      widget.onDone();
      return;
    }

    final size = MediaQuery.sizeOf(context);
    final travel = math.max(size.width, size.height);
    final target = Offset(direction.dx * travel, direction.dy * travel);
    final from = _drag;
    final controller = AnimationController(vsync: this, duration: _outDuration);
    final curved = CurvedAnimation(parent: controller, curve: Curves.easeInCubic);
    curved.addListener(() {
      if (!mounted) return;
      setState(() {
        _drag = Offset.lerp(from, target, curved.value)!;
      });
    });
    await controller.forward();
    controller.dispose();
    widget.onDone();
  }

  @override
  void dispose() {
    _hold?.cancel();
    _enter.dispose();
    _dragBack.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = widget.theme.colorScheme;
    final fill = scheme.surfaceContainerHigh;
    final shape = widget.tokens.shape(
      side: BorderSide(color: scheme.outline.withValues(alpha: 0.55)),
    );
    final dragOpacity = (1.0 - (_drag.distance / 180.0)).clamp(0.35, 1.0);

    return Positioned(
      top: widget.topInset,
      left: 0,
      right: 0,
      child: Align(
        alignment: Alignment.topCenter,
        child: SlideTransition(
          position: _enterSlide,
          child: FadeTransition(
            opacity: _opacity,
            child: Transform.translate(
              offset: _drag,
              child: Opacity(
                opacity: dragOpacity,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppTheme.toastMaxWidth,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.pagePadding,
                    ),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragStart: _onPanStart,
                      onHorizontalDragUpdate: _onPanUpdate,
                      onHorizontalDragEnd: _onPanEnd,
                      child: Material(
                        key: const ValueKey<String>('app_toast'),
                        color: fill,
                        elevation: AppTheme.toastElevation,
                        shadowColor: scheme.shadow.withValues(
                          alpha: widget.theme.brightness == Brightness.dark
                              ? 0.55
                              : 0.28,
                        ),
                        surfaceTintColor: Colors.transparent,
                        shape: shape,
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spaceMd,
                            vertical: AppTheme.spaceInline,
                          ),
                          child: AppText(
                            widget.message,
                            role: AppTextRole.body,
                            maxLines: 4,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
