import 'package:anoworld/foundation/widgets/app_disclosure_icon.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_nested_settings_group.dart';
import 'package:flutter/material.dart';

/// Settings row that reveals [child] when expanded (flat list, no island).
class AppSettingsExpandTile extends StatelessWidget {
  const AppSettingsExpandTile({
    super.key,
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.child,
    this.subtitle,
    this.icon = Icons.tune_outlined,
    this.nested = false,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;
  final bool nested;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppListTile(
          title: title,
          subtitle: subtitle,
          icon: icon,
          nested: nested,
          onTap: onToggle,
          trailing: AppDisclosureIcon(expanded: expanded),
        ),
        if (expanded) AppSettingsNestedGroup(child: child),
      ],
    );
  }
}