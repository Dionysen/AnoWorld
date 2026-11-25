import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/foundation/ai/st_prompt_manager.dart';
import 'package:anoworld/foundation/logging/app_log.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_confirm_sheet.dart';
import 'package:anoworld/foundation/widgets/app_disclosure_icon.dart';
import 'package:anoworld/foundation/widgets/app_icon_button.dart';
import 'package:anoworld/foundation/widgets/app_list_selection_controller.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_page_gutter.dart';
import 'package:anoworld/foundation/widgets/app_page_route.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/foundation/widgets/app_sheet.dart';
import 'package:anoworld/foundation/widgets/app_switch.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/foundation/widgets/app_text_edit_tile.dart';
import 'package:anoworld/foundation/widgets/app_text_field.dart';
import 'package:anoworld/foundation/widgets/app_toast.dart';
import 'package:flutter/material.dart';

/// Drag payload for moving a prompt section onto a category header.
class _SectionDragPayload {
  const _SectionDragPayload({
    required this.globalIndex,
    required this.key,
  });

  final int globalIndex;
  final String key;
}

/// Prompt section header + list: add, reorder, restore order, categories,
/// multi-select delete of custom sections and categories.
///
/// When [sliver] is true, builds a [SliverMainAxisGroup] for a parent
/// [CustomScrollView] (pinned header). Otherwise wraps the same slivers in its
/// own scroll view.
class PromptManagerPanel extends StatefulWidget {
  const PromptManagerPanel({super.key, this.sliver = false});

  /// Embed as slivers inside a parent [CustomScrollView].
  final bool sliver;

  static String sectionLabel(AppStrings strings, PromptSection section) {
    if (section.type == PromptSectionType.custom) {
      final name = section.name.trim();
      if (name.isNotEmpty) return name;
    }
    return strings.promptSectionName(section.type);
  }

  static String sectionKey(PromptSection section) {
    final id = section.identifier?.trim();
    if (id != null && id.isNotEmpty) return id;
    return '${section.type.name}:${section.name}';
  }

  static String categoryKey(String id) => 'cat:$id';

