import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/create/create_entry_page.dart';
import 'package:anoworld/data/project/folder_project_repository.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_empty_state.dart';
import 'package:anoworld/foundation/widgets/app_icon_button.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/project/project_hub_page.dart';
import 'package:anoworld/settings/settings_page.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.pickImportDirectory,
  });

  /// Injectable folder picker for tests / platforms without a dialog.
  final Future<String?> Function()? pickImportDirectory;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<ProjectSummary> _projects = const [];
  bool _loading = true;
  String? _status;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  Future<void> _reload() async {
    final projects = AppScope.projectsOf(context);
    setState(() {
      _loading = true;
      _status = null;
    });
    try {
      final list = await projects.listProjects();
      if (!mounted) return;
      setState(() {
        _projects = list;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _status = '加载作品失败：$error';
      });
    }
  }

  Future<void> _openRoute(Widget page) async {
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => page,
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
    if (mounted) await _reload();
  }

  Future<void> _openCreateEntry(CreateEntryKind kind) {
    return _openRoute(CreateEntryPage(kind: kind));
  }

  Future<void> _createBlank() async {
    final projects = AppScope.projectsOf(context);
    try {
      final project = await projects.create(title: '未命名作品');
      if (!mounted) return;
      await _openRoute(ProjectHubPage(projectId: project.meta.id));
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = '新建失败：$error');
    }
  }

  Future<void> _addSample() async {
    final projects = AppScope.projectsOf(context);
    try {
      final existing = await projects.listProjects();
      for (final row in existing) {
        if (row.id == 'proj_rain_night') {
          if (!mounted) return;
          await _openRoute(const ProjectHubPage(projectId: 'proj_rain_night'));
          return;
        }
      }
      final sample = const ProjectFactory().createRainNightSample();
      await projects.save(sample);
      if (!mounted) return;
      await _openRoute(ProjectHubPage(projectId: sample.meta.id));
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = '样例写入失败：$error');
    }
  }

  Future<void> _openProject(String id) {
    return _openRoute(ProjectHubPage(projectId: id));
  }

  Future<void> _importPack() async {
    final projects = AppScope.projectsOf(context);
    final picker = widget.pickImportDirectory ?? _defaultPickDirectory;
    final path = await picker();
    if (!mounted) return;
    if (path == null || path.isEmpty) return;
    try {
      final project = await projects.importFromDirectory(path);
      if (!mounted) return;
      setState(() => _status = '已导入「${project.meta.title}」');
      await _openRoute(ProjectHubPage(projectId: project.meta.id));
    } on ProjectIoException catch (error) {
      if (!mounted) return;
      setState(() => _status = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = '导入失败：$error');
    }
  }

  static Future<String?> _defaultPickDirectory() {
    return FilePicker.getDirectoryPath(dialogTitle: '选择 AnoWorld 作品包文件夹');
  }

  String _formatUpdated(DateTime updatedAt) {
    final local = updatedAt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '更新 $y-$m-$d';
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'AnoWorld',
      actions: [
        AppIconButton(
          icon: Icons.folder_open,
          tooltip: '导入作品包',
          onPressed: _importPack,
        ),
        AppIconButton(
          icon: Icons.settings,
          tooltip: '设置',
          onPressed: () => _openRoute(const SettingsPage()),
        ),
      ],
      body: AppPageBody(
        children: [
          const AppSectionHeader('开始创作'),
          AppButton(
            label: '导入角色卡',
            onPressed: () => _openCreateEntry(CreateEntryKind.characterCard),
            expanded: true,
          ),
          const SizedBox(height: AppTheme.spaceSm),
          AppButton(
            label: '粘贴故事',
            onPressed: () => _openCreateEntry(CreateEntryKind.novel),
            variant: AppButtonVariant.secondary,
            expanded: true,
          ),
          const SizedBox(height: AppTheme.spaceSm),
          AppButton(
            label: '分阶段提示词',
            onPressed: () => _openCreateEntry(CreateEntryKind.stagedPrompts),
            variant: AppButtonVariant.secondary,
            expanded: true,
          ),
          const SizedBox(height: AppTheme.spaceSm),
          AppButton(
            label: '新建空白作品',
            onPressed: _createBlank,
            variant: AppButtonVariant.ghost,
          ),
          const SizedBox(height: AppTheme.spaceLg),
          const AppSectionHeader('我的作品'),
          if (_status != null) ...[
            AppText(_status!, role: AppTextRole.caption),
            const SizedBox(height: AppTheme.spaceSm),
          ],
          if (_loading)
            const AppText('加载中…', role: AppTextRole.caption)
          else if (_projects.isEmpty)
            AppEmptyState(
              message: '还没有作品',
              detail: '导入、粘贴故事，或试用内置样例',
              action: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppButton(
                    label: '试用「雨夜投宿」',
                    onPressed: _addSample,
                    variant: AppButtonVariant.secondary,
                  ),
                  const SizedBox(height: AppTheme.spaceSm),
                  AppButton(
                    label: '新建空白作品',
                    onPressed: _createBlank,
                    variant: AppButtonVariant.ghost,
                  ),
                ],
              ),
            )
          else
            for (var i = 0; i < _projects.length; i++) ...[
              if (i > 0) const SizedBox(height: AppTheme.spaceSm),
              AppListTile(
                title: _projects[i].title,
                subtitle: _formatUpdated(_projects[i].updatedAt),
                icon: Icons.menu_book_outlined,
                onTap: () => _openProject(_projects[i].id),
              ),
            ],
        ],
      ),
    );
  }
}
