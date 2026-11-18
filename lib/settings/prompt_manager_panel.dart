import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/foundation/ai/st_prompt_manager.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_page_gutter.dart';
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

  static String _sectionKey(PromptSection section) {
    final id = section.identifier?.trim();
    if (id != null && id.isNotEmpty) return id;
    return '${section.type.name}:${section.name}';
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.settingsOf(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final config = controller.aiPresets.promptManager;
        final sections = config.sortedSections;
        return ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: sections.length,
          onReorderItem: (oldIndex, newIndex) async {
            await controller.updatePromptManager(
              config.reorder(oldIndex, newIndex),
            );
          },
          itemBuilder: (context, index) {
            final section = sections[index];
            return _SectionRow(
              key: ValueKey(_sectionKey(section)),
              index: index,
              section: section,
              label: sectionLabel(section),
              config: config,
            );
          },
        );
      },
    );
  }

  static Future<void> openSection(
    BuildContext context,
    int index,
    PromptSection section,
  ) async {
    if (section.isEditable) {
      await editSection(context, index, section);
      return;
    }
    await viewSection(context, section);
  }

  static Future<void> viewSection(
    BuildContext context,
    PromptSection section,
  ) async {
    final body = _readOnlyBody(section);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) {
          return AppPage(
            title: sectionLabel(section),
            onBack: () => Navigator.of(context).pop(),
            body: AppPageBody.list(
              children: [
                AppPageGutter(
                  child: AppText(
                    body,
                    role: AppTextRole.body,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _readOnlyBody(PromptSection section) {
    if (section.isCharacterOwned) {
      return '内容由当前故事角色填充，这里不能改';
    }
    final text = section.effectiveContent.trim();
    if (text.isNotEmpty) return text;
    return switch (section.type) {
      PromptSectionType.persona => '写故事时用当前玩家身份填充',
      PromptSectionType.worldInfo ||
      PromptSectionType.worldInfoAfter =>
        '写故事时用当前故事的背景设定填充',
      PromptSectionType.chatHistory => '写故事时自动带上对话历史',
      PromptSectionType.authorNote => '暂无作者备注',
      _ => '这段会在写故事时自动带上',
    };
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
            body: AppPageBody.list(
              children: [
                AppPageGutter(
                  child: AppTextField(
                    label: '内容',
                    controller: draft,
                    minLines: 8,
                    maxLines: 24,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceMd),
                AppListTile(
                  title: '保存',
                  icon: Icons.check_outlined,
                  onTap: () => Navigator.of(context).pop(true),
                  showDivider: false,
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
    super.key,
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
    final scheme = Theme.of(context).colorScheme;
    return AppListTile(
      title: label,
      subtitle: section.isCharacterOwned
          ? '内容由当前故事角色填充'
          : (editable ? '点按编辑文案' : '点按查看'),
      leading: ReorderableDragStartListener(
        index: index,
        child: Icon(
          Icons.drag_handle,
          size: AppListTile.iconSize,
          color: scheme.onSurfaceVariant,
        ),
      ),
      trailing: AppSwitch(
        value: section.enabled,
        onChanged: (_) async {
          final next = config.toggleSectionByIndex(index);
          await controller.updatePromptManager(next);
        },
      ),
      onTap: () => PromptManagerPanel.openSection(context, index, section),
    );
  }
}
