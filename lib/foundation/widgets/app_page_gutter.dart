import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';

/// Horizontal inset matching flat list row content on edge-to-edge pages.
class AppPageGutter extends StatelessWidget {
  const AppPageGutter({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.pagePadding),
      child: child,
    );
  }
}
