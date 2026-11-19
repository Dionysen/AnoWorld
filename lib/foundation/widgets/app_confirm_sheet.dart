import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_button.dart';
import 'app_sheet.dart';
import 'app_text.dart';

/// Compact sheet confirm dialog (取消 + one action); true when confirmed.
Future<bool> showAppConfirmSheet(
  BuildContext context, {
  required String title,
  required String detail,
  required String confirmLabel,
  bool danger = false,
}) async {
  final confirmed = await showAppSheet<bool>(
    context: context,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.pagePadding,
        AppTheme.spaceSm,
        AppTheme.pagePadding,
        AppTheme.pagePadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppText(title, role: AppTextRole.subtitle),
          const SizedBox(height: AppTheme.spaceXs),
          AppText(detail, role: AppTextRole.caption),
          const SizedBox(height: AppTheme.spaceMd),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: '取消',
                  variant: AppButtonVariant.secondary,
                  onPressed: () => Navigator.of(ctx).pop(false),
                ),
              ),
              const SizedBox(width: AppTheme.spaceSm),
              Expanded(
                child: AppButton(
                  label: confirmLabel,
                  variant: danger
                      ? AppButtonVariant.danger
                      : AppButtonVariant.primary,
                  onPressed: () => Navigator.of(ctx).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  return confirmed == true;
}
