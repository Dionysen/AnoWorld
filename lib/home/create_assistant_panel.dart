import 'dart:async';

import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/domain/repositories/project_merge.dart';
import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/domain/ai/ai_prompt_context.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/ai/create/create_agent_runner.dart';
import 'package:anoworld/domain/ai/create/create_assistant_target.dart';
import 'package:anoworld/domain/ai/create/create_chat_turn.dart';
import 'package:anoworld/domain/ai/create/create_tool_context.dart';
import 'package:anoworld/domain/ai/create/create_tool_services.dart';
import 'package:anoworld/domain/main/apply_cast_patch.dart';
import 'package:anoworld/domain/main/apply_main_graph_patch.dart';
import 'package:anoworld/domain/main/apply_plot_patch.dart';
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
  const CreateAssistantPanel({super.key, this.draftStore});

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

  /// Index in [_lines] where the current story's conversation starts, so the
  /// model never receives lines that belong to another story.
  int _historyStart = 0;
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
      final previousId = _projectId;
      setState(() {
        _projectId = summary.id;
        _projectTitle = summary.title;
        // Keep the transcript on screen, but do not let the previous story's
        // conversation steer this one.
        if (summary.id != previousId) _historyStart = _lines.length;
      });
      await _persist();
      AppLog.instance.info(
        '创作助手选中故事：${summary.title}',
        tag: 'create.assistant',
      );
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
    final history = _historyForModel();
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
    unawaited(
      _runAgentTurn(
        repo: repo,
        textClient: textClient,
        promptCtx: promptCtx,
        plotCatalog: plotCatalog,
        projectId: projectId,
        prompt: text,
        history: history,
      ),
    );
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
    required List<CreateChatTurn> history,
  }) async {
    final strings = context.strings;
    final toolClient = textClient is AiToolTurnClient
        ? textClient as AiToolTurnClient
        : null;
    try {
      final project = await repo.open(projectId);
      final turn = await CreateAgentRunner().runTurn(
        target: _target,
        prompt: prompt,
        history: history,
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
      final proposals = turn.proposals;
      if (proposals.isEmpty) {
        if (turn.hasAnswer) {
          _finishTurn(turn.answer);
          return;
        }
        _finishTurn(
          turn.errorMessage ?? turn.toolError ?? strings.assistantFailedRetry,
        );
        return;
      }
      final plan = _buildReviewPlan(
        project: project,
        catalog: plotCatalog,
        proposals: proposals,
      );
      if (plan == null) {
        _finishTurn(strings.patchNoChange);
        return;
      }
      // Keep the model's closing line when it wrote one; otherwise summarize
      // what was staged across layers.
      _finishTurn(
        turn.answer.trim().isNotEmpty
            ? turn.answer.trim()
            : _describeProposals(plan),
      );
      final picked = await showPatchReviewSheet(
        context: context,
        groups: plan.groups,
        initialSelection: plan.defaultSelection,
      );
      if (!mounted || picked == null) {
        AppLog.instance.info('创作助手放弃这次改动', tag: 'create.assistant');
        return;
      }
      if (picked.isEmpty) {
        AppLog.instance.info('创作助手没勾选任何改动', tag: 'create.assistant');
        return;
      }
      await _applyReviewPlan(
        repo: repo,
        project: project,
        catalog: plotCatalog,
        plan: plan,
        picked: picked,
      );
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

  /// One-line summary of a staged batch, per layer.
  String _describeProposals(_ReviewPlan plan) {
    final strings = context.strings;
    final parts = <String>[
      if (plan.wholeGraph != null)
        '${strings.assistantTargetGraph} '
            '${strings.stopCount(plan.wholeGraph!.nodes.length)}',
      if (plan.world != null)
        '${strings.assistantTargetWorld} '
            '${strings.opCount(plan.world!.ops.length)}',
      if (plan.cast != null)
        '${strings.assistantTargetCast} '
            '${strings.opCount(plan.cast!.ops.length)}',
      if (plan.graph != null)
        '${strings.assistantTargetGraph} '
            '${strings.opCount(plan.graph!.ops.length)}',
      if (plan.plot != null)
        '${strings.patchKindPlotElement} '
            '${strings.opCount(plan.plot!.ops.length)}',
    ];
    return '${strings.proposalLead} ${parts.join(' · ')}';
  }

  /// Lines of this story's conversation, as the model should see them.
  List<CreateChatTurn> _historyForModel() {
    final out = <CreateChatTurn>[];
    for (var i = _historyStart; i < _lines.length; i++) {
      final line = _lines[i];
      if (line.pending) continue;
      final text = line.text.trim();
      if (text.isEmpty) continue;
      out.add(
        line.role == _LineRole.user
            ? CreateChatTurn.user(text)
            : CreateChatTurn.assistant(text),
      );
    }
    return out;
  }

  /// Replaces the placeholder bubble with the outcome of this turn.
  void _finishTurn(String text) {
    setState(() {
      final index = _pendingLine;
      if (index != null && index < _lines.length) {
        _lines[index] = _AssistantLine(role: _LineRole.assistant, text: text);
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

  /// Builds the tickable review rows from every staged proposal.
  ///
  /// Returns null when nothing usable is left (all ops broken, or the only
  /// payload had no ops).
  _ReviewPlan? _buildReviewPlan({
    required Project project,
    required PlotElementCatalog catalog,
    required List<CreateTurnProposal> proposals,
  }) {
    final strings = context.strings;
    final plan = _ReviewPlan();
    final byKind = <String, CreateTurnProposal>{
      for (final proposal in proposals) proposal.kind: proposal,
    };

    final world = byKind['world.patch'];
    if (world != null) {
      final ops = _previewOps(world.preview);
      if (ops.isNotEmpty) {
        final patch = buildWorldBookPreview(project.worldBook, ops);
        plan.world = patch;
        _addOpsGroup(plan, strings.assistantTargetWorld, 'world', patch);
      }
    }

    final cast = byKind['cast.patch'];
    if (cast != null) {
      final ops = _previewOps(cast.preview);
      if (ops.isNotEmpty) {
        final patch = buildCastPreview(project.cast, ops);
        plan.cast = patch;
        _addOpsGroup(plan, strings.assistantTargetCast, 'cast', patch);
      }
    }

    // A whole-graph rewrite supersedes incremental graph ops in the same turn.
    final replace = byKind['main.replace'];
    final graph = replace == null ? byKind['main.patch'] : null;
    if (replace != null) {
      final raw = replace.preview['graph'];
      if (raw is! Map) {
        AppLog.instance.warning(
          'main.replace 提议缺少 graph，已忽略',
          tag: 'create.assistant',
        );
      } else {
        final next = MainGraphDocument.decodeSkeleton(
          Map<String, dynamic>.from(raw),
        );
        plan.wholeGraph = next;
        final branches = next.edges
            .where((e) => e.kind == EdgeKind.branch)
            .length;
        final bits = <String>[strings.stopCount(next.nodes.length)];
        if (branches > 0) bits.add(strings.branchCount(branches));
        final note = <String>[bits.join(' · ')];
        if (project.main.hasAuthoredNodes) {
          note.add(
            project.main.beats.isNotEmpty
                ? strings.replaceStopsWithBeats(
                    project.main.nodes.length,
                    project.main.beats.length,
                  )
                : strings.replaceStops(project.main.nodes.length),
          );
        }
        if (next.summary.trim().isNotEmpty) note.add(next.summary.trim());
        plan.groups.add(
          PatchReviewGroup(
            title: strings.assistantTargetGraph,
            rows: [
              PatchReviewRow(
                id: 'replace',
                title: strings.generatedPlotTitle,
                note: note.join('\n'),
                details: [for (final node in next.nodes) _nodeLine(node)],
              ),
            ],
          ),
        );
        plan.defaultSelection.add('replace');
      }
    } else if (graph != null) {
      final ops = _previewOps(graph.preview);
      if (ops.isNotEmpty) {
        final patch = buildMainGraphPreview(project.main, ops);
        plan.graph = patch;
        _addOpsGroup(plan, strings.assistantTargetGraph, 'main', patch);
      }
    }

    final plot = byKind['plot.select'];
    if (plot != null) {
      final ops = _previewOps(plot.preview);
      if (ops.isNotEmpty) {
        final patch = buildPlotPreview(
          PlotPatchState(catalog: catalog, selection: project.plotElements),
          ops,
        );
        plan.plot = patch;
        _addOpsGroup(plan, strings.patchKindPlotElement, 'plot', patch);
      }
    }

    return plan.isEmpty ? null : plan;
  }

  /// One station line in the whole-graph review row.
  static String _nodeLine(StoryNode node) {
    final synopsis = node.synopsis?.trim() ?? '';
    final ending = node.tags.contains('ending') ? ' · 终局' : '';
    return synopsis.isEmpty
        ? '· ${node.title}$ending'
        : '· ${node.title}$ending — $synopsis';
  }

  void _addOpsGroup<T>(
    _ReviewPlan plan,
    String title,
    String prefix,
    PatchPreview<T> patch,
  ) {
    final rows = <PatchReviewRow>[
      for (final item in patch.items)
        PatchReviewRow(
          id: '$prefix:${item.index}',
          item: item,
          selected: patch.defaultSelection.contains(item.index),
          enabled: item.usable,
        ),
    ];
    plan.groups.add(PatchReviewGroup(title: title, rows: rows));
    plan.defaultSelection.addAll(
      rows.where((row) => row.selected).map((row) => row.id),
    );
  }

  /// Op indexes ticked for one layer (`world:3` → 3).
  static Set<int> _pickedIndices(Set<String> picked, String prefix) {
    final head = '$prefix:';
    final out = <int>{};
    for (final key in picked) {
      if (!key.startsWith(head)) continue;
      final index = int.tryParse(key.substring(head.length));
      if (index != null) out.add(index);
    }
    return out;
  }

  Future<void> _applyReviewPlan({
    required ProjectRepository repo,
    required Project project,
    required PlotElementCatalog catalog,
    required _ReviewPlan plan,
    required Set<String> picked,
  }) async {
    final strings = context.strings;
    WorldBook? worldBook;
    List<CastMember>? cast;
    MainStory? graph;
    PlotPatchState? plot;

    if (plan.world != null) {
      final indices = _pickedIndices(picked, 'world');
      if (indices.isNotEmpty) {
        try {
          worldBook = plan.world!.applySelected(indices);
        } on ApplyWorldBookPatchException catch (error) {
          _finishTurn(error.message);
          return;
        }
      }
    }

    if (plan.cast != null) {
      final indices = _pickedIndices(picked, 'cast');
      if (indices.isNotEmpty) {
        try {
          cast = plan.cast!.applySelected(indices);
        } on ApplyCastPatchException catch (error) {
          _finishTurn(error.message);
          return;
        }
      }
    }

    if (plan.wholeGraph != null) {
      if (picked.contains('replace')) graph = plan.wholeGraph;
    } else if (plan.graph != null) {
      final indices = _pickedIndices(picked, 'main');
      if (indices.isNotEmpty) {
        try {
          graph = plan.graph!.applySelected(indices);
        } on ApplyMainGraphPatchException catch (error) {
          _finishTurn(error.message);
          return;
        }
      }
    }

    if (plan.plot != null) {
      final indices = _pickedIndices(picked, 'plot');
      if (indices.isNotEmpty) {
        try {
          plot = plan.plot!.applySelected(indices);
        } on ApplyPlotPatchException catch (error) {
          _finishTurn(error.message);
          return;
        }
      }
    }

    if (worldBook == null && cast == null && graph == null && plot == null) {
      _finishTurn(strings.patchNoChange);
      return;
    }

    // Library rows land first so the saved selection always resolves.
    if (plot != null && !identical(plot.catalog, catalog)) {
      await AppScope.settingsOf(context).updatePlotElements(plot.catalog);
    }

    try {
      // One save for every layer: a failed write never leaves half a batch.
      // Re-read first so an editor page saving meanwhile is not clobbered.
      await saveProjectMerged(
        repo,
        project.meta.id,
        (latest) => latest.copyWith(
          worldBook: worldBook,
          cast: cast,
          main: graph,
          plotElements: plot?.selection,
        ),
      );
    } catch (error, stack) {
      AppLog.instance.error(
        '创作助手写入失败',
        tag: 'create.assistant',
        error: error,
        stackTrace: stack,
      );
      if (!mounted) return;
      setState(() {
        _lines.add(
          _AssistantLine(
            role: _LineRole.assistant,
            text: strings.assistantNoSave,
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
          text: _savedMessage(
            world: worldBook != null,
            cast: cast != null,
            graph: graph != null,
            plot: plot != null,
          ),
        ),
      );
    });
    unawaited(_persist());
    final written = <String>[
      if (worldBook != null) '世界书 ${worldBook.entries.length} 条',
      if (cast != null) '角色 ${cast.length} 人',
      if (graph != null) '情节图 ${graph.nodes.length} 站',
      if (plot != null) '剧情元素 ${plot.selection.count} 项',
    ];
    AppLog.instance.info(
      '创作助手写入 ${written.join(' / ')}',
      tag: 'create.assistant',
    );
  }

  /// One layer keeps its old wording; several layers share one summary line.
  String _savedMessage({
    required bool world,
    required bool cast,
    required bool graph,
    required bool plot,
  }) {
    final strings = context.strings;
    final layers = <String>[
      if (world) strings.assistantTargetWorld,
      if (cast) strings.assistantTargetCast,
      if (graph) strings.assistantTargetGraph,
      if (plot) strings.patchKindPlotElement,
    ];
    if (layers.length == 1) {
      if (world) return strings.assistantWorldSaved;
      if (cast) return strings.assistantCastSaved;
      if (graph) return strings.assistantGraphSaved;
      return strings.assistantPlotSaved;
    }
    return strings.assistantLayersSaved(layers.join('、'));
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
          child: AppSelectField(
            label: strings.currentStory,
            value: storyLabel,
            hint: strings.pickStoryHint,
            onTap: _loadingStories ? null : _pickStory,
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
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMd,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(AppTheme.spaceSm),
                            child: AppText(line.text, role: AppTextRole.body),
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
            trailing: _buildTargetSwitch(strings),
          ),
        ),
      ],
    );
  }

  /// Edit scope: icon-only, left of send so it reads as part of the prompt.
  Widget _buildTargetSwitch(AppStrings strings) {
    return AppIconSegmented<CreateAssistantTarget>(
      value: _target,
      options: [
        AppSegmentOption(
          value: CreateAssistantTarget.graph,
          label: strings.assistantTargetGraph,
          icon: Icons.account_tree_outlined,
        ),
        AppSegmentOption(
          value: CreateAssistantTarget.world,
          label: strings.assistantTargetWorld,
          icon: Icons.public_outlined,
        ),
        AppSegmentOption(
          value: CreateAssistantTarget.cast,
          label: strings.assistantTargetCast,
          icon: Icons.groups_outlined,
        ),
        AppSegmentOption(
          value: CreateAssistantTarget.all,
          label: strings.assistantTargetAll,
          icon: Icons.layers_outlined,
        ),
      ],
      onChanged: _generating
          ? (_) {}
          : (value) {
              setState(() => _target = value);
              unawaited(_persist());
            },
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

/// Review state for one turn's staged proposals.
///
/// Typed patches are kept here so the sheet only deals with rows, and the
/// apply step can replay the ticked ops per layer onto the original project.
class _ReviewPlan {
  final List<PatchReviewGroup> groups = <PatchReviewGroup>[];
  final Set<String> defaultSelection = <String>{};

  PatchPreview<WorldBook>? world;
  PatchPreview<List<CastMember>>? cast;
  PatchPreview<MainStory>? graph;
  PatchPreview<PlotPatchState>? plot;

  /// Set when the model rewrote the whole graph instead of patching it.
  MainStory? wholeGraph;

  bool get isEmpty => groups.isEmpty;
}
