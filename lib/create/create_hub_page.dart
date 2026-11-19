import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/create/world_book_editor_page.dart';
import 'package:anoworld/create/cast_editor_page.dart';
import 'package:anoworld/create/main_graph/main_graph_page.dart';
import 'package:anoworld/create/plot_elements_pick_page.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/project/project_token_estimate.dart';
import 'package:anoworld/domain/settings/plot_element_catalog.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_disclosure_icon.dart';
import 'package:anoworld/foundation/widgets/app_empty_state.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_page_gutter.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/home/story_assistant_navigation.dart';
import 'package:flutter/material.dart';

/// Creation cross-section: pick WorldBook / Cast / Main to edit.
class CreateHubPage extends StatefulWidget {
  const CreateHubPage({super.key, required this.projectId});

  final String projectId;

  @override
  State<CreateHubPage> createState() => _CreateHubPageState();
}

class _CreateHubPageState extends State<CreateHubPage> {
  Project? _project;
  Object? _error;
  bool _loading = true;
  bool _loadScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadScheduled) return;
    _loadScheduled = true;
    _load();
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

  Future<void> _open(Widget page) async {
    await pushStoryRoute<void>(context, page);
    if (mounted) await _load();
  }

  String _worldBookSubtitle(Project project, ProjectTokenEstimate size) {
    return describeWorldBookSize(
      entries: project.worldBook.entries.length,
      alwaysOn: project.worldBook.entries.where((e) => e.alwaysOn).length,
      tokens: size.worldBook,
    );
  }

  String _castSubtitle(Project project, ProjectTokenEstimate size) {
    return describeCastSize(
      members: project.cast.length,
      tokens: size.cast,
    );
  }

  String _mainSubtitle(Project project, ProjectTokenEstimate size) {
    return describeMainSize(
      nodes: project.main.nodes.length,
      tokens: size.main,
    );
  }

  String _plotElementsSubtitle(
    Project project,
    ProjectTokenEstimate size,
    PlotElementCatalog catalog,
  ) {
    return describePlotElementsSize(
      selected:
          catalog.resolveSelected(project.plotElements.selectedIds).length,
      tokens: size.plotElements,
    );
  }

  String _pageTitle(Project? project) {
    final name = project?.meta.title.trim();
    if (name == null || name.isEmpty) return '创作·未命名故事';
    return '创作·$name';
  }

  @override
  Widget build(BuildContext context) {
    final project = _project;
    final catalog = AppScope.settingsOf(context).plotElements;
    final size = project == null
        ? null
        : ProjectTokenEstimate.of(project, plotCatalog: catalog);
    return AppPage(
      title: _pageTitle(project),
      onBack: () => Navigator.of(context).maybePop(),
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
          else if (project != null && size != null)
            AppListTileStack(
              tiles: [
                AppListTile(
                  title: '世界书',
                  subtitle: _worldBookSubtitle(project, size),
                  icon: Icons.public_outlined,
                  trailing: const AppForwardIcon(),
                  onTap: () => _open(
                    WorldBookEditorPage(projectId: widget.projectId),
                  ),
                ),
                AppListTile(
                  title: '角色',
                  subtitle: _castSubtitle(project, size),
                  icon: Icons.groups_outlined,
                  trailing: const AppForwardIcon(),
                  onTap: () => _open(
                    CastEditorPage(projectId: widget.projectId),
                  ),
                ),
                AppListTile(
                  title: '情节走向',
                  subtitle: _mainSubtitle(project, size),
                  icon: Icons.account_tree_outlined,
                  trailing: const AppForwardIcon(),
                  onTap: () => _open(
                    MainGraphPage(projectId: widget.projectId),
                  ),
                ),
                AppListTile(
                  title: '剧情元素',
                  subtitle: _plotElementsSubtitle(project, size, catalog),
                  icon: Icons.theater_comedy_outlined,
                  trailing: const AppForwardIcon(),
                  onTap: () => _open(
                    PlotElementsPickPage(projectId: widget.projectId),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
