import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/create/background_editor_page.dart';
import 'package:anoworld/create/cast_editor_page.dart';
import 'package:anoworld/create/create_hub_page.dart';
import 'package:anoworld/create/main_graph/main_graph_page.dart';
import 'package:anoworld/create/preset_editor_page.dart';
import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_circle_button.dart';
import 'package:anoworld/foundation/widgets/app_detail_section_card.dart';
import 'package:anoworld/foundation/widgets/app_empty_state.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/foundation/theme/app_ui_tokens.dart';
import 'package:anoworld/play/play_session_page.dart';
import 'package:flutter/material.dart';

/// Story overview: cover, structured sections, play actions, per-section edit.
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

  Future<void> _play() async {
    final project = _project;
    if (project == null) return;
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => PlaySessionPage(project: project),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Future<void> _openEditor(Widget page) async {
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

  Future<void> _openCreateHub() async {
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) =>
            CreateHubPage(projectId: widget.projectId),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
    if (mounted) await _load();
  }

  String _backgroundBody(Project project) {
    if (project.background.entries.isEmpty) return '';
    return project.background.combinedText;
  }

  String _castBody(Project project) {
    if (project.cast.isEmpty) return '';
    return project.cast.map(_formatCastMember).join('\n\n');
  }

  static String _formatCastMember(CastMember member) {
    final lines = <String>[member.name];
    final summary = member.summary.trim();
    if (summary.isNotEmpty) lines.add(summary);
    final personality = member.personality.trim();
    if (personality.isNotEmpty) lines.add(personality);
    final speech = member.speechStyle.trim();
    if (speech.isNotEmpty) lines.add(speech);
    return lines.join('\n');
  }

  String _mainBody(Project project) {
    final summary = project.main.summary.trim();
    if (summary.isNotEmpty) return summary;
    final nodes = project.main.nodes;
    if (nodes.isEmpty) return '';
    return nodes
        .take(5)
        .map((n) => n.title.trim().isEmpty ? n.id : n.title.trim())
        .join(' → ');
  }

  String _mainSubtitle(Project project) {
    final nodes = project.main.nodes.length;
    final edges = project.main.edges.length;
    if (nodes == 0) return '还没有大情节站';
    return '$nodes 站 · $edges 条连线';
  }

  String _presetBody(Project project) {
    final preset = project.activePreset;
    final notes = <String>[
      if (preset.styleNotes.trim().isNotEmpty) preset.styleNotes.trim(),
    ];
    if (preset.outputPreferences.isNotEmpty) {
      notes.add('更想要：${preset.outputPreferences.join('、')}');
    }
    if (preset.outputBans.isNotEmpty) {
      notes.add('不要：${preset.outputBans.join('、')}');
    }
    return notes.join('\n\n');
  }

  String _teaserLine(Project project) {
    final main = project.main.summary.trim();
    if (main.isNotEmpty) {
      return main.length > 48 ? '${main.substring(0, 48)}…' : main;
    }
    final bg = project.background.alwaysOnText.trim();
    if (bg.isNotEmpty) {
      final flat = bg.replaceAll('\n', ' ');
      return flat.length > 48 ? '${flat.substring(0, 48)}…' : flat;
    }
    final cast = project.cast;
    if (cast.isNotEmpty) {
      final names = cast.take(3).map((c) => c.name).join('、');
      return cast.length > 3 ? '$names 等' : names;
    }
    return '先看一看概要，再开始游玩或继续改';
  }

  Widget _storyCover(BuildContext context, String title) {
    final scheme = Theme.of(context).colorScheme;
    final letter = title.isEmpty ? '?' : title.characters.first;
    return ColoredBox(
      color: scheme.primary.withValues(alpha: 0.16),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            color: scheme.primary,
            fontWeight: FontWeight.w700,
            fontSize: 56,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final project = _project;
    final title =
        project?.meta.title.trim().isEmpty == true ||
                project == null
            ? '未命名故事'
            : project.meta.title;

    final ready = project != null && !_loading && _error == null;

    return AppPage(
      title: title,
      onBack: () => Navigator.of(context).maybePop(),
      actions: ready
          ? [
              AppCircleButton(
                icon: Icons.edit_note_outlined,
                tooltip: '继续创作',
                variant: AppCircleButtonVariant.tonal,
                onPressed: _openCreateHub,
              ),
            ]
          : const [],
      floatingActionButton: ready
          ? SizedBox.square(
              dimension: AppCircleButton.fabDiameter,
              child: AppCircleButton.fab(
                icon: Icons.play_arrow_rounded,
                tooltip: '开始游玩',
                onPressed: _play,
              ),
            )
          : null,
      body: AppPageBody(
        children: [
          if (_loading)
            const AppText('加载中…', role: AppTextRole.caption)
          else if (_error != null)
            AppEmptyState(
              message: '无法打开故事',
              detail: _error.toString(),
              action: AppButton(
                label: '重试',
                onPressed: _load,
                variant: AppButtonVariant.secondary,
              ),
            )
          else if (project != null) ...[
            ClipRRect(
              borderRadius: AppUiTokens.of(context).shape().borderRadius,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: _storyCover(context, project.meta.title),
              ),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            AppText(_teaserLine(project), role: AppTextRole.caption),
            const SizedBox(height: AppTheme.spaceLg),
            const AppSectionHeader(
              '故事内容',
              subtitle: '可展开查看，点编辑改对应部分',
            ),
            AppDetailSectionCard(
              title: '背景设定',
              icon: Icons.public_outlined,
              body: _backgroundBody(project),
              emptyHint: '还没有世界观与设定',
              onEdit: () => _openEditor(
                BackgroundEditorPage(projectId: widget.projectId),
              ),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            AppDetailSectionCard(
              title: '角色',
              icon: Icons.groups_outlined,
              body: _castBody(project),
              emptyHint: '还没有角色',
              previewLines: 4,
              onEdit: () => _openEditor(
                CastEditorPage(projectId: widget.projectId),
              ),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            AppDetailSectionCard(
              title: '情节走向',
              icon: Icons.account_tree_outlined,
              body: _mainBody(project),
              emptyHint: _mainSubtitle(project),
              onEdit: () => _openEditor(
                MainGraphPage(projectId: widget.projectId),
              ),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            AppDetailSectionCard(
              title: '文风',
              icon: Icons.tune_outlined,
              body: _presetBody(project),
              emptyHint: '使用默认文风，${project.activePreset.name}',
              onEdit: () => _openEditor(
                PresetEditorPage(projectId: widget.projectId),
              ),
            ),
            const SizedBox(
              height: AppCircleButton.fabDiameter + AppTheme.spaceLg,
            ),
          ],
        ],
      ),
    );
  }
}