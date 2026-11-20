import 'dart:async';

import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/domain/ai/ai_prompt_context.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/ai/create/create_agent_runner.dart';
import 'package:anoworld/domain/ai/create/create_assistant_target.dart';
import 'package:anoworld/domain/ai/create/create_tool_context.dart';
import 'package:anoworld/domain/ai/create/create_tool_services.dart';
import 'package:anoworld/domain/main/apply_cast_patch.dart';
import 'package:anoworld/domain/main/apply_main_graph_patch.dart';
import 'package:anoworld/domain/main/apply_world_book_patch.dart';
import 'package:anoworld/domain/main/main_graph_document.dart';
import 'package:anoworld/domain/main/patch_preview.dart';
import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/models/world_book.dart';
import 'package:anoworld/domain/repositories/project_repository.dart';
import 'package:anoworld/domain/settings/plot_element_catalog.dart';
import 'package:anoworld/foundation/logging/app_log.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_chat_composer.dart';
import 'package:anoworld/foundation/widgets/app_empty_state.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_segmented.dart';
import 'package:anoworld/foundation/widgets/app_select_field.dart';
import 'package:anoworld/foundation/widgets/app_sheet.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/home/create_assistant_draft.dart';
import 'package:anoworld/home/create_assistant_draft_store.dart';
import 'package:anoworld/home/patch_review_sheet.dart';
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
  CreateAssistantTarget _target = CreateAssistantTarget.graph;
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
      _target = draft.target;
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
      target: _target,
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
    final strings = context.strings;
    setState(() => _loadingStories = true);
    try {
      final repo = AppScope.projectsOf(context);
      final list = await repo.listProjects();
      if (!mounted) return;
      setState(() => _loadingStories = false);
      if (list.isEmpty) {
        await showAppSheet<void>(
          context: context,
          builder: (ctx) => Padding(
            padding: const EdgeInsets.all(AppTheme.pagePadding),
            child: AppEmptyState(message: strings.noStoriesYet),
          ),
        );
        return;
      }
      final picked = await showAppSheet<String>(
        context: context,
        size: AppSheetSize.half,
        builder: (sheetCtx) => AppSheetScrollBody(
          children: [
            AppText(strings.pickStoryTitle, role: AppTextRole.subtitle),
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
    final strings = context.strings;
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    final projectId = _projectId;
    if (projectId == null) {
      _reply(strings.assistantNeedsStory, user: text);
      return;
    }
    final settings = AppScope.settingsOf(context);
    final endpoint = settings.ai.text;
    if (!endpoint.isConfigured ||
        (endpoint.needsApiKey && endpoint.apiKey.trim().isEmpty)) {
      _reply(strings.assistantNeedsService, user: text);
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
        _AssistantLine(
          role: _LineRole.assistant,
          text: strings.assistantPending,
          pending: true,
        ),
      );
      _generating = true;
    });
    unawaited(_persist());
    AppLog.instance.info(
      '创作助手 ${_target.wireName}（$projectId）',
      tag: 'create.assistant',
    );
    unawaited(_runAgentTurn(
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

  Future<void> _runAgentTurn({
    required ProjectRepository repo,
    required AiTextClient textClient,
    required AiPromptContext promptCtx,
    required PlotElementCatalog plotCatalog,
    required String projectId,
    required String prompt,
  }) async {
    final strings = context.strings;
    final toolClient =
        textClient is AiToolTurnClient ? textClient as AiToolTurnClient : null;
    try {
      final project = await repo.open(projectId);
      final turn = await CreateAgentRunner().runTurn(
        target: _target,
        prompt: prompt,
        ctx: CreateToolContext(
          project: project,
          ai: promptCtx,
          services: CreateToolServices(
            toolClient: toolClient,
            plotCatalog: plotCatalog,
          ),
        ),
      );
      if (!mounted) return;
      if (turn.hasAnswer) {
        _finishTurn(turn.answer);
        return;
      }
      final preview = turn.proposal;
      if (preview == null) {
        _finishTurn(
          turn.errorMessage ??
              turn.toolError ??
              strings.assistantFailedRetry,
        );
        return;
      }
      final kind = preview['kind']?.toString() ?? turn.toolName;
      switch (kind) {
        case 'main.replace':
          final graph = MainGraphDocument.decodeSkeleton(
            Map<String, dynamic>.from(preview['graph'] as Map),
          );
          _finishTurn(_describeGraphProposal(context, graph));
          final useIt = await _confirmGraph(project: project, graph: graph);
          if (!mounted || !useIt) {
            AppLog.instance.info('创作助手放弃情节改动', tag: 'create.assistant');
            return;
          }
          await _applyGraph(repo: repo, project: project, graph: graph);
        case 'main.patch':
          await _reviewGraphPatch(
            repo: repo,
            project: project,
            preview: preview,
          );
        case 'world.patch':
          await _reviewWorldPatch(
            repo: repo,
            project: project,
            preview: preview,
          );
        case 'cast.patch':
          await _reviewCastPatch(
            repo: repo,
            project: project,
            preview: preview,
          );
        default:
          _finishTurn(strings.assistantFailedRetry);
      }
    } catch (error, stack) {
      if (!mounted) return;
      _finishTurn(strings.assistantFailedLater);
      AppLog.instance.error(
        '创作助手回合失败',
        tag: 'create.assistant',
        error: error,
        stackTrace: stack,
      );
    }
  }

  String _describeGraphProposal(BuildContext context, MainStory graph) {
    final strings = context.strings;
    final bits = <String>[strings.stopCount(graph.nodes.length)];
    final branches = graph.edges.where((e) => e.kind == EdgeKind.branch).length;
    if (branches > 0) bits.add(strings.branchCount(branches));
    return '${strings.proposalLead} ${bits.join(' · ')}';
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

  /// Ops carried by a proposal payload.
  List<Map<String, dynamic>> _previewOps(Map<String, dynamic> preview) {
    final raw = preview['ops'];
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  Future<Set<int>?> _askPatchSelection<T>(PatchPreview<T> patch) {
    return showPatchReviewSheet(
      context: context,
      items: patch.items,
      initialSelection: patch.defaultSelection,
    );
  }

  Future<void> _reviewGraphPatch({
    required ProjectRepository repo,
    required Project project,
    required Map<String, dynamic> preview,
  }) async {
    final strings = context.strings;
    final ops = _previewOps(preview);
    if (ops.isEmpty) {
      _finishTurn(strings.patchNoChange);
      return;
    }
    final patch = buildMainGraphPreview(project.main, ops);
    _finishTurn('${strings.proposalLead} ${strings.opCount(ops.length)}');
    final picked = await _askPatchSelection(patch);
    if (!mounted || picked == null) {
      AppLog.instance.info('创作助手放弃情节改动', tag: 'create.assistant');
      return;
    }
    final MainStory graph;
    try {
      graph = patch.applySelected(picked);
    } on ApplyMainGraphPatchException catch (error) {
      _finishTurn(error.message);
      return;
    }
    AppLog.instance.info(
      '创作助手写入情节改动 ${picked.length}/${ops.length} 条',
      tag: 'create.assistant',
    );
    await _applyGraph(repo: repo, project: project, graph: graph);
  }

  Future<void> _reviewWorldPatch({
    required ProjectRepository repo,
    required Project project,
    required Map<String, dynamic> preview,
  }) async {
    final strings = context.strings;
    final ops = _previewOps(preview);
    if (ops.isEmpty) {
      _finishTurn(strings.patchNoChange);
      return;
    }
    final patch = buildWorldBookPreview(project.worldBook, ops);
    _finishTurn('${strings.proposalLead} ${strings.opCount(ops.length)}');
    final picked = await _askPatchSelection(patch);
    if (!mounted || picked == null) {
      AppLog.instance.info('创作助手放弃设定改动', tag: 'create.assistant');
      return;
    }
    final WorldBook worldBook;
    try {
      worldBook = patch.applySelected(picked);
    } on ApplyWorldBookPatchException catch (error) {
      _finishTurn(error.message);
      return;
    }
    AppLog.instance.info(
      '创作助手写入设定改动 ${picked.length}/${ops.length} 条',
      tag: 'create.assistant',
    );
    await _applyWorld(repo: repo, project: project, worldBook: worldBook);
  }

  Future<void> _reviewCastPatch({
    required ProjectRepository repo,
    required Project project,
    required Map<String, dynamic> preview,
  }) async {
    final strings = context.strings;
    final ops = _previewOps(preview);
    if (ops.isEmpty) {
      _finishTurn(strings.patchNoChange);
      return;
    }
    final patch = buildCastPreview(project.cast, ops);
    _finishTurn('${strings.proposalLead} ${strings.opCount(ops.length)}');
    final picked = await _askPatchSelection(patch);
    if (!mounted || picked == null) {
      AppLog.instance.info('创作助手放弃角色改动', tag: 'create.assistant');
      return;
    }
    final List<CastMember> cast;
    try {
      cast = patch.applySelected(picked);
    } on ApplyCastPatchException catch (error) {
      _finishTurn(error.message);
      return;
    }
    AppLog.instance.info(
      '创作助手写入角色改动 ${picked.length}/${ops.length} 条',
      tag: 'create.assistant',
    );
    await _applyCast(repo: repo, project: project, cast: cast);
  }

  Future<bool> _confirmGraph({
    required Project project,
    required MainStory graph,
  }) async {
    if (!mounted) return false;
    final strings = context.strings;
    final bits = <String>[strings.stopCount(graph.nodes.length)];
    final branches = graph.edges.where((e) => e.kind == EdgeKind.branch).length;
    if (branches > 0) bits.add(strings.branchCount(branches));
    final replacing = project.main.hasAuthoredNodes;
    final droppedBeats = project.main.beats.length;

    final confirmed = await showAppSheet<bool>(
      context: context,
      size: AppSheetSize.half,
      builder: (sheetContext) => AppSheetScrollBody(
        footer: [
          AppButton(
            label: replacing ? strings.replaceGraph : strings.writeGraph,
            expanded: true,
            onPressed: () => Navigator.of(sheetContext).pop(true),
          ),
          const SizedBox(height: AppTheme.spaceSm),
          AppButton(
            label: strings.skipWrite,
            variant: AppButtonVariant.ghost,
            expanded: true,
            onPressed: () => Navigator.of(sheetContext).pop(false),
          ),
        ],
        children: [
          AppText(strings.generatedPlotTitle, role: AppTextRole.subtitle),
          const SizedBox(height: AppTheme.spaceXs),
          AppText(bits.join(' · '), role: AppTextRole.caption),
          if (replacing) ...[
            const SizedBox(height: AppTheme.spaceXs),
            AppText(
              droppedBeats > 0
                  ? strings.replaceStopsWithBeats(
                      project.main.nodes.length,
                      droppedBeats,
                    )
                  : strings.replaceStops(project.main.nodes.length),
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
          _AssistantLine(
            role: _LineRole.assistant,
            text: context.strings.assistantNoSave,
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
        _AssistantLine(
          role: _LineRole.assistant,
          text: context.strings.assistantGraphSaved,
        ),
      );
    });
    unawaited(_persist());
    AppLog.instance.info(
      '创作助手写入情节图：${graph.nodes.length} 站',
      tag: 'create.assistant',
    );
  }

  Future<void> _applyWorld({
    required ProjectRepository repo,
    required Project project,
    required WorldBook worldBook,
  }) async {
    final next = project.copyWith(
      worldBook: worldBook,
      meta: project.meta.copyWith(updatedAt: DateTime.now().toUtc()),
    );
    try {
      await repo.save(next);
    } catch (error, stack) {
      AppLog.instance.error(
        '创作助手写入世界书失败',
        tag: 'create.assistant',
        error: error,
        stackTrace: stack,
      );
      if (!mounted) return;
      setState(() {
        _lines.add(
          _AssistantLine(
            role: _LineRole.assistant,
            text: context.strings.assistantNoSave,
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
        _AssistantLine(
          role: _LineRole.assistant,
          text: context.strings.assistantWorldSaved,
        ),
      );
    });
    unawaited(_persist());
    AppLog.instance.info(
      '创作助手写入世界书：${worldBook.entries.length} 条',
      tag: 'create.assistant',
    );
  }

  Future<void> _applyCast({
    required ProjectRepository repo,
    required Project project,
    required List<CastMember> cast,
  }) async {
    final next = project.copyWith(
      cast: cast,
      meta: project.meta.copyWith(updatedAt: DateTime.now().toUtc()),
    );
    try {
      await repo.save(next);
    } catch (error, stack) {
      AppLog.instance.error(
        '创作助手写入角色失败',
        tag: 'create.assistant',
        error: error,
        stackTrace: stack,
      );
      if (!mounted) return;
      setState(() {
        _lines.add(
          _AssistantLine(
            role: _LineRole.assistant,
            text: context.strings.assistantNoSave,
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
        _AssistantLine(
          role: _LineRole.assistant,
          text: context.strings.assistantCastSaved,
        ),
      );
    });
    unawaited(_persist());
    AppLog.instance.info(
      '创作助手写入角色：${cast.length} 人',
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
    final storyLabel = _projectTitle.trim().isEmpty
        ? context.strings.notSelected
        : _projectTitle.trim();

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
    final strings = context.strings;
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
              AppText(strings.assistantTitle, role: AppTextRole.subtitle),
              const SizedBox(height: AppTheme.spaceSm),
              AppSelectField(
                label: strings.currentStory,
                value: storyLabel,
                hint: strings.pickStoryHint,
                onTap: _loadingStories ? null : _pickStory,
              ),
              const SizedBox(height: AppTheme.spaceSm),
              AppText(
                strings.assistantEditTargetLabel,
                role: AppTextRole.caption,
              ),
              const SizedBox(height: AppTheme.spaceXs),
              AppSegmented<CreateAssistantTarget>(
                value: _target,
                options: [
                  AppSegmentOption(
                    value: CreateAssistantTarget.graph,
                    label: strings.assistantTargetGraph,
                  ),
                  AppSegmentOption(
                    value: CreateAssistantTarget.world,
                    label: strings.assistantTargetWorld,
                  ),
                  AppSegmentOption(
                    value: CreateAssistantTarget.cast,
                    label: strings.assistantTargetCast,
                  ),
                ],
                onChanged: _generating
                    ? (_) {}
                    : (value) {
                        setState(() => _target = value);
                        unawaited(_persist());
                      },
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
                  return Center(
                    child: AppText(
                      strings.assistantEmptyHint,
                      role: AppTextRole.caption,
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return Center(
                  child: AppEmptyState(message: strings.assistantEmptyHint),
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
            hintText: strings.assistantComposerHint,
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
