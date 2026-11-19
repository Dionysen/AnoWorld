import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/foundation/ai/st_prompt_manager.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_page_gutter.dart';
import 'package:anoworld/foundation/widgets/app_page_route.dart';
import 'package:anoworld/foundation/widgets/app_switch.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/foundation/widgets/app_text_field.dart';
import 'package:flutter/material.dart';

/// Root-level prompt section list under the preset settings group.
class PromptManagerPanel extends StatelessWidget {
  const PromptManagerPanel({super.key});

  static String sectionLabel(AppStrings strings, PromptSection section) {
    if (section.type == PromptSectionType.custom) {
      final name = section.name.trim();
      if (name.isNotEmpty) return name;
    }
    return strings.promptSectionName(section.type);
  }

  static String _sectionKey(PromptSection section) {
    final id = section.identifier?.trim();
    if (id != null && id.isNotEmpty) return id;
    return '${section.type.name}:${section.name}';
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.settingsOf(context);
    final strings = context.strings;
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
              label: sectionLabel(strings, section),
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
    final body = _readOnlyBody(context.strings, section);
    await Navigator.of(context).push<void>(
      AppSlidePageRoute<void>(
        builder: (context) {
          return AppPage(
            title: sectionLabel(context.strings, section),
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

  static String _readOnlyBody(AppStrings strings, PromptSection section) {
    if (section.isCharacterOwned) {
      return strings.filledByCastReadOnly;
    }
    final text = section.effectiveContent.trim();
    if (text.isNotEmpty) return text;
    return switch (section.type) {
      PromptSectionType.persona => strings.filledByPersona,
      PromptSectionType.worldInfo ||
      PromptSectionType.worldInfoAfter =>
        strings.filledByWorldBook,
      PromptSectionType.chatHistory => strings.filledByHistory,
      PromptSectionType.authorNote => strings.emptyAuthorNote,
      _ => strings.filledAutomatically,
    };
  }

  static Future<void> editSection(
    BuildContext context,
    int index,
    PromptSection section,
  ) async {
    final strings = context.strings;
    final controller = AppScope.settingsOf(context);
    final draft = TextEditingController(text: section.content ?? '');
    final saved = await Navigator.of(context).push<bool>(
      AppSlidePageRoute<bool>(
        builder: (context) {
          return AppPage(
            title: sectionLabel(strings, section),
            onBack: () => Navigator.of(context).pop(false),
            body: AppPageBody.list(
              children: [
                AppPageGutter(
                  child: AppTextField(
                    label: strings.contentLabel,
                    controller: draft,
                    minLines: 8,
                    maxLines: 24,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceMd),
                AppListTile(
                  title: strings.save,
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
          ? context.strings.filledByCast
          : (editable ? context.strings.tapToEdit : context.strings.tapToView),
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
