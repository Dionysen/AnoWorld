import 'dart:io';
import 'dart:math' as math;

import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/theme/app_ui_tokens.dart';
import 'package:anoworld/foundation/widgets/app_busy_indicator.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_image.dart';
import 'package:anoworld/foundation/widgets/app_image_viewer.dart';
import 'package:anoworld/foundation/widgets/app_surface.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:flutter/material.dart';

/// Compact image preview with optional regenerate action (create / graph / cast).
///
/// Tapping the picture opens the full-screen lightbox
/// ([showAppImageViewer]); pass [zoomable] false to keep it inert.
class VisualAssetPreview extends StatelessWidget {
  const VisualAssetPreview({
    super.key,
    required this.file,
    required this.emptyLabel,
    this.height = 140,
    this.aspectRatio,
    this.busy = false,
    this.actionLabel,
    this.onAction,
    this.deleteLabel,
    this.onDelete,
    this.fit = BoxFit.cover,
    this.zoomable = true,
    this.fitWidth = false,
    this.maxHeight,
  });

  final File? file;
  final String emptyLabel;

  /// Placeholder / loading height when the picture cannot be measured.
  final double height;
  final double? aspectRatio;
  final bool busy;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? deleteLabel;
  final VoidCallback? onDelete;
  final BoxFit fit;

  /// Whether tapping the picture opens the zoomable full-screen viewer.
  final bool zoomable;

  /// Size the picture to the content width at its own aspect ratio so the
  /// whole frame stays visible (no crop). Pair with [BoxFit.contain].
  final bool fitWidth;

  /// Upper bound for the picture height when [fitWidth] is set.
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = AppUiTokens.of(context);
    final imageFile = file;
    final path = imageFile?.path;
    // Regenerating a picture rewrites the same file, so the stamp keys both
    // the decode and the measured aspect ratio.
    final stamp = imageFile == null
        ? null
        : ValueKey(
            '${imageFile.path}-${AppImage.fileModifiedMicros(imageFile)}',
          );
    final picture = imageFile == null
        ? _Empty(label: emptyLabel)
        : AppImage(
            key: stamp,
            path: imageFile.path,
            fit: fit,
            fallback: _Empty(label: emptyLabel),
          );
    final tappable = path != null && zoomable
        ? MouseRegion(
            cursor: SystemMouseCursors.zoomIn,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => showAppImageViewer(
                context,
                path: path,
                label: emptyLabel,
              ),
              child: picture,
            ),
          )
        : picture;
    final sized = fitWidth && imageFile != null
        ? _FitWidthImage(
            key: stamp,
            file: imageFile,
            fallbackHeight: height,
            maxHeight: maxHeight,
            child: tappable,
          )
        : SizedBox(
            height: height,
            width: double.infinity,
            child: tappable,
          );
    final preview = ClipRRect(
      borderRadius: BorderRadius.circular(tokens.radius),
      child: ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: sized,
      ),
    );

    final framed = aspectRatio == null
        ? preview
        : AspectRatio(aspectRatio: aspectRatio!, child: preview);

    return AppSurface(
      padding: const EdgeInsets.all(AppTheme.spaceSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          framed,
          if (actionLabel != null) ...[
            const SizedBox(height: AppTheme.spaceSm),
            if (busy)
              const Center(child: AppBusyIndicator(size: 22))
            else if (onAction != null)
              AppButton(
                label: actionLabel!,
                onPressed: onAction,
                variant: AppButtonVariant.secondary,
                expanded: true,
              ),
          ],
          if (file != null && deleteLabel != null && onDelete != null) ...[
            const SizedBox(height: AppTheme.spaceSm),
            AppButton(
              label: deleteLabel!,
              onPressed: busy ? null : onDelete,
              variant: AppButtonVariant.danger,
              expanded: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        child: AppText(
          label,
          role: AppTextRole.caption,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// Content-width picture box that keeps the source file's own aspect ratio.
///
/// Falls back to [fallbackHeight] until the file decodes, and never grows past
/// [maxHeight] so a tall picture cannot crowd out the rest of the page.
class _FitWidthImage extends StatefulWidget {
  const _FitWidthImage({
    super.key,
    required this.file,
    required this.fallbackHeight,
    required this.maxHeight,
    required this.child,
  });

  final File file;
  final double fallbackHeight;
  final double? maxHeight;
  final Widget child;

  @override
  State<_FitWidthImage> createState() => _FitWidthImageState();
}

class _FitWidthImageState extends State<_FitWidthImage> {
  ImageStream? _stream;
  double? _ratio;

  late final ImageStreamListener _listener = ImageStreamListener(
    (info, _) => _onImage(info),
    onError: (_, _) {},
  );

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(_FitWidthImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final pathChanged = oldWidget.file.path != widget.file.path;
    final stampChanged = AppImage.fileModifiedMicros(oldWidget.file) !=
        AppImage.fileModifiedMicros(widget.file);
    if (pathChanged || stampChanged) {
      _detach();
      _ratio = null;
      _resolve();
    }
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  void _resolve() {
    final stream =
        stampedFileImage(widget.file).resolve(ImageConfiguration.empty);
    _stream = stream..addListener(_listener);
  }

  void _detach() {
    _stream?.removeListener(_listener);
    _stream = null;
  }

  void _onImage(ImageInfo info) {
    final height = info.image.height;
    if (height <= 0) return;
    final ratio = info.image.width / height;
    if (!mounted || _ratio == ratio) return;
    setState(() => _ratio = ratio);
  }

  @override
  Widget build(BuildContext context) {
    final ratio = _ratio;
    if (ratio == null || !ratio.isFinite || ratio <= 0) {
      return SizedBox(
        height: widget.fallbackHeight,
        width: double.infinity,
        child: widget.child,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final natural = width / ratio;
        final room = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : double.infinity;
        final maxHeight = widget.maxHeight;
        final cap = maxHeight == null ? room : math.min(maxHeight, room);
        // Unbounded parents (e.g. inside a column) need an explicit ceiling;
        // keep the placeholder height instead of overflowing.
        final height = cap.isFinite ? natural.clamp(0.0, cap) : widget.fallbackHeight;
        return SizedBox(
          width: double.infinity,
          height: height,
          child: widget.child,
        );
      },
    );
  }
}
