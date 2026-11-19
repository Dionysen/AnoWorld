import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/app/l10n/app_strings.dart';
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
import 'package:anoworld/play/plot_element_pack_page.dart';
import 'package:anoworld/play/plot_element_pack_ui.dart';
import 'package:flutter/material.dart';

/// Global plot-element library (CRUD). Managed under 玩法; stories only pick.
class PlotElementsLibraryPage extends StatefulWidget {
  const PlotElementsLibraryPage({super.key});

  @override
  State<PlotElementsLibraryPage> createState() =>
      _PlotElementsLibraryPageState();
}

enum _LibraryTab { all, categorized, packs }

class _PlotElementsLibraryPageState extends State<PlotElementsLibraryPage> {
  var _tab = _LibraryTab.all;

  SettingsController get _settings => AppScope.settingsOf(context);

  String _preview(BuildContext context, PlotElement element) {
    final text = element.clippedDescription;
    if (text.isEmpty) return context.strings.noDescription;
    return text.length > 48 ? '${text.substring(0, 48)}…' : text;
  }

  String _rowSubtitle(
    BuildContext context,
    PlotElementCatalog catalog,
    PlotElement element,
  ) {
    final strings = context.strings;
    final parts = <String>[
      if (element.categoryId.isEmpty)
        strings.uncategorized
      else
        catalog.categoryNameOf(element.categoryId),
      if (catalog.isBuiltInId(element.id))
        catalog.isModifiedBuiltIn(element.id)
            ? strings.builtInEditedTag
            : strings.builtInTag,
      _preview(context, element),
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
    final name = await askPlotElementCategoryName(
      context,
      title: context.strings.newCategoryTitle,
    );
    if (name == null || !mounted) return;
    await _settings.addPlotElementCategory(name);
  }

  Future<void> _createPack() async {
    final name = await askPlotElementPackName(
      context,
      title: context.strings.newPack,
    );
    if (name == null || !mounted) return;
    final pack = await _settings.addPlotElementPack(name);
    if (!mounted) return;
    await _openPack(pack.id);
  }

  Future<void> _openPack(String packId) async {
    await pushAppSlide(context, PlotElementPackPage(packId: packId));
  }

  Future<void> _openCategory(String categoryId) async {
    await pushAppSlide(
      context,
      PlotElementCategoryPage(categoryId: categoryId),
    );
  }

  Future<void> _restoreAll() async {
    final strings = context.strings;
    final confirmed = await showAppConfirmSheet(
      context,
      title: strings.restoreAllConfirmTitle,
      detail: strings.restoreAllConfirmDetail,
      confirmLabel: strings.restoreAllConfirmLabel,
    );
    if (!confirmed || !mounted) return;
    await _settings.restoreAllBuiltInPlotElements();
  }

  Future<void> _openMore() async {
    final strings = context.strings;
    final action = await showAppSheet<String>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppTheme.spaceSm),
          AppListTile(
            title: strings.restoreAllBuiltIns,
            subtitle: strings.restoreAllBuiltInsHint,
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

  List<({String id, String name, int count})> _categoryEntries(
    BuildContext context,
    PlotElementCatalog catalog,
  ) {
    final rows = <({String id, String name, int count})>[
      for (final category in catalog.categories)
        (
          id: category.id,
          name: category.name,
          count: catalog.elementsOfCategory(category.id).length,
        ),
    ];
    final uncategorizedCount = catalog.uncategorizedElements.length;
    if (uncategorizedCount > 0) {
      rows.add((
        id: '',
        name: context.strings.uncategorized,
        count: uncategorizedCount,
      ));
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return ListenableBuilder(
      listenable: _settings,
      builder: (context, _) {
        final catalog = _settings.plotElements;
        final rows = catalog.effectiveList;
        return AppPage(
          title: strings.plotElementsLibraryTitle,
          onBack: () => Navigator.of(context).maybePop(),
          actions: [
            AppIconButton(
              icon: Icons.more_horiz,
              tooltip: strings.more,
              onPressed: _openMore,
            ),
            AppCircleButton(
              icon: Icons.add,
              tooltip: strings.addOne,
              onPressed: () => _edit(),
            ),
            if (_tab == _LibraryTab.packs)
              AppCircleButton(
                icon: Icons.playlist_add,
                tooltip: strings.newPack,
                onPressed: _createPack,
              )
            else
              AppCircleButton(
                icon: Icons.create_new_folder_outlined,
                tooltip: strings.newCategory,
                onPressed: _createCategory,
              ),
          ],
          body: _buildBody(context, catalog, rows),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    PlotElementCatalog catalog,
    List<PlotElement> rows,
  ) {
    final strings = context.strings;
    final header = <Widget>[
      AppUnderlineTabs<_LibraryTab>(
        value: _tab,
        onChanged: (value) => setState(() => _tab = value),
        options: [
          AppSegmentOption(value: _LibraryTab.all, label: strings.tabAll),
          AppSegmentOption(
            value: _LibraryTab.categorized,
            label: strings.tabCategorized,
          ),
          AppSegmentOption(value: _LibraryTab.packs, label: strings.tabPacks),
        ],
      ),
      if (rows.isEmpty)
        AppPageGutter(
          child: AppEmptyState(
            message: strings.libraryEmptyMessage,
            detail: strings.libraryEmptyDetail,
            action: AppButton(
              label: strings.addOne,
              onPressed: () => _edit(),
              variant: AppButtonVariant.secondary,
            ),
          ),
        )
      else if (_tab == _LibraryTab.packs && catalog.packs.isEmpty)
        AppPageGutter(
          child: AppEmptyState(
            message: strings.packsEmptyMessage,
            detail: strings.packsEmptyDetail,
            action: AppButton(
              label: strings.newPack,
              onPressed: _createPack,
              variant: AppButtonVariant.secondary,
            ),
          ),
        ),
    ];
    final categoryRows = _categoryEntries(context, catalog);
    final packRows = catalog.packs;
    final itemCount = rows.isEmpty
        ? 0
        : switch (_tab) {
            _LibraryTab.all => rows.length,
            _LibraryTab.categorized => categoryRows.length,
            _LibraryTab.packs => packRows.length,
          };
    return AppPageLazyList(
      header: header,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        switch (_tab) {
          case _LibraryTab.all:
            final row = rows[index];
            return AppListTile(
              key: ValueKey(row.id),
              title: row.keyword.isEmpty ? strings.unnamed : row.keyword,
              subtitle: _rowSubtitle(context, catalog, row),
              icon: Icons.theater_comedy_outlined,
              trailing: const AppForwardIcon(),
              showDivider: index < itemCount - 1,
              onTap: () => _edit(existing: row),
            );
          case _LibraryTab.categorized:
            final entry = categoryRows[index];
            return AppListTile(
              title: entry.name,
              subtitle: strings.countLabel(entry.count),
              icon: entry.id.isEmpty
                  ? Icons.label_outline
                  : Icons.folder_outlined,
              trailing: const AppForwardIcon(),
              showDivider: index < itemCount - 1,
              onTap: () => _openCategory(entry.id),
            );
          case _LibraryTab.packs:
            final pack = packRows[index];
            return AppListTile(
              key: ValueKey(pack.id),
              title: pack.name,
              subtitle: describePlotElementPack(context, catalog, pack),
              icon: Icons.inventory_2_outlined,
              trailing: const AppForwardIcon(),
              showDivider: index < itemCount - 1,
              onTap: () => _openPack(pack.id),
            );
        }
      },
    );
  }
}
