import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_list_hairline.dart';
import 'app_press_scale.dart';
import 'app_text.dart';

/// Full-width tappable row (X-style): flat, no island card, hairline under the row.
class AppListTile extends StatelessWidget {
  const AppListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.leading,
    this.onTap,
    this.onLongPress,
    this.trailing,
    this.selected = false,
    this.nested = false,
    this.danger = false,
    this.showDivider = true,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;

  /// When set, replaces [icon].
  final Widget? leading;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;
  final bool selected;

  /// Secondary tier inside an expanded settings block (extra leading indent).
  final bool nested;

  /// Destructive row: icon + title use [ColorScheme.error].
  final bool danger;

  /// Hairline under the row. Turn off for the last item in a custom stack.
  final bool showDivider;

  static const double iconSize = 20;

  /// Soft estimate for a custom [leading] (cover / avatar) when deciding what
  /// to drop under tight width.
  static const double _leadingEstimate = 56;

  /// Soft estimate for [trailing] (more / chevron / checkbox).
  static const double _trailingEstimate = 40;

  /// Keep at least this much for the title column before hiding chrome.
  static const double _minTitleWidth = 48;

  AppListTile copyWith({
    String? title,
    String? subtitle,
    IconData? icon,
    Widget? leading,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    Widget? trailing,
    bool? selected,
    bool? nested,
    bool? danger,
    bool? showDivider,
  }) {
    return AppListTile(
      key: key,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      icon: icon ?? this.icon,
      leading: leading ?? this.leading,
      onTap: onTap ?? this.onTap,
      onLongPress: onLongPress ?? this.onLongPress,
      trailing: trailing ?? this.trailing,
      selected: selected ?? this.selected,
      nested: nested ?? this.nested,
      danger: danger ?? this.danger,
      showDivider: showDivider ?? this.showDivider,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selectedFill = Color.alphaBlend(
      scheme.primary.withValues(alpha: 0.12),
      scheme.surface,
    );
    final left = AppTheme.spaceMd + (nested ? AppTheme.spaceMd : 0);
    final emphasis = danger ? scheme.error : null;

    final row = Material(
      color: selected ? selectedFill : Colors.transparent,
      child: AppPressScale(
        enabled: onTap != null || onLongPress != null,
        scaleX: AppTheme.pressScaleWideX,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              left,
              AppTheme.spaceInline,
              AppTheme.spaceMd,
              AppTheme.spaceInline,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxW = constraints.maxWidth;
                final leadingReserve = leading != null
                    ? _leadingEstimate + AppTheme.spaceInline
                    : icon != null
                        ? iconSize + AppTheme.spaceInline
                        : 0.0;
                final trailingReserve = trailing != null
                    ? AppTheme.spaceSm + _trailingEstimate
                    : 0.0;
                // Prefer title; drop trailing first, then leading.
                final showTrailing = trailing != null &&
                    maxW >=
                        leadingReserve + _minTitleWidth + trailingReserve;
                final showLeading = (leading != null || icon != null) &&
                    maxW >= leadingReserve + _minTitleWidth;

                return Row(
                  children: [
                    if (showLeading && leading != null) ...[
                      leading!,
                      const SizedBox(width: AppTheme.spaceInline),
                    ] else if (showLeading && icon != null) ...[
                      Icon(
                        icon,
                        size: iconSize,
                        color: emphasis ?? scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppTheme.spaceInline),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppText(
                            title,
                            role: AppTextRole.subtitle,
                            color: emphasis,
                            maxLines: 1,
                          ),
                          if (subtitle != null && subtitle!.isNotEmpty) ...[
                            const SizedBox(height: AppTheme.spaceXs),
                            AppText(
                              subtitle!,
                              role: AppTextRole.caption,
                              maxLines: 2,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (showTrailing) ...[
                      const SizedBox(width: AppTheme.spaceSm),
                      trailing!,
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );

    if (!showDivider) return row;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row,
        const AppListHairline(),
      ],
    );
  }
}

/// Stacks [tiles] with hairlines only between rows (no vertical gaps).
class AppListTileStack extends StatelessWidget {
  const AppListTileStack({super.key, required this.tiles});

  final List<AppListTile> tiles;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < tiles.length; i++)
          tiles[i].copyWith(showDivider: i < tiles.length - 1),
      ],
    );
  }
}
