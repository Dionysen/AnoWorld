import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_empty_state.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/play/play_session_page.dart';
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
  bool _hasSave = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadScheduled) return;
    _loadScheduled = true;
    _load();
  }

  Future<void> _load() async {
    final projects = AppScope.projectsOf(context);
    final saves = AppScope.savesOf(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final project = await projects.open(widget.projectId);
      final slot = await saves.load(widget.projectId);
      if (!mounted) return;
      setState(() {
        _project = project;
        _hasSave = slot != null;
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

  Future<void> _openPlay({required bool resume}) async {
    final project = _project;
    if (project == null) return;
    if (!resume) {
      await AppScope.savesOf(context).clear(widget.projectId);
      if (!mounted) return;
    }
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => PlaySessionPage(
          project: project,
          resumeSave: resume,
        ),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
    if (mounted) await _load();
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
            if (_hasSave) ...[
              AppButton(
                label: '继续游玩',
                onPressed: () => _openPlay(resume: true),
                expanded: true,
              ),
              const SizedBox(height: AppTheme.spaceSm),
              AppButton(
                label: '从头游玩',
                onPressed: () => _openPlay(resume: false),
                variant: AppButtonVariant.secondary,
                expanded: true,
              ),
            ] else
              AppButton(
                label: '开始游玩',
                onPressed: () => _openPlay(resume: false),
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
              '编辑功能还在完善。现在可以切换视觉小说或聊天模式先玩起来。',
              role: AppTextRole.caption,
            ),
          ],
        ],
      ),
    );
  }
}
