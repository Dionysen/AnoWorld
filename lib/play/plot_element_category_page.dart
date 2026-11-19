import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/domain/models/plot_element.dart';
import 'package:anoworld/domain/settings/plot_element_catalog.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_circle_button.dart';
import 'package:anoworld/foundation/widgets/app_disclosure_icon.dart';
import 'package:anoworld/foundation/widgets/app_empty_state.dart';
import 'package:anoworld/foundation/widgets/app_icon_button.dart';
import 'package:anoworld/foundation/widgets/app_list_hairline.dart';
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

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.settingsOf(context);
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final catalog = settings.plotElements;
        final rows = catalog.elementsOfCategory(categoryId);
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
          body: AppPageBody.list(
            children: [
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
                )
              else
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < rows.length; i++) ...[
                      AppListTile(
                        title: rows[i].keyword.isEmpty
                            ? '未命名'
                            : rows[i].keyword,
                        subtitle: catalog.isBuiltInId(rows[i].id)
                            ? (catalog.isModifiedBuiltIn(rows[i].id)
                                  ? '默认 · 已改 · ${_preview(rows[i])}'
                                  : '默认 · ${_preview(rows[i])}')
                            : _preview(rows[i]),
                        icon: Icons.theater_comedy_outlined,
                        trailing: const AppForwardIcon(),
                        showDivider: false,
                        onTap: () => _edit(context, existing: rows[i]),
                      ),
                      if (i < rows.length - 1) const AppListHairline(),
                    ],
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
