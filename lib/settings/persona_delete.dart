import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/foundation/persona/user_persona.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_sheet.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:flutter/material.dart';

/// Asks for confirmation, then drops [persona]. The built-in default identity
/// cannot be deleted, so it is a no-op.
Future<void> confirmAndDeletePersona(
  BuildContext context,
  UserPersona persona,
) async {
  if (persona.isDefault) return;
  final strings = context.strings;
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
          AppText(
            strings.deletePersonaTitle(persona.name),
            role: AppTextRole.subtitle,
          ),
          const SizedBox(height: AppTheme.spaceXs),
          AppText(strings.deletePersonaHint, role: AppTextRole.caption),
          const SizedBox(height: AppTheme.spaceMd),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: strings.cancel,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => Navigator.of(ctx).pop(false),
                ),
              ),
              const SizedBox(width: AppTheme.spaceSm),
              Expanded(
                child: AppButton(
                  label: strings.delete,
                  variant: AppButtonVariant.danger,
                  onPressed: () => Navigator.of(ctx).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  if (confirmed != true || !context.mounted) return;
  await AppScope.settingsOf(context).deletePersona(persona.id);
}
