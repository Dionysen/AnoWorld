import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/ai/staged_create_actions.dart';
import 'package:anoworld/domain/models/world_book.dart';
import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_page_route.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/foundation/widgets/app_segmented.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/foundation/widgets/app_text_field.dart';
import 'package:anoworld/play/play_mode_sheet.dart';
import 'package:anoworld/play/play_session_page.dart';
import 'package:flutter/material.dart';

enum _Stage { world, cast, main }

/// UX path 3: short prompts → world → cast → playable opening.
class StagedCreatePage extends StatefulWidget {
  const StagedCreatePage({super.key});

  @override
  State<StagedCreatePage> createState() => _StagedCreatePageState();
}

class _StagedCreatePageState extends State<StagedCreatePage> {
  _Stage _stage = _Stage.world;
  Project? _project;
  bool _booting = true;
  bool _busy = false;
  String? _status;

  final _prompt = TextEditingController();
  final _preview = TextEditingController();

  WorldBook? _worldBook;
  List<CastMember>? _cast;
  MainStory? _main;
  bool _hasPreview = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  @override
  void dispose() {
    _prompt.dispose();
    _preview.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    try {
      final project = await AppScope.projectsOf(
        context,
      ).create(title: context.strings.untitledStory);
      if (!mounted) return;
      setState(() {
        _project = project;
        _booting = false;
        _prompt.text = '';
        _status = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _booting = false;
        _status = context.strings.createStoryFailed(error);
      });
    }
  }

  StagedCreateActions _actions() =>
      StagedCreateActions(textClient: AppScope.textClientOf(context));

  String _stageTitle(AppStrings strings) => switch (_stage) {
        _Stage.world => strings.stagedWorld,
        _Stage.cast => strings.stagedCast,
        _Stage.main => strings.stagedMain,
      };

  String _exampleHint(AppStrings strings) => switch (_stage) {
        _Stage.world => strings.stagedWorldHint,
        _Stage.cast => strings.stagedCastHint,
        _Stage.main => strings.stagedMainHint,
      };

  String _promptLabel(AppStrings strings) => switch (_stage) {
        _Stage.world => strings.stagedWorldPrompt,
        _Stage.cast => strings.stagedCastPrompt,
        _Stage.main => strings.stagedMainPrompt,
      };

  void _showPreview(String text) {
    _preview.text = text;
    _hasPreview = true;
  }

  String _formatWorldBook(WorldBook worldBook) {
    return worldBook.entries
        .map((s) => '【${s.title}】\n${s.body}')
        .join('\n\n');
  }

  String _formatCast(List<CastMember> cast) {
    return cast
        .map((c) {
          final bits = <String>[c.name];
          if (c.summary.isNotEmpty) bits.add(c.summary);
          if (c.personality.isNotEmpty) bits.add('性格：${c.personality}');
          if (c.speechStyle.isNotEmpty) bits.add('说话：${c.speechStyle}');
          return bits.join('\n');
        })
        .join('\n\n');
  }

  String _formatMain(MainStory main) {
    final buf = StringBuffer(main.summary);
    buf.writeln();
    buf.writeln();
    buf.write('大站：');
    for (var i = 0; i < main.nodes.length; i++) {
      final node = main.nodes[i];
      buf.writeln();
      buf.write('${i + 1}. ${node.title}');
      if (node.synopsis != null && node.synopsis!.isNotEmpty) {
        buf.write(' — ${node.synopsis}');
      }
      if (node.tags.contains('ending')) {
        buf.write('（结局）');
      }
    }
    if (main.edges.isNotEmpty) {
      buf.writeln();
      buf.writeln();
      buf.write('分支：');
      for (final edge in main.edges) {
        final from = main.nodeById(edge.from)?.title ?? edge.from;
        final to = main.nodeById(edge.to)?.title ?? edge.to;
        buf.writeln();
        final kind = edge.kind == EdgeKind.branch ? '岔路' : '接着';
        final label =
            (edge.label != null && edge.label!.isNotEmpty) ? '「${edge.label}」' : '';
        buf.write('$kind $from → $to$label');
      }
    }
    return buf.toString();
  }

  WorldBook? _worldBookFromPreview() {
    final text = _preview.text.trim();
    if (text.isEmpty || _worldBook == null) return _worldBook;
    // Keep entry ids; replace bodies from editable blob best-effort by whole text.
    if (_worldBook!.entries.length == 1) {
      final only = _worldBook!.entries.first;
      return WorldBook(
        entries: [
          WorldBookEntry(
            id: only.id,
            title: only.title,
            body: text,
            alwaysOn: only.alwaysOn,
            keys: only.keys,
          ),
        ],
      );
    }
    return WorldBook(
      entries: [
        WorldBookEntry(
          id: _worldBook!.entries.first.id,
          title: '设定',
          body: text,
          alwaysOn: true,
        ),
      ],
    );
  }

  Future<void> _persist(Project project) async {
    await AppScope.projectsOf(context).save(project);
    if (!mounted) return;
    setState(() => _project = project);
  }

