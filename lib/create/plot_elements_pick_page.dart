import 'dart:async';

import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/domain/models/plot_element.dart';
import 'package:anoworld/domain/models/plot_element_pack.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/settings/plot_element_catalog.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_confirm_sheet.dart';
import 'package:anoworld/foundation/widgets/app_disclosure_icon.dart';
import 'package:anoworld/foundation/widgets/app_empty_state.dart';
import 'package:anoworld/foundation/widgets/app_icon_button.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_page_gutter.dart';
import 'package:anoworld/foundation/widgets/app_segmented.dart';
import 'package:anoworld/foundation/widgets/app_switch.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/foundation/widgets/app_underline_tabs.dart';
import 'package:anoworld/home/story_assistant_navigation.dart';
import 'package:anoworld/play/plot_elements_library_page.dart';
import 'package:anoworld/play/plot_element_pack_ui.dart';
import 'package:flutter/material.dart';

/// Story-side plot-element picker: toggle ids from the global library only.
class PlotElementsPickPage extends StatefulWidget {
  const PlotElementsPickPage({super.key, required this.projectId});

  final String projectId;

  @override
  State<PlotElementsPickPage> createState() => _PlotElementsPickPageState();
}

enum _PickTab { all, categorized, packs }

class _PlotElementsPickPageState extends State<PlotElementsPickPage> {
  Project? _project;
  Object? _error;
  bool _loading = true;
  Timer? _saveDebounce;
  var _tab = _PickTab.all;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_project == null && _loading) {
      _load();
    }
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final project = await AppScope.projectsOf(context).open(widget.projectId);
      if (!mounted) return;
      setState(() {
        _project = project;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _persist(Project project) async {
    final stamped = project.copyWith(
      meta: project.meta.copyWith(updatedAt: DateTime.now().toUtc()),
    );
    await AppScope.projectsOf(context).save(stamped);
    if (!mounted) return;
    setState(() => _project = stamped);
  }

  void _scheduleSave(PlotElementSelection selection) {
    final current = _project;
    if (current == null) return;
    final next = current.copyWith(plotElements: selection);
    setState(() => _project = next);
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 280), () async {
      if (!mounted) return;
      await _persist(next);
    });
  }

  void _toggle(String id, bool selected) {
    final current = _project;
    if (current == null) return;
    _scheduleSave(current.plotElements.withToggle(id, selected: selected));
  }

  /// Switches a pack on/off. Only that pack's own elements change; anything
  /// shared with other applied packs or picked by hand is announced first.
  Future<void> _togglePack(
    PlotElementCatalog catalog,
    PlotElementPack pack, {
    required bool selected,
  }) async {
    final current = _project;
    if (current == null) return;
    final selection = current.plotElements;
    if (selected) {
      final plan = catalog.planPackApply(pack, selection);
      if (plan.isEmpty) return;
      if (plan.needsConfirm) {
        final confirmed = await showAppConfirmSheet(
          context,
          title: '「${pack.name}」和已选元素有重叠',
          detail: describePackApplyImpact(plan),
          confirmLabel: '仍然应用',
        );
        if (!confirmed || !mounted) return;
      }
      _scheduleSave(
        selection
            .withIds(plan.addedIds, selected: true)
            .withPackApplied(pack.id, applied: true),
      );
      return;
    }
    final plan = catalog.planPackRemove(pack, selection);
    if (plan.needsConfirm) {
      final confirmed = await showAppConfirmSheet(
        context,
        title: '取消「${pack.name}」？',
        detail: describePackRemoveImpact(plan),
        confirmLabel: '取消勾选',
      );
      if (!confirmed || !mounted) return;
    }
    _scheduleSave(
      selection
          .withIds(plan.removedIds, selected: false)
          .withPackApplied(pack.id, applied: false),
    );
  }

  Future<void> _openLibrary() async {
    await pushStoryRoute<void>(context, const PlotElementsLibraryPage());
    if (mounted) setState(() {});
  }

  Future<void> _openCategory(
    PlotElementCatalog catalog,
    String categoryId,
  ) async {
    final elements = catalog.elementsOfCategory(categoryId);
    await pushStoryRoute<void>(
      context,
      _PickCategoryPage(
        title: categoryId.isEmpty
            ? PlotElementCatalog.uncategorizedLabel
            : catalog.categoryNameOf(categoryId),
        elements: elements,
        initialSelectedIds:
            _project?.plotElements.selectedIds.toSet() ?? const <String>{},
        onToggle: _toggle,
      ),
    );
  }

  String _preview(PlotElement element) {
    final text = element.clippedDescription;
    if (text.isEmpty) return '还没写描述';
    return text.length > 48 ? '${text.substring(0, 48)}…' : text;
  }

  String _countLabel(int count) => count == 0 ? '还空着' : '$count 条';

  Widget _elementRow(
    PlotElement element,
    List<String> selectedIds, {
    bool showDivider = false,
  }) {
    final selected = selectedIds.contains(element.id);
    return AppListTile(
      key: ValueKey(element.id),
      title: element.keyword.isEmpty ? '未命名' : element.keyword,
      subtitle: _preview(element),
      icon: Icons.theater_comedy_outlined,
      trailing: AppSwitch(
        value: selected,
        onChanged: (value) => _toggle(element.id, value),
      ),
      showDivider: showDivider,
      onTap: () => _toggle(element.id, !selected),
    );
  }

  Widget _packRow(
    PlotElementCatalog catalog,
    PlotElementPack pack,
    PlotElementSelection selection, {
    bool showDivider = false,
  }) {
    final elements = catalog.elementsOfPack(pack);
    final applied = elements
        .where((e) => selection.selectedIds.contains(e.id))
        .length;
    final on = selection.hasPack(pack.id) && applied > 0;
    final subtitle = on || applied > 0
        ? '已选 $applied / ${elements.length} 条'
        : describePlotElementPack(catalog, pack);
    return AppListTile(
      key: ValueKey(pack.id),
      title: pack.name,
      subtitle: subtitle,
      icon: Icons.inventory_2_outlined,
      trailing: AppSwitch(
        value: on,
        onChanged: elements.isEmpty
            ? null
            : (value) => _togglePack(catalog, pack, selected: value),
      ),
      showDivider: showDivider,
      onTap: elements.isEmpty
          ? null
          : () => _togglePack(catalog, pack, selected: !on),
    );
  }

  List<({String id, String name, int count})> _categoryEntries(
    PlotElementCatalog catalog,
  ) {
    final entries = <({String id, String name, int count})>[
      for (final category in catalog.categories)
        (
          id: category.id,
          name: category.name,
          count: catalog.elementsOfCategory(category.id).length,
        ),
    ];
    final uncategorizedCount = catalog.uncategorizedElements.length;
    if (uncategorizedCount > 0) {
      entries.add((
        id: '',
        name: PlotElementCatalog.uncategorizedLabel,
        count: uncategorizedCount,
      ));
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.settingsOf(context);
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final catalog = settings.plotElements;
        final rows = catalog.effectiveList;
        final project = _project;
        final selection = project?.plotElements ?? const PlotElementSelection();
        final selectedIds = selection.selectedIds;
        final selectedCount = selectedIds
            .where((id) => catalog.byId(id) != null)
            .length;

        return AppPage(
          title: '剧情元素',
          onBack: () => Navigator.of(context).maybePop(),
          actions: [
            if (selectedCount > 0)
              AppText('已选 $selectedCount', role: AppTextRole.caption),
            AppIconButton(
              icon: Icons.library_books_outlined,
              tooltip: '管理库',
              onPressed: _openLibrary,
            ),
          ],
          body: _buildBody(catalog, rows, project, selection),
        );
      },
    );
  }

  Widget _buildBody(
    PlotElementCatalog catalog,
    List<PlotElement> rows,
    Project? project,
    PlotElementSelection selection,
  ) {
    final selectedIds = selection.selectedIds;
    final header = <Widget>[
      AppUnderlineTabs<_PickTab>(
        value: _tab,
        onChanged: (value) => setState(() => _tab = value),
        options: const [
          AppSegmentOption(value: _PickTab.all, label: '全部'),
          AppSegmentOption(value: _PickTab.categorized, label: '分类'),
          AppSegmentOption(value: _PickTab.packs, label: '包'),
        ],
      ),
      if (_loading)
        const AppPageGutter(
          child: AppText('加载中…', role: AppTextRole.caption),
        )
      else if (_error != null)
        AppPageGutter(
          child: AppEmptyState(
            message: '无法打开故事',
            detail: _error.toString(),
            action: AppButton(
              label: '重试',
              onPressed: _load,
              variant: AppButtonVariant.secondary,
            ),
          ),
        )
      else if (project != null && rows.isEmpty)
        AppPageGutter(
          child: AppEmptyState(
            message: '库里还没有剧情元素',
            detail: '去玩法里管理库',
            action: AppButton(
              label: '去管理库',
              onPressed: _openLibrary,
              variant: AppButtonVariant.secondary,
            ),
          ),
        ),
    ];
    final idle = _loading || _error != null || project == null || rows.isEmpty;
    if (idle) {
      return AppPageLazyList(
        header: header,
        itemCount: 0,
        itemBuilder: (context, index) => const SizedBox.shrink(),
      );
    }
    if (_tab == _PickTab.all) {
      return AppPageLazyList(
        header: header,
        itemCount: rows.length,
        itemBuilder: (context, index) => _elementRow(
          rows[index],
          selectedIds,
          showDivider: index < rows.length - 1,
        ),
      );
    }
    if (_tab == _PickTab.packs) {
      final packs = catalog.packs;
      return AppPageLazyList(
        header: [
          ...header,
          if (packs.isEmpty)
            AppPageGutter(
              child: AppEmptyState(
                message: '还没有包',
                detail: '去剧情元素库把常用元素打包',
                action: AppButton(
                  label: '去管理库',
                  onPressed: _openLibrary,
                  variant: AppButtonVariant.secondary,
                ),
              ),
            ),
        ],
        itemCount: packs.length,
        itemBuilder: (context, index) => _packRow(
          catalog,
          packs[index],
          selection,
          showDivider: index < packs.length - 1,
        ),
      );
    }
    final entries = _categoryEntries(catalog);
    return AppPageLazyList(
      header: header,
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return AppListTile(
          title: entry.name,
          subtitle: _countLabel(entry.count),
          icon: entry.id.isEmpty ? Icons.label_outline : Icons.folder_outlined,
          trailing: const AppForwardIcon(),
          showDivider: index < entries.length - 1,
          onTap: () => _openCategory(catalog, entry.id),
        );
      },
    );
  }
}

