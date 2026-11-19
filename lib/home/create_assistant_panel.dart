import 'dart:async';

import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/domain/ai/ai_prompt_context.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/ai/create/create_agent_runner.dart';
import 'package:anoworld/domain/ai/create/create_tool_context.dart';
import 'package:anoworld/domain/ai/create/create_tool_services.dart';
import 'package:anoworld/domain/main/main_graph_document.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/repositories/project_repository.dart';
import 'package:anoworld/domain/settings/plot_element_catalog.dart';
import 'package:anoworld/foundation/logging/app_log.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_chat_composer.dart';
import 'package:anoworld/foundation/widgets/app_empty_state.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_select_field.dart';
import 'package:anoworld/foundation/widgets/app_sheet.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/home/create_assistant_draft.dart';
import 'package:anoworld/home/create_assistant_draft_store.dart';
import 'package:flutter/material.dart';

/// Create-assistant conversation body (inside [CreateAssistantBloomShell]).
class CreateAssistantPanel extends StatefulWidget {
  const CreateAssistantPanel({
    super.key,
    this.draftStore,
  });

  /// Injectable for tests; defaults to SharedPreferences-backed store.
  final CreateAssistantDraftStore? draftStore;

  /// Minimum panel height before layout chrome + composer can fit.
  static const minLayoutHeight = 380;

  @override
  State<CreateAssistantPanel> createState() => CreateAssistantPanelState();
}

class CreateAssistantPanelState extends State<CreateAssistantPanel> {
  final _composer = TextEditingController();
  late final CreateAssistantDraftStore _store =
      widget.draftStore ?? CreateAssistantDraftStore();

  String? _projectId;
  String _projectTitle = '';
  final List<_AssistantLine> _lines = [];
  bool _loadingStories = false;
  bool _generating = false;
  int? _pendingLine;
  bool _ready = false;
  Timer? _composerDebounce;

  @override
  void initState() {
    super.initState();
    _composer.addListener(_onComposerChanged);
    unawaited(_restore());
  }

  Future<void> _restore() async {
    final draft = await _store.load();
    if (!mounted) return;
    setState(() {
      _projectId = draft.projectId;
      _projectTitle = draft.projectTitle;
      _lines
        ..clear()
        ..addAll(
          draft.lines.map(
            (line) => _AssistantLine(
              role: line.role == 'user' ? _LineRole.user : _LineRole.assistant,
              text: line.text,
            ),
          ),
        );
      _composer.text = draft.composer;
      _ready = true;
    });
    if (!draft.isEmpty) {
      AppLog.instance.info(
        '创作助手草稿已恢复（${draft.lines.length} 条）',
        tag: 'create.assistant',
      );
    }
  }

