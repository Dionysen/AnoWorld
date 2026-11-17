import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_disclosure_icon.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_surface.dart';
import 'package:flutter/material.dart';

/// Settings row that reveals [child] in an inset surface when expanded.
class AppSettingsExpandTile extends StatelessWidget {
  const AppSettingsExpandTile({
    super.key,
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.child,
    this.subtitle,
    this.icon = Icons.tune_outlined,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppListTile(
          title: title,
          subtitle: subtitle,
          icon: icon,
          onTap: onToggle,
          trailing: AppDisclosureIcon(expanded: expanded),
        ),
        if (expanded) ...[
          const SizedBox(height: AppTheme.spaceSm),
          AppSurface(
            child: child,
          ),
        ],
      ],
    );
  }
}