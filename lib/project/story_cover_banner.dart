import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/foundation/widgets/app_image.dart';
import 'package:flutter/material.dart';

/// Story hub hero cover, resting look aligned with NativeTavern character detail.
///
/// Half-screen tall (from the window top when [AppPage.overlayTitle] extends the
/// body under chrome), [BoxFit.cover] cropped from the top, top scrim for the
/// overlay title and bottom fade into the page surface.
///
/// Optional [title] sits near the bottom (expanded FlexibleSpaceBar title) and
/// can fade / scale with [titleOpacity] / [titleScale] as the page scrolls.
class StoryCoverBanner extends StatelessWidget {
  const StoryCoverBanner({
    super.key,
    this.coverPath,
    this.title,
    this.titleOpacity = 1,
    this.titleScale = 1,
  });

  /// Absolute path to the cover file, if any.
  final String? coverPath;

  /// Expanded hero title drawn at the bottom of the cover.
  final String? title;

  /// 0–1 opacity for [title] (collapsed bar title cross-fades separately).
  final double titleOpacity;

  /// Scale for [title] while collapsing (1 = fully expanded).
  final double titleScale;

  /// Resting hero height as a fraction of the window (NT character detail).
  static const double restingHeightFraction = 0.5;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final height = MediaQuery.sizeOf(context).height * restingHeightFraction;
    final placeholder = _defaultBackground(scheme);
    final label = title?.trim();
    final showTitle = label != null && label.isNotEmpty && titleOpacity > 0;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (coverPath != null)
            AppImage(
              path: coverPath,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              fallback: placeholder,
            )
          else
            placeholder,
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  scheme.surface.withValues(alpha: 0.45),
                  Colors.transparent,
                  Colors.transparent,
                  scheme.surface.withValues(alpha: 0.85),
                ],
                stops: const [0, 0.22, 0.55, 1],
              ),
            ),
          ),
          if (showTitle)
            Positioned(
              left: AppTheme.pagePadding * 2.5,
              right: AppTheme.pagePadding * 2.5,
              bottom: AppTheme.spaceMd,
              child: Opacity(
                opacity: titleOpacity.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: titleScale.clamp(0.75, 1.15),
                  alignment: Alignment.bottomCenter,
                  child: AppText(
                    label,
                    role: AppTextRole.title,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static Widget _defaultBackground(ColorScheme scheme) {
    return ColoredBox(
      color: scheme.surfaceContainerHigh,
      child: Center(
        child: Icon(
          Icons.auto_stories_outlined,
          size: 120,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
