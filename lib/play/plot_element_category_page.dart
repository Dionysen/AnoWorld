import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/domain/models/plot_element.dart';
import 'package:anoworld/domain/settings/plot_element_catalog.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_circle_button.dart';
import 'package:anoworld/foundation/widgets/app_disclosure_icon.dart';
import 'package:anoworld/foundation/widgets/app_empty_state.dart';
import 'package:anoworld/foundation/widgets/app_icon_button.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_page_gutter.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/play/plot_element_category_ui.dart';
import 'package:anoworld/play/plot_element_editor.dart';
import 'package:flutter/material.dart';

/// Rows of one library category; empty [categoryId] is the 未分类 bucket.
class PlotElementCategoryPage extends StatelessWidget {
  const PlotElementCategoryPage({super.key, required this.categoryId});

  final String categoryId;

  String _title(PlotElementCatalog catalog) => categoryId.isEmpty
      ? PlotElementCatalog.uncategorizedLabel
      : catalog.categoryNameOf(categoryId);

  String _subtitle(PlotElementCatalog catalog) {
    final count = catalog.elementsOfCategory(categoryId).length;
    return count == 0 ? '还空着' : '$count 条';
  }

  String _preview(PlotElement element) {
    final text = element.clippedDescription;
    if (text.isEmpty) return '还没写描述';
    return text.length > 48 ? '${text.substring(0, 48)}…' : text;
  }

  Future<void> _edit(BuildContext context, {PlotElement? existing}) async {
    final settings = AppScope.settingsOf(context);
    final result = await showPlotElementEditor(
      context,
      existing: existing,
      initialCategoryId: categoryId,
    );
    if (result == null || !context.mounted) return;
    await commitPlotElementEdit(
      context,
      settings: settings,
      existing: existing,
      result: result,
    );
  }

  Future<void> _rename(BuildContext context) async {
    if (categoryId.isEmpty) return;
    final settings = AppScope.settingsOf(context);
    final name = await askPlotElementCategoryName(
      context,
      title: '重命名分类',
      initialName: settings.plotElements.categoryNameOf(categoryId),
    );
    if (name == null || !context.mounted) return;
    await settings.renamePlotElementCategory(categoryId, name);
  }

  String _rowSubtitle(PlotElementCatalog catalog, PlotElement element) {
    final preview = _preview(element);
    if (!catalog.isBuiltInId(element.id)) return preview;
    return catalog.isModifiedBuiltIn(element.id)
        ? '默认 · 已改 · $preview'
        : '默认 · $preview';
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.settingsOf(context);
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final catalog = settings.plotElements;
        final rows = catalog.elementsOfCategory(categoryId);
        final header = <Widget>[
          AppPageGutter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
              child: AppText(_subtitle(catalog), role: AppTextRole.caption),
            ),
          ),
          if (rows.isEmpty)
            AppPageGutter(
              child: AppEmptyState(
                message: '这个分类还空着',
                detail: '加一条，或在编辑条目时改分类',
                action: AppButton(
                  label: '加一条',
                  onPressed: () => _edit(context),
                  variant: AppButtonVariant.secondary,
                ),
              ),
            ),
        ];
        return AppPage(
          title: _title(catalog),
          onBack: () => Navigator.of(context).maybePop(),
          actions: [
            if (categoryId.isNotEmpty)
              AppIconButton(
                icon: Icons.edit_outlined,
                tooltip: '重命名分类',
                onPressed: () => _rename(context),
              ),
            AppCircleButton(
              icon: Icons.add,
              tooltip: '加一条',
              onPressed: () => _edit(context),
            ),
          ],
          body: AppPageLazyList(
            header: header,
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              return AppListTile(
                key: ValueKey(row.id),
                title: row.keyword.isEmpty ? '未命名' : row.keyword,
                subtitle: _rowSubtitle(catalog, row),
                icon: Icons.theater_comedy_outlined,
                trailing: const AppForwardIcon(),
                showDivider: index < rows.length - 1,
                onTap: () => _edit(context, existing: row),
              );
            },
          ),
        );
      },
    );
  }
}
