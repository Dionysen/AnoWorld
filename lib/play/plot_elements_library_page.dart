import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/app/settings_controller.dart';
import 'package:anoworld/domain/models/plot_element.dart';
import 'package:anoworld/domain/settings/plot_element_catalog.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_circle_button.dart';
import 'package:anoworld/foundation/widgets/app_confirm_sheet.dart';
import 'package:anoworld/foundation/widgets/app_disclosure_icon.dart';
import 'package:anoworld/foundation/widgets/app_empty_state.dart';
import 'package:anoworld/foundation/widgets/app_icon_button.dart';
import 'package:anoworld/foundation/widgets/app_list_hairline.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_page_gutter.dart';
import 'package:anoworld/foundation/widgets/app_page_route.dart';
import 'package:anoworld/foundation/widgets/app_segmented.dart';
import 'package:anoworld/foundation/widgets/app_sheet.dart';
import 'package:anoworld/foundation/widgets/app_underline_tabs.dart';
import 'package:anoworld/play/plot_element_category_page.dart';
import 'package:anoworld/play/plot_element_category_ui.dart';
import 'package:anoworld/play/plot_element_editor.dart';
import 'package:flutter/material.dart';

/// Global plot-element library (CRUD). Managed under 玩法; stories only pick.
class PlotElementsLibraryPage extends StatefulWidget {
  const PlotElementsLibraryPage({super.key});

  @override
  State<PlotElementsLibraryPage> createState() =>
      _PlotElementsLibraryPageState();
}

enum _LibraryTab { all, categorized }

class _PlotElementsLibraryPageState extends State<PlotElementsLibraryPage> {
  var _tab = _LibraryTab.all;

  SettingsController get _settings => AppScope.settingsOf(context);

  String _preview(PlotElement element) {
    final text = element.clippedDescription;
    if (text.isEmpty) return '还没写描述';
    return text.length > 48 ? '${text.substring(0, 48)}…' : text;
  }

  String _countLabel(int count) => count == 0 ? '还空着' : '$count 条';

  String _rowSubtitle(PlotElementCatalog catalog, PlotElement element) {
    final parts = <String>[
      catalog.categoryNameOf(element.categoryId),
      if (catalog.isBuiltInId(element.id))
        catalog.isModifiedBuiltIn(element.id) ? '默认 · 已改' : '默认',
      _preview(element),
    ];
    return parts.join(' · ');
  }

  Future<void> _edit({PlotElement? existing}) async {
    final result = await showPlotElementEditor(context, existing: existing);
    if (result == null || !mounted) return;
    await commitPlotElementEdit(
      context,
      settings: _settings,
      existing: existing,
      result: result,
    );
  }

  Future<void> _createCategory() async {
    final name = await askPlotElementCategoryName(context, title: '新分类');
    if (name == null || !mounted) return;
    await _settings.addPlotElementCategory(name);
  }

  Future<void> _openCategory(String categoryId) async {
    await pushAppSlide(
      context,
      PlotElementCategoryPage(categoryId: categoryId),
    );
  }

  Future<void> _restoreAll() async {
    final confirmed = await showAppConfirmSheet(
      context,
      title: '全部恢复默认？',
      detail: '出厂条目会恢复原文并补回已删的；你自己加的保留',
      confirmLabel: '全部恢复',
    );
    if (!confirmed || !mounted) return;
    await _settings.restoreAllBuiltInPlotElements();
  }

  Future<void> _openMore() async {
    final action = await showAppSheet<String>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppTheme.spaceSm),
          AppListTile(
            title: '全部恢复默认',
            subtitle: '出厂条目恢复原文并补回已删的',
            icon: Icons.restart_alt_outlined,
            showDivider: false,
            onTap: () => Navigator.of(ctx).pop('restore_all'),
          ),
          const SizedBox(height: AppTheme.pagePadding),
        ],
      ),
    );
    if (action == 'restore_all' && mounted) {
      await _restoreAll();
    }
  }

  Widget _categoryRow({
    required String title,
    required int count,
    required IconData icon,
    required String categoryId,
  }) {
    return AppListTile(
      title: title,
      subtitle: _countLabel(count),
      icon: icon,
      trailing: const AppForwardIcon(),
      showDivider: false,
      onTap: () => _openCategory(categoryId),
    );
  }

  List<Widget> _categorySections(PlotElementCatalog catalog) {
    final uncategorizedCount = catalog.uncategorizedElements.length;
    final rows = <Widget>[
      for (final category in catalog.categories)
        _categoryRow(
          title: category.name,
          count: catalog.elementsOfCategory(category.id).length,
          icon: Icons.folder_outlined,
          categoryId: category.id,
        ),
      if (uncategorizedCount > 0)
        _categoryRow(
          title: PlotElementCatalog.uncategorizedLabel,
          count: uncategorizedCount,
          icon: Icons.label_outline,
          categoryId: '',
        ),
    ];
    return [
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i < rows.length - 1) const AppListHairline(),
          ],
        ],
      ),
      const SizedBox(height: AppTheme.spaceLg),
      AppListTile(
        title: '新建分类',
        subtitle: '给元素多一个归处',
        icon: Icons.create_new_folder_outlined,
        showDivider: false,
        onTap: _createCategory,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _settings,
      builder: (context, _) {
        final catalog = _settings.plotElements;
        final rows = catalog.effectiveList;
        return AppPage(
          title: '剧情元素库',
          onBack: () => Navigator.of(context).maybePop(),
          actions: [
            AppIconButton(
              icon: Icons.more_horiz,
              tooltip: '更多',
              onPressed: _openMore,
            ),
            AppCircleButton(
              icon: Icons.add,
              tooltip: '加一条',
              onPressed: () => _edit(),
            ),
          ],
          body: AppPageBody.list(
            children: [
              AppUnderlineTabs<_LibraryTab>(
                value: _tab,
                onChanged: (value) => setState(() => _tab = value),
                options: const [
                  AppSegmentOption(value: _LibraryTab.all, label: '全部'),
                  AppSegmentOption(value: _LibraryTab.categorized, label: '分类'),
                ],
              ),
              if (rows.isEmpty)
                AppPageGutter(
                  child: AppEmptyState(
                    message: '库是空的',
                    detail: '加一条，或全部恢复默认',
                    action: AppButton(
                      label: '加一条',
                      onPressed: () => _edit(),
                      variant: AppButtonVariant.secondary,
                    ),
                  ),
                )
              else if (_tab == _LibraryTab.all) ...[
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < rows.length; i++) ...[
                      AppListTile(
                        title: rows[i].keyword.isEmpty
                            ? '未命名'
                            : rows[i].keyword,
                        subtitle: _rowSubtitle(catalog, rows[i]),
                        icon: Icons.theater_comedy_outlined,
                        trailing: const AppForwardIcon(),
                        showDivider: false,
                        onTap: () => _edit(existing: rows[i]),
                      ),
                      if (i < rows.length - 1) const AppListHairline(),
                    ],
                  ],
                ),
              ] else
                ..._categorySections(catalog),
            ],
          ),
        );
      },
    );
  }
}
