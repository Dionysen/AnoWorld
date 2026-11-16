import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/theme/app_ui_tokens.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:flutter/material.dart';

/// Shared elevated node look for canvas chips and locked card mode.
///
/// No product vocabulary: callers pass [badgeLabel] / [badgeColor].
class GraphNodeCard extends StatelessWidget {
  const GraphNodeCard({
    super.key,
    required this.title,
    this.subtitle,
    this.badgeLabel,
    this.badgeColor,
    this.selected = false,
    this.elevated = true,
    this.width,
    this.titleMaxLines = 1,
    this.subtitleMaxLines = 2,
    this.footer,
    this.overlay,
  });

  final String title;
  final String? subtitle;
  final String? badgeLabel;
  final Color? badgeColor;
  final bool selected;
  final bool elevated;
  final double? width;
  final int titleMaxLines;
  final int subtitleMaxLines;

  /// Optional bottom hint inside the card (e.g. swipe caption).
  final Widget? footer;

  /// Stacked on top (e.g. link handle).
  final Widget? overlay;

  static const double badgeHeight = 28;
  static const double defaultWidth = 168;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AppUiTokens.of(context);
    final shape = tokens.shape(
      side: BorderSide(
        color: selected
            ? theme.colorScheme.primary
            : theme.colorScheme.outline.withValues(alpha: 0.55),
        width: selected ? 2 : 1,
      ),
    );
    final barColor = badgeColor ?? theme.colorScheme.primary;
    final hasBadge = badgeLabel != null && badgeLabel!.isNotEmpty;

    return SizedBox(
      width: width ?? defaultWidth,
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        elevation: elevated ? AppTheme.surfaceElevation : 0,
        shadowColor: theme.colorScheme.shadow.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.72 : 0.36,
        ),
        surfaceTintColor: Colors.transparent,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hasBadge)
                  ColoredBox(
                    color: barColor,
                    child: SizedBox(
                      height: badgeHeight,
                      child: Center(
                        child: Text(
                          badgeLabel!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: _onBadge(barColor),
                            fontWeight: FontWeight.w600,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spaceSm,
                    AppTheme.spaceSm,
                    AppTheme.spaceSm,
                    AppTheme.spaceSm,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        title,
                        role: AppTextRole.subtitle,
                        maxLines: titleMaxLines,
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: AppTheme.spaceXs),
                        AppText(
                          subtitle!,
                          role: AppTextRole.caption,
                          maxLines: subtitleMaxLines,
                        ),
                      ],
                      if (footer != null) ...[
                        const SizedBox(height: AppTheme.spaceSm),
                        footer!,
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (overlay != null) overlay!,
          ],
        ),
      ),
    );
  }

  static Color _onBadge(Color bar) {
    return bar.computeLuminance() > 0.45 ? Colors.black87 : Colors.white;
  }
}
