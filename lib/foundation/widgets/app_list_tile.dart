import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_list_hairline.dart';
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

  /// Hairline under the row. Turn off for the last item in a custom stack.
  final bool showDivider;

  static const double iconSize = 20;

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

    final row = Material(
      color: selected ? selectedFill : Colors.transparent,
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
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: AppTheme.spaceInline),
              ] else if (icon != null) ...[
                Icon(
                  icon,
                  size: iconSize,
                  color: scheme.onSurfaceVariant,
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
              if (trailing != null) ...[
                const SizedBox(width: AppTheme.spaceSm),
                trailing!,
              ],
            ],
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
