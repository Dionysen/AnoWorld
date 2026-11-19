import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/foundation/persona/user_persona.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_disclosure_icon.dart';
import 'package:anoworld/foundation/widgets/app_empty_state.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_page_gutter.dart';
import 'package:anoworld/foundation/widgets/app_person_avatar.dart';
import 'package:anoworld/foundation/widgets/app_sheet.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/settings/persona_editor_page.dart';
import 'package:flutter/material.dart';

/// Manage player identities: select current, open editor, add / delete.
class PersonaSettingsPanel extends StatelessWidget {
  const PersonaSettingsPanel({super.key});

  Future<void> _openEditor(BuildContext context, {UserPersona? persona}) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PersonaEditorPage(persona: persona),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    UserPersona persona,
  ) async {
    if (persona.isDefault) return;
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
            AppText('删除「${persona.name}」？', role: AppTextRole.subtitle),
            const SizedBox(height: AppTheme.spaceXs),
            const AppText(
              '删掉后不能恢复',
              role: AppTextRole.caption,
            ),
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
                    label: '删除',
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

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.settingsOf(context);
    final scheme = Theme.of(context).colorScheme;
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
                label: '添加身份',
                variant: AppButtonVariant.secondary,
                expanded: true,
                onPressed: () => _openEditor(context),
              ),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            if (list.isEmpty)
              const AppPageGutter(
                child: AppEmptyState(
                  message: '还没有身份',
                  detail: '添加一套，写故事和游玩时会用到',
                ),
              )
            else
              for (final persona in list)
                AppListTile(
                  title: persona.name,
                  subtitle: _subtitle(persona, active?.id),
                  leading: AppPersonAvatar(
                    size: 40,
                    semanticLabel: persona.name,
                  ),
                  selected: persona.id == active?.id,
                  onTap: () => controller.setActivePersona(persona.id),
                  onLongPress: persona.isDefault
                      ? null
                      : () => _confirmDelete(context, persona),
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

  static String? _subtitle(UserPersona persona, String? activeId) {
    final desc = persona.description.trim();
    if (desc.isEmpty) {
      if (persona.id == activeId) return '正在使用';
      return null;
    }
    final short = desc.length > 36 ? '${desc.substring(0, 36)}…' : desc;
    if (persona.id == activeId) return '正在使用 · $short';
    return short;
  }
}
