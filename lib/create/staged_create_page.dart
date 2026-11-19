import 'package:anoworld/app/app_scope.dart';
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
      final project =
          await AppScope.projectsOf(context).create(title: '未命名故事');
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
        _status = '创建故事失败：$error';
      });
    }
  }

  StagedCreateActions _actions() =>
      StagedCreateActions(textClient: AppScope.textClientOf(context));

  String get _stageTitle => switch (_stage) {
        _Stage.world => '世界',
        _Stage.cast => '人物',
        _Stage.main => '走向',
      };

  String get _exampleHint => switch (_stage) {
        _Stage.world => '例如：雨夜的边城，人们靠传闻活着',
        _Stage.cast => '例如：少年想离开，客栈老板知道出路',
        _Stage.main => '例如：今晚必须出城，在客栈做一个选择',
      };

  String get _promptLabel => switch (_stage) {
        _Stage.world => '写一两句世界',
        _Stage.cast => '写一两句人物',
        _Stage.main => '写一两句走向',
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
    final prompt = _prompt.text.trim();
    if (prompt.isEmpty) {
      setState(() => _status = '先写一两句提示');
      return;
    }

    final endpoint = AppScope.settingsOf(context).ai.text;
    if (!endpoint.isConfigured ||
        (endpoint.needsApiKey && endpoint.apiKey.trim().isEmpty)) {
      setState(() => _status = '请先在设置里配好写故事的服务');
      return;
    }

    setState(() {
      _busy = true;
      _status = '正在生成…';
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
            setState(() => _status = '请先完成世界设定');
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
            setState(() => _status = '请先完成设定和角色');
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
      setState(() => _status = '生成失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _nextOrPlay() async {
    final project = _project;
    if (project == null) return;

    switch (_stage) {
      case _Stage.world:
        final worldBook = _worldBookFromPreview();
        if (worldBook == null || worldBook.entries.isEmpty) {
          setState(() => _status = '请先生成设定');
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
          setState(() => _status = '请先生成角色');
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
          setState(() => _status = '请先生成走向');
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
    return AppPage(
      title: '分阶段提示词',
      onBack: () => Navigator.of(context).maybePop(),
      body: AppPageBody(
        children: [
          if (_booting)
            const AppText('正在准备故事…', role: AppTextRole.caption)
          else ...[
            AppSegmented<_Stage>(
              value: _stage,
              onChanged: (value) {
                if (_busy) return;
                if (value == _Stage.cast && _worldBook == null) {
                  setState(() => _status = '请先完成世界');
                  return;
                }
                if (value == _Stage.main &&
                    (_worldBook == null || _cast == null)) {
                  setState(() => _status = '请先完成世界和人物');
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
              options: const [
                AppSegmentOption(value: _Stage.world, label: '世界'),
                AppSegmentOption(value: _Stage.cast, label: '人物'),
                AppSegmentOption(value: _Stage.main, label: '走向'),
              ],
            ),
            const SizedBox(height: AppTheme.spaceLg),
            AppSectionHeader(
              _stageTitle,
              subtitle: _exampleHint,
            ),
            AppTextField(
              label: _promptLabel,
              controller: _prompt,
              hint: _exampleHint,
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: AppTheme.spaceGroup),
            AppButton(
              label: _busy
                  ? '生成中…'
                  : (_hasPreview ? '重写这一阶段' : '生成'),
              onPressed: _busy ? null : _generate,
              expanded: true,
            ),
            if (_hasPreview) ...[
              const SizedBox(height: AppTheme.spaceLg),
              AppTextField(
                label: '预览（可改）',
                controller: _preview,
                minLines: 6,
                maxLines: 12,
              ),
              const SizedBox(height: AppTheme.spaceGroup),
              AppButton(
                label: _stage == _Stage.main ? '开始游玩' : '下一步',
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
