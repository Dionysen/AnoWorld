import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Full-width hairline under flat list rows ([AppListTile], [AppSlider]).
class AppListHairline extends StatelessWidget {
  const AppListHairline({super.key});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: AppTheme.listHairline(context),
    );
  }
}
