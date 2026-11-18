import 'dart:async';

import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/foundation/logging/app_log.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_chat_composer.dart';
import 'package:anoworld/foundation/widgets/app_empty_state.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_page_gutter.dart';
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
        builder: (sheetCtx) => AppPageGutter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
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
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    _composer.clear();
    setState(() {
      _lines.add(_AssistantLine(role: _LineRole.user, text: text));
      _lines.add(
        const _AssistantLine(
          role: _LineRole.assistant,
          text: '创作助手还在完善，暂时没法代写。可以先在故事页改设定与角色',
        ),
      );
    });
    unawaited(_persist());
    AppLog.instance.info(
      '创作助手消息（${_projectId ?? '未选故事'}）',
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
                      '说说想补哪段设定或角色',
                      role: AppTextRole.caption,
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return const Center(
                  child: AppEmptyState(
                    message: '说说想补哪段设定或角色',
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
            hintText: '想创作或整理什么…',
            onSend: _send,
          ),
        ),
      ],
    );
  }
}

enum _LineRole { user, assistant }

class _AssistantLine {
  const _AssistantLine({required this.role, required this.text});

  final _LineRole role;
  final String text;
}
