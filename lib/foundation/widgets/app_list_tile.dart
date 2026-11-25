import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/app_ui_tokens.dart';
import 'app_icon_button.dart';
import 'app_list_hairline.dart';
import 'app_press_scale.dart';
import 'app_text.dart';

/// Full-width tappable row (X-style): flat, no island card, hairline under the row.
///
/// Optional [onEdit] appends a trailing edit control after [trailing] (e.g.
/// disclosure / forward chevron + edit), matching story-detail section headers.
class AppListTile extends StatelessWidget {
  const AppListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.tags = const <String>[],
    this.icon,
    this.leading,
    this.onTap,
    this.onLongPress,
    this.onEdit,
    this.trailing,
    this.selected = false,
    this.nested = false,
    this.danger = false,
    this.showDivider = true,
  });

  final String title;
  final String? subtitle;

  /// Compact chips drawn after [title] on the same wrap run.
  final List<String> tags;
  final IconData? icon;

  /// When set, replaces [icon].
  final Widget? leading;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// When set, shows an edit icon after [trailing]; taps do not fire [onTap].
  final VoidCallback? onEdit;
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

  /// Soft estimate for the optional edit control.
  static const double _editEstimate = 36;

  /// Keep at least this much for the title column before hiding chrome.
  static const double _minTitleWidth = 48;

  AppListTile copyWith({
    String? title,
    String? subtitle,
    List<String>? tags,
    IconData? icon,
    Widget? leading,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    VoidCallback? onEdit,
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
      tags: tags ?? this.tags,
      icon: icon ?? this.icon,
      leading: leading ?? this.leading,
      onTap: onTap ?? this.onTap,
      onLongPress: onLongPress ?? this.onLongPress,
      onEdit: onEdit ?? this.onEdit,
      trailing: trailing ?? this.trailing,
      selected: selected ?? this.selected,
      nested: nested ?? this.nested,
      danger: danger ?? this.danger,
      showDivider: showDivider ?? this.showDivider,
    );
  }

  double _trailingReserve() {
    var width = 0.0;
    if (trailing != null) width += _trailingEstimate;
    if (onEdit != null) {
      if (trailing != null) width += AppTheme.spaceXs;
      width += _editEstimate;
    }
    if (width <= 0) return 0;
    return AppTheme.spaceSm + width;
  }

  Widget? _trailingCluster(BuildContext context) {
    if (trailing == null && onEdit == null) return null;
    final edit = onEdit == null
        ? null
        : AppIconButton(
            icon: Icons.edit_outlined,
            tooltip: context.ui.edit,
            size: _editEstimate,
            iconSize: iconSize,
            onPressed: onEdit,
          );
    if (trailing == null) return edit;
    if (edit == null) return trailing;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        trailing!,
        const SizedBox(width: AppTheme.spaceXs),
        edit,
      ],
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
    final trailingCluster = _trailingCluster(context);
    final trailingReserve = _trailingReserve();

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
                // Prefer title; drop trailing first, then leading.
                final showTrailing = trailingCluster != null &&
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
                          _TitleWithTags(
                            title: title,
                            tags: tags,
                            titleColor: emphasis,
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
                      trailingCluster,
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

class _TitleWithTags extends StatelessWidget {
  const _TitleWithTags({
    required this.title,
    required this.tags,
    this.titleColor,
  });

  final String title;
  final List<String> tags;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      for (final tag in tags)
        if (tag.trim().isNotEmpty) _ListTileTagChip(label: tag.trim()),
    ];
    if (chips.isEmpty) {
      return AppText(
        title,
        role: AppTextRole.subtitle,
        color: titleColor,
        maxLines: 1,
      );
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppTheme.spaceSm,
      runSpacing: AppTheme.spaceXs,
      children: [
        AppText(
          title,
          role: AppTextRole.subtitle,
          color: titleColor,
          maxLines: 1,
        ),
        ...chips,
      ],
    );
  }
}

class _ListTileTagChip extends StatelessWidget {
  const _ListTileTagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tagFill = Color.alphaBlend(
      scheme.primary.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.1 : 0.07,
      ),
      scheme.surface,
    );
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: tagFill,
        shape: AppUiTokens.of(context).shape(
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.16)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceSm,
          vertical: AppTheme.spaceXs,
        ),
        child: AppText(label, role: AppTextRole.compactTag),
      ),
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
