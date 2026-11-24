import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../frame/immersive_frame.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'app_circle_button.dart';
import 'app_image.dart';
import 'app_text.dart';

/// Opens a full-screen lightbox for a local image.
///
/// The picture starts fitted to the screen; wheel / pinch / double-tap zoom in
/// on it. Tapping the dim area around it, the close button, back, or Esc
/// dismisses the viewer.
Future<void> showAppImageViewer(
  BuildContext context, {
  String? path,
  Uint8List? bytes,
  String? label,
}) {
  final hasPath = path != null && path.isNotEmpty;
  if (!hasPath && bytes == null) return Future<void>.value();
  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 160),
      reverseTransitionDuration: const Duration(milliseconds: 130),
      pageBuilder: (_, _, _) => AppImageViewer(
        path: path,
        bytes: bytes,
        label: label,
      ),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

/// Full-screen zoomable image surface used by [showAppImageViewer].
class AppImageViewer extends StatefulWidget {
  const AppImageViewer({
    super.key,
    this.path,
    this.bytes,
    this.label,
  });

  final String? path;
  final Uint8List? bytes;

  /// Accessibility label / failed-to-decode message.
  final String? label;

  @override
  State<AppImageViewer> createState() => _AppImageViewerState();
}

class _AppImageViewerState extends State<AppImageViewer>
    with SingleTickerProviderStateMixin {
  static const double _doubleTapScale = 2.6;

  final TransformationController _transform = TransformationController();
  late final AnimationController _zoom;
  Animation<Matrix4>? _zoomTween;
  Offset? _doubleTapPoint;

  @override
  void initState() {
    super.initState();
    _zoom = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    )..addListener(() {
        final tween = _zoomTween;
        if (tween == null) return;
        _transform.value = tween.value;
      });
  }

  @override
  void dispose() {
    _zoom.dispose();
    _transform.dispose();
    super.dispose();
  }

  bool get _zoomed => _transform.value.getMaxScaleOnAxis() > 1.01;

  void _toggleZoom() {
    final point = _doubleTapPoint;
    if (point == null) return;
    final Matrix4 target;
    if (_zoomed) {
      target = Matrix4.identity();
    } else {
      target = Matrix4.identity()
        ..translateByDouble(
          -point.dx * (_doubleTapScale - 1),
          -point.dy * (_doubleTapScale - 1),
          0,
          1,
        )
        ..scaleByDouble(_doubleTapScale, _doubleTapScale, _doubleTapScale, 1);
    }
    _zoomTween = Matrix4Tween(begin: _transform.value, end: target).animate(
      CurvedAnimation(parent: _zoom, curve: Curves.easeOutCubic),
    );
    _zoom.forward(from: 0);
  }

  void _close() => Navigator.of(context).maybePop();

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      _close();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  ImageProvider? _provider() {
    final bytes = widget.bytes;
    if (bytes != null) return MemoryImage(bytes);
    final path = widget.path;
    if (path == null || path.isEmpty) return null;
    return stampedFileImage(File(path));
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.ui;
    final media = MediaQuery.of(context);
    // Keep the close button out of the window title band / status bar.
    final chromeBottom = ImmersiveScope.metricsOf(context).barHeight;
    final provider = _provider();
    final image = provider == null
        ? const SizedBox.shrink()
        : Image(
            image: provider,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, _, _) => Center(
              child: AppText(
                widget.label ?? strings.emptyContent,
                role: AppTextRole.caption,
                color: Colors.white70,
              ),
            ),
          );

    return Material(
      type: MaterialType.transparency,
      child: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Tap anywhere outside the gesture surface closes the viewer.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
              child: const ColoredBox(color: Color(0xE6000000)),
            ),
            SafeArea(
              // One tap closes (browser-style); double-tap zooms at the point.
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _close,
                onDoubleTapDown: (details) =>
                    _doubleTapPoint = details.localPosition,
                onDoubleTap: _toggleZoom,
                child: InteractiveViewer(
                  transformationController: _transform,
                  minScale: 1,
                  maxScale: 6,
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spaceMd),
                    child: image,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Padding(
                padding: EdgeInsets.only(
                  top: chromeBottom + AppTheme.spaceSm,
                  right: AppTheme.spaceSm + media.padding.right,
                ),
                child: AppCircleButton(
                  icon: Icons.close,
                  tooltip: strings.closePreview,
                  variant: AppCircleButtonVariant.filled,
                  onPressed: _close,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              // The hint must not eat the tap that closes the viewer.
              child: IgnorePointer(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: AppTheme.spaceMd + media.padding.left,
                    right: AppTheme.spaceMd + media.padding.right,
                    bottom: AppTheme.spaceMd + media.padding.bottom,
                  ),
                  child: AppText(
                    strings.zoomHint,
                    role: AppTextRole.caption,
                    color: Colors.white70,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
