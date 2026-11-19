import 'dart:async';

import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/domain/models/plot_element.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/settings/plot_element_catalog.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_disclosure_icon.dart';
import 'package:anoworld/foundation/widgets/app_empty_state.dart';
import 'package:anoworld/foundation/widgets/app_icon_button.dart';
import 'package:anoworld/foundation/widgets/app_list_hairline.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_page_gutter.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/foundation/widgets/app_segmented.dart';
import 'package:anoworld/foundation/widgets/app_switch.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/foundation/widgets/app_underline_tabs.dart';
import 'package:anoworld/home/story_assistant_navigation.dart';
import 'package:anoworld/play/plot_elements_library_page.dart';
import 'package:flutter/material.dart';

/// Story-side plot-element picker: toggle ids from the global library only.
class PlotElementsPickPage extends StatefulWidget {
  const PlotElementsPickPage({super.key, required this.projectId});

  final String projectId;

  @override
  State<PlotElementsPickPage> createState() => _PlotElementsPickPageState();
}

enum _PickTab { all, categorized }

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

  String _subtitle(int selected, int total) {
    if (total == 0) return '库是空的';
    if (selected == 0) return '还没选';
    return '已选 $selected 项';
  }

  String _preview(PlotElement element) {
    final text = element.clippedDescription;
    if (text.isEmpty) return '还没写描述';
    return text.length > 48 ? '${text.substring(0, 48)}…' : text;
  }

  String _countLabel(int count) => count == 0 ? '还空着' : '$count 条';

  Widget _elementRow(PlotElement element, List<String> selectedIds) {
    final selected = selectedIds.contains(element.id);
    return AppListTile(
      title: element.keyword.isEmpty ? '未命名' : element.keyword,
      subtitle: _preview(element),
      icon: Icons.theater_comedy_outlined,
      trailing: AppSwitch(
        value: selected,
        onChanged: (value) => _toggle(element.id, value),
      ),
      showDivider: false,
      onTap: () => _toggle(element.id, !selected),
    );
  }

  List<Widget> _categoryRows(
    PlotElementCatalog catalog,
    List<String> selectedIds,
  ) {
    final uncategorizedCount = catalog.uncategorizedElements.length;
    final entries = <({String id, String name, int count})>[
      for (final category in catalog.categories)
        (
          id: category.id,
          name: category.name,
          count: catalog.elementsOfCategory(category.id).length,
        ),
      if (uncategorizedCount > 0)
        (
          id: '',
          name: PlotElementCatalog.uncategorizedLabel,
          count: uncategorizedCount,
        ),
    ];
    return [
      for (var i = 0; i < entries.length; i++) ...[
        AppListTile(
          title: entries[i].name,
          subtitle: _countLabel(entries[i].count),
          icon: entries[i].id.isEmpty
              ? Icons.label_outline
              : Icons.folder_outlined,
          trailing: const AppForwardIcon(),
          showDivider: false,
          onTap: () => _openCategory(catalog, entries[i].id),
        ),
        if (i < entries.length - 1) const AppListHairline(),
      ],
    ];
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
        final selectedIds = project?.plotElements.selectedIds ?? const [];
        final selectedCount = selectedIds
            .where((id) => catalog.byId(id) != null)
            .length;

        return AppPage(
          title: '剧情元素',
          onBack: () => Navigator.of(context).maybePop(),
          actions: [
            AppIconButton(
              icon: Icons.library_books_outlined,
              tooltip: '管理库',
              onPressed: _openLibrary,
            ),
          ],
          body: AppPageBody.list(
            children: [
              AppUnderlineTabs<_PickTab>(
                value: _tab,
                onChanged: (value) => setState(() => _tab = value),
                options: const [
                  AppSegmentOption(value: _PickTab.all, label: '全部'),
                  AppSegmentOption(value: _PickTab.categorized, label: '分类'),
                ],
              ),
              const SizedBox(height: AppTheme.spaceLg),
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
              else if (project != null) ...[
                AppSectionHeader(
                  '勾选进本故事',
                  subtitle: _subtitle(selectedCount, rows.length),
                  gutter: true,
                ),
                if (rows.isEmpty)
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
                  )
                else if (_tab == _PickTab.all)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < rows.length; i++) ...[
                        _elementRow(rows[i], selectedIds),
                        if (i < rows.length - 1) const AppListHairline(),
                      ],
                    ],
                  )
                else
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _categoryRows(catalog, selectedIds),
                  ),
              ],
            ],
          ),
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
    return AppPage(
      title: widget.title,
      onBack: () => Navigator.of(context).maybePop(),
      body: AppPageBody.list(
        children: [
          if (elements.isEmpty)
            AppPageGutter(
              child: AppEmptyState(message: '这个分类还空着', detail: '去玩法里把元素挪进来'),
            )
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < elements.length; i++) ...[
                  AppListTile(
                    title: elements[i].keyword.isEmpty
                        ? '未命名'
                        : elements[i].keyword,
                    subtitle: _preview(elements[i]),
                    icon: Icons.theater_comedy_outlined,
                    trailing: AppSwitch(
                      value: _selected.contains(elements[i].id),
                      onChanged: (value) => _toggle(elements[i].id, value),
                    ),
                    showDivider: false,
                    onTap: () => _toggle(
                      elements[i].id,
                      !_selected.contains(elements[i].id),
                    ),
                  ),
                  if (i < elements.length - 1) const AppListHairline(),
                ],
              ],
            ),
        ],
      ),
    );
  }
}
