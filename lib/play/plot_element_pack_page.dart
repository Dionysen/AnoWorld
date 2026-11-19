import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/domain/models/plot_element_pack.dart';
import 'package:anoworld/domain/settings/plot_element_catalog.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_confirm_sheet.dart';
import 'package:anoworld/foundation/widgets/app_empty_state.dart';
import 'package:anoworld/foundation/widgets/app_icon_button.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_page_gutter.dart';
import 'package:anoworld/foundation/widgets/app_switch.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/play/plot_element_pack_ui.dart';
import 'package:flutter/material.dart';

/// Membership editor for one pack: toggle which library elements it bundles.
class PlotElementPackPage extends StatelessWidget {
  const PlotElementPackPage({super.key, required this.packId});

  final String packId;

  String _preview(BuildContext context, PlotElementCatalog catalog, String id) {
    final element = catalog.byId(id);
    if (element == null) return '';
    final text = element.clippedDescription;
    if (text.isEmpty) return context.strings.noDescription;
    return text.length > 48 ? '${text.substring(0, 48)}…' : text;
  }

  Future<void> _rename(
    BuildContext context,
    PlotElementPack pack,
  ) async {
    final settings = AppScope.settingsOf(context);
    final name = await askPlotElementPackName(
      context,
      title: context.strings.renamePack,
      initialName: pack.name,
    );
    if (name == null || !context.mounted) return;
    await settings.renamePlotElementPack(pack.id, name);
  }

  Future<void> _delete(
    BuildContext context,
    PlotElementPack pack,
    int count,
  ) async {
    final strings = context.strings;
    final confirmed = await showAppConfirmSheet(
      context,
      title: strings.deletePackTitle,
      detail: count == 0
          ? strings.deletePackEmptyDetail
          : strings.packDeleteDetail(count),
      confirmLabel: strings.delete,
      danger: true,
    );
    if (!confirmed || !context.mounted) return;
    final navigator = Navigator.of(context);
    await AppScope.settingsOf(context).deletePlotElementPack(pack.id);
    if (navigator.canPop()) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.settingsOf(context);
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final strings = context.strings;
        final catalog = settings.plotElements;
        final pack = catalog.packById(packId);
        if (pack == null) {
          return AppPage(
            title: strings.packTitleFallback,
            onBack: () => Navigator.of(context).maybePop(),
            body: AppPageBody.list(
              children: [
                AppPageGutter(
                  child: AppEmptyState(message: strings.packMissing),
                ),
              ],
            ),
          );
        }
        final rows = catalog.effectiveList;
        final selectedCount = catalog.elementsOfPack(pack).length;
        final header = <Widget>[
          AppPageGutter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
              child: AppText(
                strings.countLabel(selectedCount),
                role: AppTextRole.caption,
              ),
            ),
          ),
          if (rows.isEmpty)
            AppPageGutter(
              child: AppEmptyState(
                message: strings.libraryEmptyMessage,
                detail: strings.packEmptyLibraryDetail,
              ),
            ),
        ];
        return AppPage(
          title: pack.name,
          onBack: () => Navigator.of(context).maybePop(),
          actions: [
            AppIconButton(
              icon: Icons.edit_outlined,
              tooltip: strings.renamePack,
              onPressed: () => _rename(context, pack),
            ),
            AppIconButton(
              icon: Icons.delete_outline,
              tooltip: strings.deletePack,
              danger: true,
              onPressed: () => _delete(context, pack, selectedCount),
            ),
          ],
          body: AppPageLazyList(
            header: header,
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final element = rows[index];
              final selected = pack.contains(element.id);
              return AppListTile(
                key: ValueKey(element.id),
                title: element.keyword.isEmpty
                    ? strings.unnamed
                    : element.keyword,
                subtitle: _preview(context, catalog, element.id),
                icon: Icons.theater_comedy_outlined,
                trailing: AppSwitch(
                  value: selected,
                  onChanged: (value) => settings.savePlotElementPack(
                    pack.withToggle(element.id, selected: value),
                  ),
                ),
                showDivider: index < rows.length - 1,
                onTap: () => settings.savePlotElementPack(
                  pack.withToggle(element.id, selected: !selected),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