  Future<void> _generate() async {
    final project = _project;
    if (project == null || _busy) return;
    final strings = context.strings;
    final prompt = _prompt.text.trim();
    if (prompt.isEmpty) {
      setState(() => _status = strings.stagedNeedPrompt);
      return;
    }

    final endpoint = AppScope.settingsOf(context).ai.text;
    if (!endpoint.isConfigured ||
        (endpoint.needsApiKey && endpoint.apiKey.trim().isEmpty)) {
      setState(() => _status = strings.stagedNeedService);
      return;
    }

    setState(() {
      _busy = true;
      _status = strings.stagedGenerating;
    });

    try {
      final actions = _actions();
      final ctx = AppScope.settingsOf(context).textPromptContext();
      switch (_stage) {
        case _Stage.world:
          final worldBook = await actions.generateWorld(
            ctx: ctx,
            prompt: prompt,
          );
          final next = actions.applyWorldBook(project, worldBook);
          await _persist(next);
          if (!mounted) return;
          setState(() {
            _worldBook = worldBook;
            _showPreview(_formatWorldBook(worldBook));
            _status = null;
          });
        case _Stage.cast:
          final worldBook = _worldBookFromPreview() ?? _worldBook;
          if (worldBook == null || worldBook.entries.isEmpty) {
            setState(() => _status = strings.stagedNeedWorldFirst);
            return;
          }
          final cast = await actions.generateCast(
            ctx: ctx,
            prompt: prompt,
            worldBook: worldBook,
          );
          var next = actions.applyWorldBook(project, worldBook);
          next = actions.applyCast(next, cast);
          await _persist(next);
          if (!mounted) return;
          setState(() {
            _worldBook = worldBook;
            _cast = cast;
            _showPreview(_formatCast(cast));
            _status = null;
          });
        case _Stage.main:
          final worldBook = _worldBook ?? project.worldBook;
          final cast = _cast ?? project.cast;
          if (worldBook.entries.isEmpty || cast.isEmpty) {
            setState(() => _status = strings.stagedNeedWorldAndCast);
            return;
          }
          final main = await actions.generateMain(
            ctx: ctx,
            prompt: prompt,
            worldBook: worldBook,
            cast: cast,
          );
          final next = actions.applyMain(project, main);
          await _persist(next);
          if (!mounted) return;
          setState(() {
            _main = main;
            _showPreview(_formatMain(main));
            _status = null;
          });
      }
    } on AiTextException catch (error) {
      if (!mounted) return;
      setState(() => _status = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = strings.stagedGenerateFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _nextOrPlay() async {
    final project = _project;
    if (project == null) return;
    final strings = context.strings;

    switch (_stage) {
      case _Stage.world:
        final worldBook = _worldBookFromPreview();
        if (worldBook == null || worldBook.entries.isEmpty) {
          setState(() => _status = strings.stagedNeedWorldDone);
          return;
        }
        final next = _actions().applyWorldBook(project, worldBook);
        await _persist(next);
        if (!mounted) return;
        setState(() {
          _worldBook = worldBook;
          _stage = _Stage.cast;
          _prompt.clear();
          _hasPreview = false;
          _preview.clear();
          _status = null;
        });
      case _Stage.cast:
        final cast = _cast;
        if (cast == null || cast.isEmpty) {
          setState(() => _status = strings.stagedNeedCastDone);
          return;
        }
        setState(() {
          _stage = _Stage.main;
          _prompt.clear();
          _hasPreview = false;
          _preview.clear();
          _status = null;
        });
      case _Stage.main:
        final main = _main;
        if (main == null || main.nodes.isEmpty) {
          setState(() => _status = strings.stagedNeedMainDone);
          return;
        }
        final latest = _project;
        if (latest == null) return;
        final mode = await showPlayModeSheet(context);
        if (!mounted || mode == null) return;
        await Navigator.of(context).pushReplacement(
          AppSlidePageRoute<void>(
            builder: (_) => PlaySessionPage(
              project: latest,
              mode: mode,
              resumeSave: false,
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return AppPage(
      title: strings.stagedPrompts,
      onBack: () => Navigator.of(context).maybePop(),
      body: AppPageBody(
        children: [
          if (_booting)
            AppText(strings.stagedBooting, role: AppTextRole.caption)
          else ...[
            AppSegmented<_Stage>(
              value: _stage,
              onChanged: (value) {
                if (_busy) return;
                if (value == _Stage.cast && _worldBook == null) {
                  setState(() => _status = strings.stagedNeedWorldFirst);
                  return;
                }
                if (value == _Stage.main &&
                    (_worldBook == null || _cast == null)) {
                  setState(() => _status = strings.stagedNeedWorldAndCast);
                  return;
                }
                setState(() {
                  _stage = value;
                  _hasPreview = false;
                  _preview.clear();
                  _prompt.clear();
                  _status = null;
                });
              },
              options: [
                AppSegmentOption(value: _Stage.world, label: strings.stagedWorld),
                AppSegmentOption(value: _Stage.cast, label: strings.stagedCast),
                AppSegmentOption(value: _Stage.main, label: strings.stagedMain),
              ],
            ),
            const SizedBox(height: AppTheme.spaceLg),
            AppSectionHeader(
              _stageTitle(strings),
              subtitle: _exampleHint(strings),
            ),
            AppTextField(
              label: _promptLabel(strings),
              controller: _prompt,
              hint: _exampleHint(strings),
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: AppTheme.spaceGroup),
            AppButton(
              label: _busy
                  ? strings.stagedGeneratingShort
                  : (_hasPreview
                        ? strings.stagedRegenerate
                        : strings.stagedGenerate),
              onPressed: _busy ? null : _generate,
              expanded: true,
            ),
            if (_hasPreview) ...[
              const SizedBox(height: AppTheme.spaceLg),
              AppTextField(
                label: strings.stagedPreviewLabel,
                controller: _preview,
                minLines: 6,
                maxLines: 12,
              ),
              const SizedBox(height: AppTheme.spaceGroup),
              AppButton(
                label: _stage == _Stage.main
                    ? strings.stagedPlay
                    : strings.stagedNext,
                onPressed: _busy ? null : _nextOrPlay,
                expanded: true,
              ),
            ],
            if (_status != null) ...[
              const SizedBox(height: AppTheme.spaceMd),
              AppText(_status!, role: AppTextRole.caption),
            ],
          ],
        ],
      ),
    );
  }
}
