import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/app/l10n/app_strings.dart';
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

  String _title(BuildContext context, PlotElementCatalog catalog) =>
      categoryId.isEmpty
      ? context.strings.uncategorized
      : catalog.categoryNameOf(categoryId);

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
    final preview = _preview(context, element);
    if (!catalog.isBuiltInId(element.id)) return preview;
    return catalog.isModifiedBuiltIn(element.id)
        ? '${strings.builtInEditedTag} · $preview'
        : '${strings.builtInTag} · $preview';
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
      title: context.strings.renameCategory,
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
        final strings = context.strings;
        final catalog = settings.plotElements;
        final rows = catalog.elementsOfCategory(categoryId);
        final header = <Widget>[
          AppPageGutter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
              child: AppText(
                strings.countLabel(rows.length),
                role: AppTextRole.caption,
              ),
            ),
          ),
          if (rows.isEmpty)
            AppPageGutter(
              child: AppEmptyState(
                message: strings.categoryEmptyMessage,
                detail: strings.categoryEmptyDetail,
                action: AppButton(
                  label: strings.addOne,
                  onPressed: () => _edit(context),
                  variant: AppButtonVariant.secondary,
                ),
              ),
            ),
        ];
        return AppPage(
          title: _title(context, catalog),
          onBack: () => Navigator.of(context).maybePop(),
          actions: [
            if (categoryId.isNotEmpty)
              AppIconButton(
                icon: Icons.edit_outlined,
                tooltip: strings.renameCategory,
                onPressed: () => _rename(context),
              ),
            AppCircleButton(
              icon: Icons.add,
              tooltip: strings.addOne,
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
                title: row.keyword.isEmpty ? strings.unnamed : row.keyword,
                subtitle: _rowSubtitle(context, catalog, row),
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