  static int indexOf(PromptManagerConfig config, PromptSection section) {
    return config.sortedSections.indexWhere(
      (s) =>
          s.identifier == section.identifier &&
          s.type == section.type &&
          s.name == section.name &&
          s.order == section.order,
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
    var draftCategoryId = section.categoryId;

    final saved = await Navigator.of(context).push<bool>(
      AppSlidePageRoute<bool>(
        builder: (pageContext) {
          return ListenableBuilder(
            listenable: controller,
            builder: (pageContext, _) {
              final config = controller.aiPresets.promptManager;
              final catName = () {
                final id = draftCategoryId?.trim();
                if (id == null || id.isEmpty) return strings.promptCategoryNone;
                return config.categoryById(id)?.name ??
                    strings.promptCategoryNone;
              }();
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
                    AppListTile(
                      title: strings.promptCategoryLabel,
                      subtitle: catName,
                      onTap: () async {
                        final picked = await _pickCategory(
                          pageContext,
                          config,
                          currentId: draftCategoryId,
                        );
                        if (picked == null || !pageContext.mounted) return;
                        draftCategoryId = picked.isEmpty ? null : picked;
                        (pageContext as Element).markNeedsBuild();
                      },
                    ),
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
          );
        },
      ),
    );
    if (saved != true || !context.mounted) return;
    final config = controller.aiPresets.promptManager;
    final cat = draftCategoryId?.trim();
    final updated = (cat == null || cat.isEmpty)
        ? section.copyWith(content: draft.text, clearCategoryId: true)
        : section.copyWith(content: draft.text, categoryId: cat);
    await controller.updatePromptManager(
      config.updateSectionByIndex(index, updated),
    );
  }

  /// Returns category id, empty string for none, or null if cancelled.
  static Future<String?> _pickCategory(
    BuildContext context,
    PromptManagerConfig config, {
    String? currentId,
  }) async {
    final strings = context.strings;
    return showAppSheet<String>(
      context: context,
      size: AppSheetSize.compact,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppTheme.spaceSm),
          AppListTile(
            title: strings.promptCategoryNone,
            selected: currentId == null || currentId.isEmpty,
            onTap: () => Navigator.of(ctx).pop(''),
          ),
          for (final cat in config.sortedCategories)
            AppListTile(
              title: cat.name,
              selected: currentId == cat.id,
              onTap: () => Navigator.of(ctx).pop(cat.id),
              showDivider: cat.id != config.sortedCategories.last.id,
            ),
          const SizedBox(height: AppTheme.pagePadding),
        ],
      ),
    );
  }

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
    final index = indexOf(config, section);
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
  final Set<String> _expandedCategoryIds = <String>{};
  bool _expandedSeeded = false;

  /// Height of the pinned 「预设提示词」 row (icon buttons + section bottom gap).
  /// Slightly taller than the bare button row so gutter/text do not clip.
  static const double _headerExtent =
      AppIconButton.hitTarget + AppTheme.spaceSm + AppTheme.spaceXs;

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

  void _seedExpanded(PromptManagerConfig config) {
    if (_expandedSeeded) return;
    _expandedSeeded = true;
    for (final cat in config.sortedCategories) {
      final members = config.sectionsInCategory(cat.id);
      if (members.any((s) => s.enabled)) {
        _expandedCategoryIds.add(cat.id);
      }
    }
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

  Future<void> _addCategory() async {
    final strings = context.strings;
    final name = await showAppTextEditSheet(
      context: context,
      title: strings.promptAddCategoryTitle,
      initialValue: '',
      hint: strings.promptAddCategoryHint,
    );
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty || !mounted) return;
    final controller = AppScope.settingsOf(context);
    final id = 'cat_${DateTime.now().toUtc().microsecondsSinceEpoch}';
    await controller.updatePromptManager(
      controller.aiPresets.promptManager.upsertCategory(id: id, name: trimmed),
    );
    AppLog.instance.info('添加提示词分类：$trimmed', tag: 'ai.preset');
    if (!mounted) return;
    setState(() => _expandedCategoryIds.add(id));
    showAppToast(context, strings.promptCategoryAdded(trimmed));
  }

  Future<void> _renameCategory(PromptCategory category) async {
    final strings = context.strings;
    final name = await showAppTextEditSheet(
      context: context,
      title: strings.promptRenameCategoryTitle,
      initialValue: category.name,
      hint: strings.promptAddCategoryHint,
    );
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty || !mounted) return;
    final controller = AppScope.settingsOf(context);
    await controller.updatePromptManager(
      controller.aiPresets.promptManager.renameCategory(category.id, trimmed),
    );
    AppLog.instance.info('重命名提示词分类：$trimmed', tag: 'ai.preset');
    if (!mounted) return;
    showAppToast(context, strings.promptCategoryRenamed(trimmed));
  }

  Future<void> _deleteCategory(PromptCategory category) async {
    final strings = context.strings;
    final confirmed = await showAppConfirmSheet(
      context,
      title: strings.promptDeleteCategoryTitle(category.name),
      detail: strings.promptDeleteCategoryDetail,
      confirmLabel: strings.delete,
      danger: true,
    );
    if (!confirmed || !mounted) return;
    final controller = AppScope.settingsOf(context);
    await controller.updatePromptManager(
      controller.aiPresets.promptManager.deleteCategory(category.id),
    );
    AppLog.instance.info('删除提示词分类：${category.name}', tag: 'ai.preset');
    if (!mounted) return;
    setState(() => _expandedCategoryIds.remove(category.id));
    showAppToast(context, strings.promptCategoryDeleted);
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
    PromptManagerConfig config, {
    required List<String> sectionIdentifiers,
    required List<String> categoryIds,
  }) async {
    final total = sectionIdentifiers.length + categoryIds.length;
    if (total == 0) return;
    final strings = context.strings;
    final confirmed = await showAppConfirmSheet(
      context,
      title: strings.deleteItemsTitle(total),
      detail: categoryIds.isEmpty
          ? strings.promptDeleteDetail
          : strings.promptDeleteCategoryDetail,
      confirmLabel: strings.delete,
      danger: true,
    );
    if (!confirmed || !mounted) return;
    final controller = AppScope.settingsOf(context);
    var next = config;
    for (final id in categoryIds) {
      next = next.deleteCategory(id);
    }
    next = next.removeCustomSections(sectionIdentifiers);
    await controller.updatePromptManager(next);
    AppLog.instance.info(
      '删除选中：分类 ${categoryIds.length}，提示词 ${sectionIdentifiers.length}',
      tag: 'ai.preset',
    );
    if (!mounted) return;
    setState(() {
      for (final id in categoryIds) {
        _expandedCategoryIds.remove(id);
      }
    });
    _selection.exit();
    showAppToast(context, strings.promptDeleted);
  }

  Future<void> _moveToCategory(int globalIndex, String? categoryId) async {
    if (globalIndex < 0) return;
    final controller = AppScope.settingsOf(context);
    final config = controller.aiPresets.promptManager;
    await controller.updatePromptManager(
      config.moveSectionToCategory(globalIndex, categoryId),
    );
    final id = categoryId?.trim();
    if (id != null && id.isNotEmpty && mounted) {
      setState(() => _expandedCategoryIds.add(id));
    }
    AppLog.instance.info(
      id == null || id.isEmpty ? '移到未分类' : '移到分类：$id',
      tag: 'ai.preset',
    );
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
    final categories = config.sortedCategories;
    final customSections = [
      for (final section in sections)
        if (section.isCustom) section,
    ];
    final selectedCustom = [
      for (final section in customSections)
        if (_selection.isSelected(PromptManagerPanel.sectionKey(section)))
          section,
    ];
    final selectedCategories = [
      for (final cat in categories)
        if (_selection.isSelected(PromptManagerPanel.categoryKey(cat.id))) cat,
    ];
    final selectedCount = selectedCustom.length + selectedCategories.length;
    final hasSelection = selectedCount > 0;
    final canMultiSelect =
        customSections.isNotEmpty || categories.isNotEmpty;

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
          if (canMultiSelect)
            AppIconButton(
              icon: hasSelection ? Icons.deselect : Icons.select_all,
              tooltip: strings.selectAll(hasSelection),
              onPressed: () => _selection.toggleAll([
                for (final section in customSections)
                  PromptManagerPanel.sectionKey(section),
                for (final cat in categories)
                  PromptManagerPanel.categoryKey(cat.id),
              ]),
            ),
          if (hasSelection)
            AppIconButton(
              icon: Icons.delete_outline,
              tooltip: strings.delete,
              danger: true,
              onPressed: () => _deleteSelected(
                config,
                sectionIdentifiers: [
                  for (final section in selectedCustom)
                    if (section.identifier != null) section.identifier!,
                ],
                categoryIds: [
                  for (final cat in selectedCategories) cat.id,
                ],
              ),
            ),
        ]),
      );
    } else {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: AppPage.spacedActions([
          if (canMultiSelect)
            AppIconButton(
              icon: Icons.checklist,
              tooltip: strings.multiSelect,
              onPressed: _selection.enter,
            ),
          AppIconButton(
            icon: Icons.create_new_folder_outlined,
            tooltip: strings.promptAddCategoryAction,
            onPressed: _addCategory,
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
              ? strings.selectedCount(selectedCount)
              : strings.multiSelect)
        : strings.presetPromptsSection;
    return AppSectionHeader(label, gutter: true, trailing: trailing);
  }

  Widget _uncategorizedDropHeader(AppStrings strings, {required bool active}) {
    return DragTarget<_SectionDragPayload>(
      onWillAcceptWithDetails: (_) => !_selection.active,
      onAcceptWithDetails: (details) {
        _moveToCategory(details.data.globalIndex, null);
      },
      builder: (context, candidate, rejected) {
        final hovering = candidate.isNotEmpty;
        return AppListTile(
          title: strings.promptCategoryNone,
          icon: Icons.inbox_outlined,
          selected: hovering || active,
          showDivider: true,
        );
      },
    );
  }

  Widget _buildListBody(
    BuildContext context,
    AppStrings strings,
    PromptManagerConfig config,
  ) {
    final controller = AppScope.settingsOf(context);
    final items = config.topLevelItems;
    final showUncategorizedHeader = config.categories.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showUncategorizedHeader)
          _uncategorizedDropHeader(
            strings,
            active: false,
          ),
        if (items.isNotEmpty)
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: items.length,
            onReorderItem: (oldIndex, newIndex) async {
              if (_selection.active) return;
              await controller.updatePromptManager(
                config.reorderTopLevel(oldIndex, newIndex),
              );
            },
            itemBuilder: (context, index) {
              final item = items[index];
              if (item.isCategory) {
                final category = item.category!;
                return _CategoryBlock(
                  key: ValueKey(item.layoutKey),
                  reorderIndex: index,
                  category: category,
                  config: config,
                  expanded: _expandedCategoryIds.contains(category.id),
                  selection: _selection,
                  selected: _selection.isSelected(
                    PromptManagerPanel.categoryKey(category.id),
                  ),
                  enableCrossDrag: !_selection.active,
                  onToggleExpanded: () {
                    setState(() {
                      if (_expandedCategoryIds.contains(category.id)) {
                        _expandedCategoryIds.remove(category.id);
                      } else {
                        _expandedCategoryIds.add(category.id);
                      }
                    });
                  },
                  onSelect: () => _selection.toggle(
                    PromptManagerPanel.categoryKey(category.id),
                  ),
                  onRename: () => _renameCategory(category),
                  onDelete: () => _deleteCategory(category),
                  onRowTap: _onRowTap,
                  onAcceptSection: (payload) {
                    _moveToCategory(payload.globalIndex, category.id);
                  },
                );
              }

              final section = item.section!;
              final globalIndex = PromptManagerPanel.indexOf(config, section);
              final key = PromptManagerPanel.sectionKey(section);
              return _SectionRow(
                key: ValueKey(item.layoutKey),
                index: index,
                globalIndex: globalIndex,
                section: section,
                label: PromptManagerPanel.sectionLabel(strings, section),
                config: config,
                selectionActive: _selection.active,
                selected: _selection.isSelected(key),
                enableCrossDrag: !_selection.active,
                onTap: () => _onRowTap(globalIndex, section, key),
              );
            },
          ),
      ],
    );
  }

  List<Widget> _slivers(
    BuildContext context,
    AppStrings strings,
    PromptManagerConfig config,
  ) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return [
      SliverPersistentHeader(
        pinned: true,
        delegate: _PinnedPromptHeaderDelegate(
          extent: _headerExtent,
          background: bg,
          child: _buildHeader(strings, config, config.sortedSections),
        ),
      ),
      SliverToBoxAdapter(child: _buildListBody(context, strings, config)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.settingsOf(context);
    final strings = context.strings;
    final config = controller.aiPresets.promptManager;
    _seedExpanded(config);

    // Root must be a [RenderSliver] when embedded; parent already rebuilds on
    // settings changes via its own [ListenableBuilder].
    if (widget.sliver) {
      return SliverMainAxisGroup(
        slivers: _slivers(context, strings, config),
      );
    }

    final mediaBottom = MediaQuery.paddingOf(context).bottom;
    final keyboardBottom = MediaQuery.viewInsetsOf(context).bottom;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final latest = controller.aiPresets.promptManager;
        _seedExpanded(latest);
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.only(
                top: AppTheme.pagePadding,
                bottom:
                    AppTheme.pagePadding + mediaBottom + keyboardBottom,
              ),
              sliver: SliverMainAxisGroup(
                slivers: _slivers(context, strings, latest),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PinnedPromptHeaderDelegate extends SliverPersistentHeaderDelegate {
  _PinnedPromptHeaderDelegate({
    required this.extent,
    required this.background,
    required this.child,
  });

  final double extent;
  final Color background;
  final Widget child;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: background,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: child,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedPromptHeaderDelegate oldDelegate) {
    return extent != oldDelegate.extent ||
        background != oldDelegate.background ||
        child != oldDelegate.child;
  }
}

class _CategoryBlock extends StatelessWidget {
  const _CategoryBlock({
    super.key,
    required this.reorderIndex,
    required this.category,
    required this.config,
    required this.expanded,
    required this.selection,
    required this.selected,
    required this.enableCrossDrag,
    required this.onToggleExpanded,
    required this.onSelect,
    required this.onRename,
    required this.onDelete,
    required this.onRowTap,
    required this.onAcceptSection,
  });

  final int reorderIndex;
  final PromptCategory category;
  final PromptManagerConfig config;
  final bool expanded;
  final AppListSelectionController selection;
  final bool selected;
  final bool enableCrossDrag;
  final VoidCallback onToggleExpanded;
  final VoidCallback onSelect;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final void Function(int index, PromptSection section, String key) onRowTap;
  final void Function(_SectionDragPayload payload) onAcceptSection;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final controller = AppScope.settingsOf(context);
    final scheme = Theme.of(context).colorScheme;
    final members = config.sectionsInCategory(category.id);
    final enabledCount = members.where((s) => s.enabled).length;
    final selectionActive = selection.active;

    final Widget leading;
    if (selectionActive) {
      leading = Icon(
        selected ? Icons.check_circle : Icons.circle_outlined,
        size: AppListTile.iconSize,
        color: selected ? scheme.primary : scheme.outline,
      );
    } else {
      leading = ReorderableDragStartListener(
        index: reorderIndex,
        child: Icon(
          Icons.drag_handle,
          size: AppListTile.iconSize,
          color: scheme.onSurfaceVariant,
        ),
      );
    }

    final header = DragTarget<_SectionDragPayload>(
      onWillAcceptWithDetails: (_) => enableCrossDrag,
      onAcceptWithDetails: (details) => onAcceptSection(details.data),
      builder: (context, candidate, rejected) {
        final hovering = candidate.isNotEmpty;
        return AppListTile(
          title: category.name,
          subtitle: strings.promptCategoryEnabledCount(
            enabledCount,
            members.length,
          ),
          leading: leading,
          selected: hovering ||
              (selectionActive ? selected : expanded),
          trailing: selectionActive
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIconButton(
                      icon: Icons.edit_outlined,
                      tooltip: strings.promptRenameCategoryTitle,
                      onPressed: onRename,
                    ),
                    if (members.isEmpty)
                      AppIconButton(
                        icon: Icons.delete_outline,
                        tooltip: strings.delete,
                        danger: true,
                        onPressed: onDelete,
                      ),
                    AppDisclosureIcon(expanded: expanded),
                  ],
                ),
          onTap: selectionActive ? onSelect : onToggleExpanded,
          onLongPress: selectionActive ? null : onRename,
          showDivider: !expanded,
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        if (expanded)
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: members.length,
            onReorderItem: (oldIndex, newIndex) async {
              if (selectionActive) return;
              await controller.updatePromptManager(
                config.reorderInCategory(
                  category.id,
                  oldIndex,
                  newIndex,
                ),
              );
            },
            itemBuilder: (context, localIndex) {
              final section = members[localIndex];
              final globalIndex =
                  PromptManagerPanel.indexOf(config, section);
              final key = PromptManagerPanel.sectionKey(section);
              return _SectionRow(
                key: ValueKey('cat-${category.id}-$key'),
                index: localIndex,
                globalIndex: globalIndex,
                section: section,
                label: PromptManagerPanel.sectionLabel(strings, section),
                config: config,
                selectionActive: selectionActive,
                selected: selection.isSelected(key),
                enableCrossDrag: enableCrossDrag,
                onTap: () => onRowTap(globalIndex, section, key),
              );
            },
          ),
      ],
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({
    super.key,
    required this.index,
    required this.globalIndex,
    required this.section,
    required this.label,
    required this.config,
    required this.selectionActive,
    required this.selected,
    required this.enableCrossDrag,
    required this.onTap,
  });

  final int index;
  final int globalIndex;
  final PromptSection section;
  final String label;
  final PromptManagerConfig config;
  final bool selectionActive;
  final bool selected;
  final bool enableCrossDrag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.settingsOf(context);
    final strings = context.strings;
    final scheme = Theme.of(context).colorScheme;
    final editable = section.isEditable;
    final selectable = section.isCustom;
    final key = PromptManagerPanel.sectionKey(section);

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

    final tile = AppListTile(
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
                if (globalIndex < 0) return;
                final next = config.toggleSectionByIndex(globalIndex);
                await controller.updatePromptManager(next);
              },
            ),
      onTap: onTap,
    );

    if (!enableCrossDrag || selectionActive || globalIndex < 0) {
      return tile;
    }

    return LongPressDraggable<_SectionDragPayload>(
      data: _SectionDragPayload(globalIndex: globalIndex, key: key),
      feedback: Material(
        elevation: 4,
        color: Theme.of(context).colorScheme.surface,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.85,
          ),
          child: AppListTile(
            title: label,
            icon: Icons.drag_indicator,
            showDivider: false,
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: tile),
      child: tile,
    );
  }
}
