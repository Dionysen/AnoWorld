import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_nested_settings_style.dart';
import 'package:flutter/material.dart';

/// Inset stack under an expanded settings row: spaced sibling blocks.
class AppSettingsNestedGroup extends StatelessWidget {
  const AppSettingsNestedGroup({
    super.key,
    required this.child,
    this.spacing = AppTheme.spaceSm,
  });

  final Widget child;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppNestedSettingsStyle.horizontalInset,
      ),
      child: child,
    );
  }
}

/// Helpers to lay out [children] with uniform vertical gaps (nested tier).
class AppSettingsNestedColumn extends StatelessWidget {
  const AppSettingsNestedColumn({
    super.key,
    required this.children,
    this.spacing = AppTheme.spaceSm,
  });

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: spacing),
          children[i],
        ],
      ],
    );
  }
}