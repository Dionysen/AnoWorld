import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_ui_tokens.dart';
import 'app_text.dart';

/// Tappable row for lists. Visuals come from theme tokens only.
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

  static const double iconSize = 20;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shape = AppUiTokens.of(context).shape();
    final scheme = theme.colorScheme;
    final base = scheme.surfaceContainerHighest;
    final color = selected
        ? Color.alphaBlend(scheme.primary.withValues(alpha: 0.12), base)
        : base;
    return Material(
      color: color,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        customBorder: shape,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceMd,
            vertical: AppTheme.spaceSm + 2,
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
  }
}
