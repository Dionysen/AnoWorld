import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/foundation/persona/user_persona.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_empty_state.dart';
import 'package:anoworld/foundation/widgets/app_disclosure_icon.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/settings/persona_editor_page.dart';
import 'package:flutter/material.dart';

class PersonaSettingsPanel extends StatelessWidget {
  const PersonaSettingsPanel({super.key});

  Future<void> _openEditor(BuildContext context, {UserPersona? persona}) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PersonaEditorPage(persona: persona),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.settingsOf(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final settings = controller.personas;
        final active = controller.activePersona;
        final list = settings.personas;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppSectionHeader(
              '玩家身份',
              subtitle: '与酒馆 Persona 相同，写进提示词并参与宏展开',
            ),
            if (active != null)
              AppText(
                '当前：${active.name}',
                role: AppTextRole.caption,
              ),
            const SizedBox(height: AppTheme.spaceSm),
            AppButton(
              label: '新建身份',
              variant: AppButtonVariant.secondary,
              expanded: true,
              onPressed: () => _openEditor(context),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            if (list.isEmpty)
              const AppEmptyState(
                message: '还没有玩家身份',
                detail: '建一套，写故事和游玩时会当作用户名',
              )
            else
              for (var i = 0; i < list.length; i++) ...[
                if (i > 0) const SizedBox(height: AppTheme.spaceSm),
                AppListTile(
                  title: list[i].name,
                  subtitle: _subtitle(list[i], active?.id),
                  icon: Icons.face_outlined,
                  onTap: () => controller.setActivePersona(list[i].id),
                  trailing: GestureDetector(
                    onTap: () => _openEditor(context, persona: list[i]),
                    child: const AppForwardIcon(),
                  ),
                ),
              ],
            const SizedBox(height: AppTheme.spaceXs),
            const AppText(
              '点一行切换当前身份，点右侧箭头编辑',
              role: AppTextRole.caption,
            ),
          ],
        );
      },
    );
  }

  static String? _subtitle(UserPersona persona, String? activeId) {
    final parts = <String>[
      if (persona.isDefault) '默认',
      if (persona.id == activeId) '正在使用',
    ];
    final desc = persona.description.trim();
    if (desc.isNotEmpty) {
      final short = desc.length > 28 ? '${desc.substring(0, 28)}…' : desc;
      parts.add(short);
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }
}