import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';
import 'app_text.dart';

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
      child: AppText(label, role: AppTextRole.subtitle),
    );
  }
}
