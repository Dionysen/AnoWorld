import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/domain/models/plot_element_pack.dart';
import 'package:anoworld/domain/settings/plot_element_catalog.dart';import 'package:anoworld/foundation/theme/app_theme.dart';
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

  String _preview(PlotElementCatalog catalog, String elementId) {
    final element = catalog.byId(elementId);
    if (element == null) return '';
    final text = element.clippedDescription;
    if (text.isEmpty) return '还没写描述';
    return text.length > 48 ? '${text.substring(0, 48)}…' : text;
  }

  Future<void> _rename(BuildContext context, PlotElementPack pack) async {
    final settings = AppScope.settingsOf(context);
    final name = await askPlotElementPackName(
      context,
      title: '重命名包',
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
    final confirmed = await showAppConfirmSheet(
      context,
      title: '删除这个包？',
      detail: count == 0 ? '包是空的' : '包里的 $count 条元素仍留在库里',
      confirmLabel: '删除',
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
        final catalog = settings.plotElements;
        final pack = catalog.packById(packId);
        if (pack == null) {
          return AppPage(
            title: '包',
            onBack: () => Navigator.of(context).maybePop(),
            body: const AppPageBody.list(
              children: [
                AppPageGutter(
                  child: AppEmptyState(message: '这个包已经不在了'),
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
                selectedCount == 0 ? '还空着' : '$selectedCount 条',
                role: AppTextRole.caption,
              ),
            ),
          ),
          if (rows.isEmpty)
            const AppPageGutter(
              child: AppEmptyState(
                message: '库里还没有剧情元素',
                detail: '去剧情元素库加一条',
              ),
            ),
        ];
        return AppPage(
          title: pack.name,
          onBack: () => Navigator.of(context).maybePop(),
          actions: [
            AppIconButton(
              icon: Icons.edit_outlined,
              tooltip: '重命名包',
              onPressed: () => _rename(context, pack),
            ),
            AppIconButton(
              icon: Icons.delete_outline,
              tooltip: '删除包',
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
                title: element.keyword.isEmpty ? '未命名' : element.keyword,
                subtitle: _preview(catalog, element.id),
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
