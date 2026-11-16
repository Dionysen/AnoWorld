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
    this.onTap,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shape = AppUiTokens.of(context).shape();
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: shape,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceMd,
            vertical: AppTheme.spaceSm + 2,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                        maxLines: 1,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppTheme.spaceSm),
                Flexible(
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: trailing!,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