  void _onComposerChanged() {
    _composerDebounce?.cancel();
    _composerDebounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(_persist());
    });
  }

  CreateAssistantDraft _snapshot() {
    return CreateAssistantDraft(
      projectId: _projectId,
      projectTitle: _projectTitle,
      composer: _composer.text,
      lines: [
        for (final line in _lines)
          if (!line.pending)
            CreateAssistantDraftLine(
              role: line.role == _LineRole.user ? 'user' : 'assistant',
              text: line.text,
            ),
      ],
    );
  }

  Future<void> _persist() async {
    if (!_ready) return;
    await _store.save(_snapshot());
  }

  Future<void> _pickStory() async {
    setState(() => _loadingStories = true);
    try {
      final repo = AppScope.projectsOf(context);
      final list = await repo.listProjects();
      if (!mounted) return;
      setState(() => _loadingStories = false);
      if (list.isEmpty) {
        await showAppSheet<void>(
          context: context,
          builder: (ctx) => const Padding(
            padding: EdgeInsets.all(AppTheme.pagePadding),
            child: AppEmptyState(message: '还没有故事，先去故事页新建'),
          ),
        );
        return;
      }
      final picked = await showAppSheet<String>(
        context: context,
        size: AppSheetSize.half,
        builder: (sheetCtx) => AppSheetScrollBody(
          children: [
            const AppText('选择故事', role: AppTextRole.subtitle),
            const SizedBox(height: AppTheme.spaceSm),
            for (final p in list)
              AppListTile(
                title: p.title,
                onTap: () => Navigator.of(sheetCtx).pop(p.id),
              ),
          ],
        ),
      );
      if (picked == null || !mounted) return;
      final summary = list.firstWhere((p) => p.id == picked);
      setState(() {
        _projectId = summary.id;
        _projectTitle = summary.title;
      });
      await _persist();
      AppLog.instance.info('创作助手选中故事：${summary.title}', tag: 'create.assistant');
    } catch (error, stack) {
      if (!mounted) return;
      setState(() => _loadingStories = false);
      AppLog.instance.error(
        '加载故事列表失败',
        tag: 'create.assistant',
        error: error,
        stackTrace: stack,
      );
    }
  }

  void _send() {
    if (_generating) return;
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    final projectId = _projectId;
    if (projectId == null) {
      _reply('先在上面选一个故事，我才能读它的设定', user: text);
      return;
    }
    final settings = AppScope.settingsOf(context);
    final endpoint = settings.ai.text;
    if (!endpoint.isConfigured ||
        (endpoint.needsApiKey && endpoint.apiKey.trim().isEmpty)) {
      _reply('先在设置里配好写故事的服务', user: text);
      return;
    }
    final repo = AppScope.projectsOf(context);
    final textClient = AppScope.textClientOf(context);
    final promptCtx = settings.textPromptContext();
    final plotCatalog = settings.plotElements;
    _composer.clear();
    setState(() {
      _lines.add(_AssistantLine(role: _LineRole.user, text: text));
      _pendingLine = _lines.length;
      _lines.add(
        const _AssistantLine(
          role: _LineRole.assistant,
          text: '正在理顺走向…',
          pending: true,
        ),
      );
      _generating = true;
    });
    unawaited(_persist());
    AppLog.instance.info(
      '创作助手写情节（$projectId）',
      tag: 'create.assistant',
    );
    unawaited(_generateGraph(
      repo: repo,
      textClient: textClient,
      promptCtx: promptCtx,
      plotCatalog: plotCatalog,
      projectId: projectId,
      prompt: text,
    ));
  }

  /// Straight answer without calling the model (no story / no service).
  void _reply(String answer, {required String user}) {
    _composer.clear();
    setState(() {
      _lines.add(_AssistantLine(role: _LineRole.user, text: user));
      _lines.add(_AssistantLine(role: _LineRole.assistant, text: answer));
    });
    unawaited(_persist());
  }

  Future<void> _generateGraph({
    required ProjectRepository repo,
    required AiTextClient textClient,
    required AiPromptContext promptCtx,
    required PlotElementCatalog plotCatalog,
    required String projectId,
    required String prompt,
  }) async {
    try {
      final project = await repo.open(projectId);
      final result = await CreateAgentRunner().runSingle(
        toolName: 'main.generate_graph',
        ctx: CreateToolContext(
          project: project,
          ai: promptCtx,
          services: CreateToolServices(
            textClient: textClient,
            plotCatalog: plotCatalog,
          ),
        ),
        args: <String, dynamic>{'prompt': prompt},
      );
      if (!mounted) return;
      final preview = result.userConfirmPayload;
      if (!result.ok || preview == null) {
        _finishTurn(result.errorMessage ?? '没写出来，换个说法再试');
        return;
      }
      final graph = MainGraphDocument.decodeSkeleton(
        Map<String, dynamic>.from(preview['graph'] as Map),
      );
      _finishTurn(_describeProposal(graph));
      final useIt = await _confirmGraph(project: project, graph: graph);
      if (!mounted || !useIt) {
        AppLog.instance.info('创作助手放弃这份情节', tag: 'create.assistant');
        return;
      }
      await _applyGraph(repo: repo, project: project, graph: graph);
    } catch (error, stack) {
      if (!mounted) return;
      _finishTurn('没写出来，稍后再试');
      AppLog.instance.error(
        '创作助手写情节失败',
        tag: 'create.assistant',
        error: error,
        stackTrace: stack,
      );
    }
  }

  String _describeProposal(MainStory graph) {
    final bits = <String>['${graph.nodes.length} 站'];
    final branches = graph.edges.where((e) => e.kind == EdgeKind.branch).length;
    if (branches > 0) bits.add('$branches 处岔路');
    return '读了设定，理出 ${bits.join(' · ')}';
  }

  /// Replaces the placeholder bubble with the outcome of this turn.
  void _finishTurn(String text) {
    setState(() {
      final index = _pendingLine;
      if (index != null && index < _lines.length) {
        _lines[index] = _AssistantLine(
          role: _LineRole.assistant,
          text: text,
        );
      } else {
        _lines.add(_AssistantLine(role: _LineRole.assistant, text: text));
      }
      _pendingLine = null;
      _generating = false;
    });
    unawaited(_persist());
  }

  Future<bool> _confirmGraph({
    required Project project,
    required MainStory graph,
  }) async {
    if (!mounted) return false;
    final bits = <String>['${graph.nodes.length} 站'];
    final branches = graph.edges.where((e) => e.kind == EdgeKind.branch).length;
    if (branches > 0) bits.add('$branches 处岔路');
    final replacing = project.main.hasAuthoredNodes;
    final droppedBeats = project.main.beats.length;

    final confirmed = await showAppSheet<bool>(
      context: context,
      size: AppSheetSize.half,
      builder: (sheetContext) => AppSheetScrollBody(
        footer: [
          AppButton(
            label: replacing ? '替换情节图' : '写入情节图',
            expanded: true,
            onPressed: () => Navigator.of(sheetContext).pop(true),
          ),
          const SizedBox(height: AppTheme.spaceSm),
          AppButton(
            label: '先不写',
            variant: AppButtonVariant.ghost,
            expanded: true,
            onPressed: () => Navigator.of(sheetContext).pop(false),
          ),
        ],
        children: [
          const AppText('生成的情节', role: AppTextRole.subtitle),
          const SizedBox(height: AppTheme.spaceXs),
          AppText(bits.join(' · '), role: AppTextRole.caption),
          if (replacing) ...[
            const SizedBox(height: AppTheme.spaceXs),
            AppText(
              droppedBeats > 0
                  ? '会替换现有的 ${project.main.nodes.length} 站，'
                      '$droppedBeats 段剧情一起清掉'
                  : '会替换现有的 ${project.main.nodes.length} 站',
              role: AppTextRole.caption,
            ),
          ],
          if (graph.summary.trim().isNotEmpty) ...[
            const SizedBox(height: AppTheme.spaceMd),
            AppText(graph.summary.trim(), role: AppTextRole.body),
          ],
          const SizedBox(height: AppTheme.spaceMd),
          for (final node in graph.nodes)
            AppListTile(
              title: node.title,
              subtitle: _synopsisOf(node),
              icon: node.tags.contains('ending')
                  ? Icons.flag_outlined
                  : Icons.circle_outlined,
            ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  static String? _synopsisOf(StoryNode node) {
    final synopsis = node.synopsis?.trim();
    return synopsis == null || synopsis.isEmpty ? null : synopsis;
  }

  Future<void> _applyGraph({
    required ProjectRepository repo,
    required Project project,
    required MainStory graph,
  }) async {
    final next = project.copyWith(
      main: graph,
      meta: project.meta.copyWith(updatedAt: DateTime.now().toUtc()),
    );
    try {
      await repo.save(next);
    } catch (error, stack) {
      AppLog.instance.error(
        '创作助手写入情节图失败',
        tag: 'create.assistant',
        error: error,
        stackTrace: stack,
      );
      if (!mounted) return;
      setState(() {
        _lines.add(
          const _AssistantLine(
            role: _LineRole.assistant,
            text: '没能写进故事，稍后再试一次',
          ),
        );
      });
      unawaited(_persist());
      return;
    }
    if (!mounted) return;
    AppScope.projectChangesOf(context).markChanged(project.meta.id);
    setState(() {
      _lines.add(
        const _AssistantLine(
          role: _LineRole.assistant,
          text: '情节图写好了，可以在情节图里继续调整',
        ),
      );
    });
    unawaited(_persist());
    AppLog.instance.info(
      '创作助手写入情节图：${graph.nodes.length} 站',
      tag: 'create.assistant',
    );
  }

  @override
  void dispose() {
    _composerDebounce?.cancel();
    _composer.removeListener(_onComposerChanged);
    // Best-effort flush; store handles errors.
    unawaited(_store.save(_snapshot()));
    _composer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storyLabel =
        _projectTitle.trim().isEmpty ? '未选择' : _projectTitle.trim();

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight < CreateAssistantPanel.minLayoutHeight) {
          return const SizedBox.shrink();
        }
        return _buildBody(context, storyLabel);
      },
    );
  }

  Widget _buildBody(BuildContext context, String storyLabel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pagePadding,
            AppTheme.spaceSm,
            AppTheme.pagePadding,
            AppTheme.spaceXs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppText('创作助手', role: AppTextRole.subtitle),
              const SizedBox(height: AppTheme.spaceSm),
              AppSelectField(
                label: '当前故事',
                value: storyLabel,
                hint: '点选故事',
                onTap: _loadingStories ? null : _pickStory,
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (_lines.isEmpty) {
                if (constraints.maxHeight < 48) {
                  return const SizedBox.shrink();
                }
                if (constraints.maxHeight < 96) {
                  return const Center(
                    child: AppText(
                      '说说这段故事该怎么走',
                      role: AppTextRole.caption,
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return const Center(
                  child: AppEmptyState(
                    message: '说说这段故事该怎么走',
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.pagePadding,
                  vertical: AppTheme.spaceSm,
                ),
                itemCount: _lines.length,
                itemBuilder: (context, index) {
                  final line = _lines[index];
                  final isUser = line.role == _LineRole.user;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
                    child: Align(
                      alignment: isUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * 0.72,
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: isUser
                                ? Theme.of(context)
                                    .colorScheme
                                    .primaryContainer
                                : Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMd,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(AppTheme.spaceSm),
                            child: AppText(
                              line.text,
                              role: AppTextRole.body,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: AppChatComposer(
            controller: _composer,
            hintText: '想写出怎样的情节…',
            isGenerating: _generating,
            onSend: _send,
          ),
        ),
      ],
    );
  }
}

enum _LineRole { user, assistant }

class _AssistantLine {
  const _AssistantLine({
    required this.role,
    required this.text,
    this.pending = false,
  });

  final _LineRole role;
  final String text;

  /// Episode-in-progress bubble; not persisted so a stale "正在写…" cannot
  /// come back on the next launch.
  final bool pending;
}
