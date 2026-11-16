import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/theme/app_ui_tokens.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:flutter/material.dart';

/// Shared elevated node look (UE-style header + body).
///
/// Header shows [title] on [badgeColor]; optional [badgeLabel] is a trailing
/// chip. When [body] is set, [subtitle] sits under the title in the header;
/// otherwise [subtitle] fills the body (card / locked mode).
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
    this.subtitleMaxLines = 1,
    this.minHeight,
    this.body,
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
  final double? minHeight;
  final int titleMaxLines;
  final int subtitleMaxLines;

  /// Custom content under the header (e.g. port rows).
  final Widget? body;

  /// Optional bottom hint inside the card (e.g. swipe caption).
  final Widget? footer;

  /// Stacked on top (e.g. link handle).
  final Widget? overlay;

  static const double headerHeightCompact = 36;
  static const double headerHeightWithSubtitle = 50;
  static const double defaultWidth = 200;

  /// Legacy alias used by older call sites / docs.
  static const double badgeHeight = headerHeightCompact;

  static double headerHeight({bool hasSubtitle = false}) =>
      hasSubtitle ? headerHeightWithSubtitle : headerHeightCompact;

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
    final headerSubtitle = body != null &&
            subtitle != null &&
            subtitle!.trim().isNotEmpty
        ? subtitle
        : null;
    final headerH = headerHeight(hasSubtitle: headerSubtitle != null);

    return SizedBox(
      width: width ?? defaultWidth,
      height: minHeight,
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
              mainAxisSize:
                  minHeight == null ? MainAxisSize.min : MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(
                  height: headerH,
                  title: title,
                  subtitle: headerSubtitle,
                  badgeLabel: badgeLabel,
                  barColor: barColor,
                  titleMaxLines: titleMaxLines,
                  subtitleMaxLines: 1,
                ),
                if (minHeight != null)
                  Expanded(child: _bodyArea(context))
                else
                  _bodyArea(context),
              ],
            ),
            if (overlay != null) overlay!,
          ],
        ),
      ),
    );
  }

  Widget _bodyArea(BuildContext context) {
    if (body != null) return body!;
    final showSubtitle =
        subtitle != null && subtitle!.trim().isNotEmpty;
    return Padding(
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
          if (showSubtitle)
            AppText(
              subtitle!,
              role: AppTextRole.caption,
              maxLines: subtitleMaxLines,
            ),
          if (footer != null) ...[
            if (showSubtitle) const SizedBox(height: AppTheme.spaceSm),
            footer!,
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.height,
    required this.title,
    required this.barColor,
    this.subtitle,
    this.badgeLabel,
    this.titleMaxLines = 1,
    this.subtitleMaxLines = 1,
  });

  final double height;
  final String title;
  final String? subtitle;
  final String? badgeLabel;
  final Color barColor;
  final int titleMaxLines;
  final int subtitleMaxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onBar = _onBadge(barColor);
    final hasBadge = badgeLabel != null && badgeLabel!.isNotEmpty;

    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              barColor,
              Color.lerp(barColor, Colors.black, 0.45)!,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceSm),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: titleMaxLines,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: onBar,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    if (subtitle != null && subtitle!.trim().isNotEmpty)
                      Text(
                        subtitle!,
                        maxLines: subtitleMaxLines,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: onBar.withValues(alpha: 0.78),
                          fontStyle: FontStyle.italic,
                          height: 1.1,
                        ),
                      ),
                  ],
                ),
              ),
              if (hasBadge) ...[
                const SizedBox(width: AppTheme.spaceXs),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(AppTheme.spaceXs),
                  ),
                  child: Text(
                    badgeLabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: onBar,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static Color _onBadge(Color bar) {
    return bar.computeLuminance() > 0.45 ? Colors.black87 : Colors.white;
  }
}
