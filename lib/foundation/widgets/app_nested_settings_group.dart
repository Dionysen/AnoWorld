import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Stack under an expanded settings row. Flat list: no extra inset chrome.
class AppSettingsNestedGroup extends StatelessWidget {
  const AppSettingsNestedGroup({
    super.key,
    required this.child,
    this.spacing = 0,
  });

  final Widget child;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (spacing <= 0) return child;
    return Padding(
      padding: EdgeInsets.only(top: spacing),
      child: child,
    );
  }
}

/// Helpers to lay out [children] with uniform vertical gaps (nested tier).
/// Default gap is 0 — flat rows use their own hairline dividers.
class AppSettingsNestedColumn extends StatelessWidget {
  const AppSettingsNestedColumn({
    super.key,
    required this.children,
    this.spacing = 0,
  });

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0 && spacing > 0) SizedBox(height: spacing),
          children[i],
        ],
      ],
    );
  }
}
