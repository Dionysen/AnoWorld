import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/foundation/ai/st_prompt_manager.dart';
import 'package:anoworld/foundation/logging/app_log.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_confirm_sheet.dart';
import 'package:anoworld/foundation/widgets/app_icon_button.dart';
import 'package:anoworld/foundation/widgets/app_list_selection_controller.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_page_gutter.dart';
import 'package:anoworld/foundation/widgets/app_page_route.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/foundation/widgets/app_switch.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/foundation/widgets/app_text_edit_tile.dart';
import 'package:anoworld/foundation/widgets/app_text_field.dart';
import 'package:anoworld/foundation/widgets/app_toast.dart';
import 'package:flutter/material.dart';

/// Prompt section header + list: add, reorder, restore order, multi-select
/// delete of custom sections.
class PromptManagerPanel extends StatefulWidget {
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
        builder: (pageContext) {
          return AppPage(
            title: sectionLabel(strings, section),
            onBack: () => Navigator.of(pageContext).pop(false),
            actions: [
              if (section.isCustom)
                AppIconButton(
                  icon: Icons.delete_outline,
                  tooltip: strings.delete,
                  danger: true,
                  onPressed: () => _deleteSection(pageContext, section),
                ),
            ],
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
                  onTap: () => Navigator.of(pageContext).pop(true),
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

  /// Confirm, then remove a custom section and close its editor.
  static Future<void> _deleteSection(
    BuildContext context,
    PromptSection section,
  ) async {
    final strings = context.strings;
    final label = sectionLabel(strings, section);
    final confirmed = await showAppConfirmSheet(
      context,
      title: strings.promptDeleteTitle(label),
      detail: strings.promptDeleteDetail,
      confirmLabel: strings.delete,
      danger: true,
    );
    if (!confirmed || !context.mounted) return;
    final controller = AppScope.settingsOf(context);
    final config = controller.aiPresets.promptManager;
    final sorted = config.sortedSections;
    final index = sorted.indexWhere(
      (s) =>
          s.identifier == section.identifier &&
          s.type == section.type &&
          s.name == section.name,
    );
    if (index < 0) return;
    await controller.updatePromptManager(config.removeSectionAt(index));
    AppLog.instance.info('删除提示词：$label', tag: 'ai.preset');
    if (!context.mounted) return;
    showAppToast(context, strings.promptDeleted);
    Navigator.of(context).pop(false);
  }

  @override
  State<PromptManagerPanel> createState() => _PromptManagerPanelState();
}

class _PromptManagerPanelState extends State<PromptManagerPanel> {
  final AppListSelectionController _selection = AppListSelectionController();

  @override
  void initState() {
    super.initState();
    _selection.addListener(_onSelectionChanged);
  }

  @override
  void dispose() {
    _selection.removeListener(_onSelectionChanged);
    _selection.dispose();
    super.dispose();
  }

  void _onSelectionChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _addSection() async {
    final strings = context.strings;
    final name = await showAppTextEditSheet(
      context: context,
      title: strings.promptAddTitle,
      initialValue: '',
      hint: strings.promptAddNameHint,
    );
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty || !mounted) return;
    final controller = AppScope.settingsOf(context);
    final identifier =
        'custom_${DateTime.now().toUtc().microsecondsSinceEpoch}';
    await controller.updatePromptManager(
      controller.aiPresets.promptManager.addCustomSection(
        name: trimmed,
        identifier: identifier,
      ),
    );
    AppLog.instance.info('添加提示词：$trimmed', tag: 'ai.preset');
    if (!mounted) return;
    showAppToast(context, strings.promptAdded(trimmed));
  }

  Future<void> _restoreOrder() async {
    final controller = AppScope.settingsOf(context);
    await controller.updatePromptManager(
      controller.aiPresets.promptManager.restoreDefaultOrder(),
    );
    if (!mounted) return;
    AppLog.instance.info('恢复预设提示词默认顺序', tag: 'ai.preset');
    showAppToast(context, context.strings.presetOrderRestored);
  }

  Future<void> _deleteSelected(
    PromptManagerConfig config,
    List<String> identifiers,
  ) async {
    if (identifiers.isEmpty) return;
    final strings = context.strings;
    final confirmed = await showAppConfirmSheet(
      context,
      title: strings.deleteItemsTitle(identifiers.length),
      detail: strings.promptDeleteDetail,
      confirmLabel: strings.delete,
      danger: true,
    );
    if (!confirmed || !mounted) return;
    final controller = AppScope.settingsOf(context);
    await controller.updatePromptManager(
      config.removeCustomSections(identifiers),
    );
    AppLog.instance.info(
      '删除 ${identifiers.length} 条提示词',
      tag: 'ai.preset',
    );
    if (!mounted) return;
    _selection.exit();
    showAppToast(context, strings.promptDeleted);
  }

  void _onRowTap(int index, PromptSection section, String key) {
    if (!_selection.active) {
      PromptManagerPanel.openSection(context, index, section);
      return;
    }
    if (!section.isCustom) {
      showAppToast(context, context.strings.promptDeleteBuiltInHint);
      return;
    }
    _selection.toggle(key);
  }

  Widget _buildHeader(
    AppStrings strings,
    PromptManagerConfig config,
    List<PromptSection> sections,
  ) {
    final customSections = [
      for (final section in sections)
        if (section.isCustom) section,
    ];
    final selectedCustom = [
      for (final section in customSections)
        if (_selection.isSelected(PromptManagerPanel._sectionKey(section)))
          section,
    ];
    final hasSelection = selectedCustom.isNotEmpty;
    final Widget trailing;
    if (_selection.active) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: AppPage.spacedActions([
          AppIconButton(
            icon: Icons.close,
            tooltip: strings.exitSelection,
            onPressed: _selection.exit,
          ),
          if (customSections.isNotEmpty)
            AppIconButton(
              icon: hasSelection ? Icons.deselect : Icons.select_all,
              tooltip: strings.selectAll(hasSelection),
              onPressed: () => _selection.toggleAll([
                for (final section in customSections)
                  PromptManagerPanel._sectionKey(section),
              ]),
            ),
          if (hasSelection)
            AppIconButton(
              icon: Icons.delete_outline,
              tooltip: strings.delete,
              danger: true,
              onPressed: () => _deleteSelected(
                config,
                [
                  for (final section in selectedCustom)
                    if (section.identifier != null) section.identifier!,
                ],
              ),
            ),
        ]),
      );
    } else {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: AppPage.spacedActions([
          if (customSections.isNotEmpty)
            AppIconButton(
              icon: Icons.checklist,
              tooltip: strings.multiSelect,
              onPressed: _selection.enter,
            ),
          AppIconButton(
            icon: Icons.add,
            tooltip: strings.addOne,
            onPressed: _addSection,
          ),
          AppIconButton(
            icon: Icons.restart_alt_outlined,
            tooltip: strings.presetRestoreOrderAction,
            onPressed: _restoreOrder,
          ),
        ]),
      );
    }

    final label = _selection.active
        ? (hasSelection
              ? strings.selectedCount(selectedCustom.length)
              : strings.multiSelect)
        : strings.presetPromptsSection;
    return AppSectionHeader(label, gutter: true, trailing: trailing);
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(strings, config, sections),
            ReorderableListView.builder(
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
                final key = PromptManagerPanel._sectionKey(section);
                return _SectionRow(
                  key: ValueKey(key),
                  index: index,
                  section: section,
                  label: PromptManagerPanel.sectionLabel(strings, section),
                  config: config,
                  selectionActive: _selection.active,
                  selected: _selection.isSelected(key),
                  onTap: () => _onRowTap(index, section, key),
                  onLongPress: section.isCustom
                      ? () => _selection.enter(id: key)
                      : null,
                );
              },
            ),
          ],
        );
      },
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
    required this.selectionActive,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final int index;
  final PromptSection section;
  final String label;
  final PromptManagerConfig config;
  final bool selectionActive;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.settingsOf(context);
    final strings = context.strings;
    final scheme = Theme.of(context).colorScheme;
    final editable = section.isEditable;
    final selectable = section.isCustom;

    final Widget leading;
    if (selectionActive) {
      leading = Icon(
        selectable
            ? (selected ? Icons.check_circle : Icons.circle_outlined)
            : Icons.lock_outline,
        size: AppListTile.iconSize,
        color: selectable
            ? (selected ? scheme.primary : scheme.outline)
            : scheme.outlineVariant,
      );
    } else {
      leading = ReorderableDragStartListener(
        index: index,
        child: Icon(
          Icons.drag_handle,
          size: AppListTile.iconSize,
          color: scheme.onSurfaceVariant,
        ),
      );
    }

    return AppListTile(
      title: label,
      subtitle: section.isCharacterOwned
          ? strings.filledByCast
          : (editable ? strings.tapToEdit : strings.tapToView),
      leading: leading,
      selected: selectionActive && selected,
      trailing: selectionActive
          ? null
          : AppSwitch(
              value: section.enabled,
              onChanged: (_) async {
                final next = config.toggleSectionByIndex(index);
                await controller.updatePromptManager(next);
              },
            ),
      onTap: onTap,
      onLongPress: selectionActive ? null : onLongPress,
    );
  }
}
