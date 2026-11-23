import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/foundation/persona/user_persona.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_disclosure_icon.dart';
import 'package:anoworld/foundation/widgets/app_empty_state.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_page_gutter.dart';
import 'package:anoworld/foundation/widgets/app_page_route.dart';
import 'package:anoworld/foundation/widgets/app_person_avatar.dart';
import 'package:anoworld/settings/persona_delete.dart';
import 'package:anoworld/settings/persona_editor_page.dart';
import 'package:anoworld/settings/persona_labels.dart';
import 'package:flutter/material.dart';

/// Manage player identities: select current, open editor, add / delete.
class PersonaSettingsPanel extends StatelessWidget {
  const PersonaSettingsPanel({super.key});

  Future<void> _openEditor(BuildContext context, {UserPersona? persona}) async {
    await pushAppSlide(context, PersonaEditorPage(persona: persona));
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.settingsOf(context);
    final scheme = Theme.of(context).colorScheme;
    final strings = context.strings;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final settings = controller.personas;
        final active = controller.activePersona;
        final list = settings.personas;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppPageGutter(
              child: AppButton(
                label: strings.addPersona,
                variant: AppButtonVariant.secondary,
                expanded: true,
                onPressed: () => _openEditor(context),
              ),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            if (list.isEmpty)
              AppPageGutter(
                child: AppEmptyState(
                  message: strings.personasEmpty,
                  detail: strings.personasEmptyHint,
                ),
              )
            else
              for (final persona in list)
                AppListTile(
                  title: persona.name,
                  subtitle: personaSubtitle(strings, persona, active?.id),
                  leading: AppPersonAvatar(
                    size: 40,
                    semanticLabel: persona.name,
                  ),
                  selected: persona.id == active?.id,
                  onTap: () => controller.setActivePersona(persona.id),
                  onLongPress: persona.isDefault
                      ? null
                      : () => confirmAndDeletePersona(context, persona),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (persona.id == active?.id)
                        Padding(
                          padding: const EdgeInsets.only(right: AppTheme.spaceXs),
                          child: Icon(
                            Icons.check_rounded,
                            size: 20,
                            color: scheme.primary,
                          ),
                        ),
                      GestureDetector(
                        onTap: () => _openEditor(context, persona: persona),
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.all(AppTheme.spaceXs),
                          child: AppForwardIcon(),
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        );
      },
    );
  }
}
