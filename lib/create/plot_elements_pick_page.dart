import 'dart:async';

import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/domain/models/plot_element.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_empty_state.dart';
import 'package:anoworld/foundation/widgets/app_icon_button.dart';
import 'package:anoworld/foundation/widgets/app_list_hairline.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_page_gutter.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/foundation/widgets/app_switch.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
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

class _PlotElementsPickPageState extends State<PlotElementsPickPage> {
  Project? _project;
  Object? _error;
  bool _loading = true;
  Timer? _saveDebounce;

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
      final project =
          await AppScope.projectsOf(context).open(widget.projectId);
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
    await pushStoryRoute<void>(
      context,
      const PlotElementsLibraryPage(),
    );
    if (mounted) setState(() {});
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
                          subtitle: _preview(rows[i]),
                          icon: Icons.auto_awesome_outlined,
                          trailing: AppSwitch(
                            value: selectedIds.contains(rows[i].id),
                            onChanged: (value) =>
                                _toggle(rows[i].id, value),
                          ),
                          showDivider: false,
                          onTap: () => _toggle(
                            rows[i].id,
                            !selectedIds.contains(rows[i].id),
                          ),
                        ),
                        if (i < rows.length - 1) const AppListHairline(),
                      ],
                    ],
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}
