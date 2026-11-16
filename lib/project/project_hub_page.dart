import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_empty_state.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/play/play_placeholder_page.dart';
import 'package:flutter/widgets.dart';

/// After opening a work: play or continue editing (edit UI comes later).
class ProjectHubPage extends StatefulWidget {
  const ProjectHubPage({super.key, required this.projectId});

  final String projectId;

  @override
  State<ProjectHubPage> createState() => _ProjectHubPageState();
}

class _ProjectHubPageState extends State<ProjectHubPage> {
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
    final projects = AppScope.projectsOf(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final project = await projects.open(widget.projectId);
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

  void _openPlay() {
    final project = _project;
    if (project == null) return;
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => PlayPlaceholderPage(project: project),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final project = _project;
    return AppPage(
      title: project?.meta.title ?? '作品',
      onBack: () => Navigator.of(context).maybePop(),
      body: AppPageBody(
        children: [
          if (_loading)
            const AppText('加载中…', role: AppTextRole.caption)
          else if (_error != null)
            AppEmptyState(
              message: '无法打开作品',
              detail: _error.toString(),
              action: AppButton(
                label: '重试',
                onPressed: _load,
                variant: AppButtonVariant.secondary,
              ),
            )
          else if (project != null) ...[
            AppText(
              project.main.summary.isEmpty ? '尚无主线概括' : project.main.summary,
              role: AppTextRole.body,
              maxLines: 3,
            ),
            const SizedBox(height: AppTheme.spaceLg),
            const AppSectionHeader('下一步'),
            AppButton(
              label: '开始游玩',
              onPressed: _openPlay,
              expanded: true,
            ),
            const SizedBox(height: AppTheme.spaceSm),
            const AppButton(
              label: '继续创作',
              onPressed: null,
              variant: AppButtonVariant.secondary,
              expanded: true,
            ),
            const SizedBox(height: AppTheme.spaceSm),
            const AppText(
              '创作编辑器下一阶段接入；现在可先游玩样例或空白开场。',
              role: AppTextRole.caption,
            ),
          ],
        ],
      ),
    );
  }
}