/// One category's elements with switches; toggles flow back to the picker.
class _PickCategoryPage extends StatefulWidget {
  const _PickCategoryPage({
    required this.title,
    required this.elements,
    required this.initialSelectedIds,
    required this.onToggle,
  });

  final String title;
  final List<PlotElement> elements;
  final Set<String> initialSelectedIds;
  final void Function(String id, bool selected) onToggle;

  @override
  State<_PickCategoryPage> createState() => _PickCategoryPageState();
}

class _PickCategoryPageState extends State<_PickCategoryPage> {
  late final Set<String> _selected = {...widget.initialSelectedIds};

  void _toggle(String id, bool selected) {
    setState(() {
      if (selected) {
        _selected.add(id);
      } else {
        _selected.remove(id);
      }
    });
    widget.onToggle(id, selected);
  }

  String _preview(PlotElement element) {
    final text = element.clippedDescription;
    if (text.isEmpty) return '还没写描述';
    return text.length > 48 ? '${text.substring(0, 48)}…' : text;
  }

  @override
  Widget build(BuildContext context) {
    final elements = widget.elements;
    if (elements.isEmpty) {
      return AppPage(
        title: widget.title,
        onBack: () => Navigator.of(context).maybePop(),
        body: AppPageBody.list(
          children: [
            AppPageGutter(
              child: AppEmptyState(
                message: '这个分类还空着',
                detail: '去玩法里把元素挪进来',
              ),
            ),
          ],
        ),
      );
    }
    return AppPage(
      title: widget.title,
      onBack: () => Navigator.of(context).maybePop(),
      body: AppPageLazyList(
        itemCount: elements.length,
        itemBuilder: (context, index) {
          final element = elements[index];
          return AppListTile(
            key: ValueKey(element.id),
            title: element.keyword.isEmpty ? '未命名' : element.keyword,
            subtitle: _preview(element),
            icon: Icons.theater_comedy_outlined,
            trailing: AppSwitch(
              value: _selected.contains(element.id),
              onChanged: (value) => _toggle(element.id, value),
            ),
            showDivider: index < elements.length - 1,
            onTap: () => _toggle(
              element.id,
              !_selected.contains(element.id),
            ),
          );
        },
      ),
    );
  }
}
