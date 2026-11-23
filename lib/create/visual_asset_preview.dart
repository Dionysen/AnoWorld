import 'dart:io';

import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/theme/app_ui_tokens.dart';
import 'package:anoworld/foundation/widgets/app_busy_indicator.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
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
    this.fit = BoxFit.cover,
    this.zoomable = true,
  });

  final File? file;
  final String emptyLabel;
  final double height;
  final double? aspectRatio;
  final bool busy;
  final String? actionLabel;
  final VoidCallback? onAction;
  final BoxFit fit;

  /// Whether tapping the picture opens the zoomable full-screen viewer.
  final bool zoomable;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = AppUiTokens.of(context);
    final imageFile = file;
    final picture = imageFile == null
        ? _Empty(label: emptyLabel)
        : Image.file(
            imageFile,
            key: ValueKey(
              '${imageFile.path}-${imageFile.lastModifiedSync().millisecondsSinceEpoch}',
            ),
            fit: fit,
            alignment: Alignment.center,
            errorBuilder: (_, _, _) => _Empty(label: emptyLabel),
          );
    final path = imageFile?.path;
    final preview = ClipRRect(
      borderRadius: BorderRadius.circular(tokens.radius),
      child: ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: path != null && zoomable
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
              : picture,
        ),
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
