import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/create/background_editor_page.dart';
import 'package:anoworld/create/cast_editor_page.dart';
import 'package:anoworld/create/create_hub_page.dart';
import 'package:anoworld/create/main_graph/main_graph_page.dart';
import 'package:anoworld/create/preset_editor_page.dart';
import 'package:anoworld/domain/models/background.dart';
import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/models/story_node_kind.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_circle_button.dart';
import 'package:anoworld/foundation/widgets/app_detail_entry.dart';
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

  List<AppDetailEntry> _backgroundEntries(Project project) {
    final entries = project.background.entries;
    if (entries.isEmpty) return const [];
    final always = entries.where((e) => e.alwaysOn);
    final keyed = entries.where((e) => !e.alwaysOn);
    return [...always, ...keyed].map(_backgroundEntry).toList(growable: false);
  }

  static AppDetailEntry _backgroundEntry(BackgroundEntry entry) {
    final title = entry.title.trim();
    return AppDetailEntry(
      title: title.isEmpty ? '未命名条目' : title,
      tags: _backgroundTags(entry),
      body: entry.body.trim(),
    );
  }

  static List<String> _backgroundTags(BackgroundEntry entry) {
    if (entry.alwaysOn) return const <String>['常驻'];
    if (entry.keys.isEmpty) return const <String>['按需'];
    return entry.keys;
  }

  List<AppDetailEntry> _castEntries(Project project) {
    return project.cast.map(_castEntry).toList(growable: false);
  }

  static AppDetailEntry _castEntry(CastMember member) {
    final tags = <String>[
      if (member.exampleLines.isNotEmpty) '示例对白',
    ];
    return AppDetailEntry(
      title: member.name.trim().isEmpty ? '未命名角色' : member.name.trim(),
      tags: tags,
      body: _castEntryBody(member),
    );
  }

  static String _castEntryBody(CastMember member) {
    final parts = <String>[
      if (member.summary.trim().isNotEmpty) member.summary.trim(),
      if (member.personality.trim().isNotEmpty) member.personality.trim(),
      if (member.speechStyle.trim().isNotEmpty) member.speechStyle.trim(),
    ];
    if (member.exampleLines.isNotEmpty) {
      parts.add(
        member.exampleLines
            .map((line) => '「${line.trim()}」')
            .where((line) => line != '「」')
            .join('\n'),
      );
    }
    return parts.join('\n\n');
  }

  List<AppDetailEntry> _mainEntries(Project project) {
    final main = project.main;
    final rows = <AppDetailEntry>[];
    final summary = main.summary.trim();
    if (summary.isNotEmpty) {
      rows.add(
        AppDetailEntry(
          title: '脉络摘要',
          tags: const <String>['概要'],
          body: summary,
        ),
      );
    }
    for (final node in main.nodes) {
      rows.add(_mainNodeEntry(node));
    }
    return rows;
  }

  static AppDetailEntry _mainNodeEntry(StoryNode node) {
    final title = node.title.trim();
    final kind = StoryNodeKind.fromTags(node.tags);
    final extraTags = node.tags
        .where((t) => !StoryNodeKind.tagNames.contains(t))
        .toList(growable: false);
    return AppDetailEntry(
      title: title.isEmpty ? node.id : title,
      tags: <String>[kind.label, ...extraTags],
      body: node.synopsis?.trim() ?? '',
    );
  }

  String _mainSubtitle(Project project) {
    final nodes = project.main.nodes.length;
    final edges = project.main.edges.length;
    if (nodes == 0) return '还没有大情节站';
    return '$nodes 站 · $edges 条连线';
  }

  List<AppDetailEntry> _presetEntries(Project project) {
    final preset = project.activePreset;
    final rows = <AppDetailEntry>[];
    final notes = preset.styleNotes.trim();
    if (notes.isNotEmpty) {
      rows.add(
        AppDetailEntry(
          title: '预设说明',
          tags: <String>[preset.name],
          body: notes,
        ),
      );
    }
    if (preset.outputPreferences.isNotEmpty) {
      rows.add(
        AppDetailEntry(
          title: '更想要',
          tags: preset.outputPreferences,
          body: '',
        ),
      );
    }
    if (preset.outputBans.isNotEmpty) {
      rows.add(
        AppDetailEntry(
          title: '不要',
          tags: preset.outputBans,
          body: '',
        ),
      );
    }
    return rows;
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
              subtitle: '分条预览，点右上角展开全文',
            ),
            AppDetailSectionCard(
              title: '背景设定',
              icon: Icons.public_outlined,
              entries: _backgroundEntries(project),
              emptyHint: '还没有世界观与设定',
              onEdit: () => _openEditor(
                BackgroundEditorPage(projectId: widget.projectId),
              ),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            AppDetailSectionCard(
              title: '角色',
              icon: Icons.groups_outlined,
              entries: _castEntries(project),
              emptyHint: '还没有角色',
              onEdit: () => _openEditor(
                CastEditorPage(projectId: widget.projectId),
              ),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            AppDetailSectionCard(
              title: '情节走向',
              icon: Icons.account_tree_outlined,
              entries: _mainEntries(project),
              emptyHint: _mainSubtitle(project),
              onEdit: () => _openEditor(
                MainGraphPage(projectId: widget.projectId),
              ),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            AppDetailSectionCard(
              title: '预设',
              icon: Icons.tune_outlined,
              entries: _presetEntries(project),
              emptyHint: '使用默认预设，${project.activePreset.name}',
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