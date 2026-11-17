import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/foundation/ai/st_prompt_manager.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_nested_settings_group.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_switch.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/foundation/widgets/app_text_field.dart';
import 'package:flutter/material.dart';

/// Root-level prompt section list under the preset settings group.
class PromptManagerPanel extends StatelessWidget {
  const PromptManagerPanel({super.key});

  static String sectionLabel(PromptSection section) {
    return switch (section.type) {
      PromptSectionType.systemPrompt => '系统提示',
      PromptSectionType.persona => '玩家身份',
      PromptSectionType.characterDescription => '角色描述',
      PromptSectionType.characterPersonality => '角色性格',
      PromptSectionType.characterScenario => '场景',
      PromptSectionType.exampleMessages => '示例对白',
      PromptSectionType.worldInfo => '设定（前）',
      PromptSectionType.worldInfoAfter => '设定（后）',
      PromptSectionType.authorNote => '作者备注',
      PromptSectionType.postHistoryInstructions => '历史后指令',
      PromptSectionType.nsfw => '成人向提示',
      PromptSectionType.chatHistory => '对话历史',
      PromptSectionType.enhanceDefinitions => '强化定义',
      PromptSectionType.custom => section.name,
    };
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.settingsOf(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final config = controller.aiPresets.promptManager;
        final sections = config.sortedSections;
        return AppSettingsNestedColumn(
          children: [
            for (var i = 0; i < sections.length; i++)
              _SectionRow(
                index: i,
                section: sections[i],
                label: sectionLabel(sections[i]),
                config: config,
              ),
          ],
        );
      },
    );
  }

  static Future<void> editSection(
    BuildContext context,
    int index,
    PromptSection section,
  ) async {
    final controller = AppScope.settingsOf(context);
    final draft = TextEditingController(text: section.content ?? '');
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) {
          return AppPage(
            title: sectionLabel(section),
            onBack: () => Navigator.of(context).pop(false),
            body: AppPageBody(
              children: [
                AppTextField(
                  label: '内容',
                  controller: draft,
                  minLines: 8,
                  maxLines: 24,
                ),
                const SizedBox(height: AppTheme.spaceMd),
                AppListTile(
                  title: '保存',
                  icon: Icons.check_outlined,
                  onTap: () => Navigator.of(context).pop(true),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (saved != true || !context.mounted) return;
    final config = controller.aiPresets.promptManager;
    final updated = section.copyWith(content: draft.text);
    await controller.updatePromptManager(
      config.updateSectionByIndex(index, updated),
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({
    required this.index,
    required this.section,
    required this.label,
    required this.config,
  });

  final int index;
  final PromptSection section;
  final String label;
  final PromptManagerConfig config;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.settingsOf(context);
    final editable = section.isEditable;
    return AppListTile(
      title: '${index + 1}. $label',
      subtitle: section.isCharacterOwned
          ? '内容由当前故事角色填充'
          : (editable ? '点按编辑文案' : null),
      icon: Icons.article_outlined,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (editable)
            const Padding(
              padding: EdgeInsets.only(right: AppTheme.spaceSm),
              child: AppText('编辑', role: AppTextRole.caption),
            ),
          AppSwitch(
            value: section.enabled,
            onChanged: (_) async {
              final next = config.toggleSectionByIndex(index);
              await controller.updatePromptManager(next);
            },
          ),
        ],
      ),
      onTap: editable
          ? () => PromptManagerPanel.editSection(context, index, section)
          : null,
    );
  }
}