import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/create/background_editor_page.dart';
import 'package:anoworld/create/cast_editor_page.dart';
import 'package:anoworld/create/main_graph/main_graph_page.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_disclosure_icon.dart';
import 'package:anoworld/foundation/widgets/app_empty_state.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_page_gutter.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:flutter/material.dart';

/// Creation cross-section: pick Background / Cast / Main to edit.
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
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => page,
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
    if (mounted) await _load();
  }

  String _backgroundSubtitle(Project project) {
    final count = project.background.entries.length;
    if (count == 0) return '还没有设定条目';
    final always =
        project.background.entries.where((e) => e.alwaysOn).length;
    return '$count 条设定，其中 $always 条常驻';
  }

  String _castSubtitle(Project project) {
    final count = project.cast.length;
    if (count == 0) return '还没有角色';
    final names = project.cast.take(3).map((c) => c.name).join('、');
    return count <= 3 ? names : '$names 等 $count 人';
  }

  String _mainSubtitle(Project project) {
    final nodes = project.main.nodes.length;
    final edges = project.main.edges.length;
    if (project.main.summary.trim().isEmpty) {
      return '$nodes 站 · $edges 条连线';
    }
    final summary = project.main.summary.trim();
    final short =
        summary.length > 24 ? '${summary.substring(0, 24)}…' : summary;
    return '$short · $nodes 站';
  }

  @override
  Widget build(BuildContext context) {
    final project = _project;
    return AppPage(
      title: '创作',
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
          else if (project != null) ...[
            AppSectionHeader(
              project.meta.title,
              subtitle: '改设定、角色与情节走向',
              gutter: true,
            ),
            AppListTileStack(
              tiles: [
                AppListTile(
                  title: '背景设定',
                  subtitle: _backgroundSubtitle(project),
                  icon: Icons.public_outlined,
                  trailing: const AppForwardIcon(),
                  onTap: () => _open(
                    BackgroundEditorPage(projectId: widget.projectId),
                  ),
                ),
                AppListTile(
                  title: '角色',
                  subtitle: _castSubtitle(project),
                  icon: Icons.groups_outlined,
                  trailing: const AppForwardIcon(),
                  onTap: () => _open(
                    CastEditorPage(projectId: widget.projectId),
                  ),
                ),
                AppListTile(
                  title: '情节走向',
                  subtitle: _mainSubtitle(project),
                  icon: Icons.account_tree_outlined,
                  trailing: const AppForwardIcon(),
                  onTap: () => _open(
                    MainGraphPage(projectId: widget.projectId),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
