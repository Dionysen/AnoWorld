import 'dart:convert';

import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/ai/novel_import_actions.dart';
import 'package:anoworld/domain/ai/novel_import_draft.dart';
import 'package:anoworld/domain/ai/novel_text_chunker.dart';
import 'package:anoworld/foundation/logging/app_log.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_busy_indicator.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_icon_button.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_page_gutter.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/foundation/widgets/app_text_field.dart';
import 'package:anoworld/home/story_assistant_navigation.dart';
import 'package:anoworld/project/project_hub_page.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

enum _NovelImportPhase { input, running, review }

/// Path 2: paste / import text → AI skeleton → confirm → project hub.
class NovelImportPage extends StatefulWidget {
  const NovelImportPage({
    super.key,
    this.actions,
    this.pickTextFile,
    this.chunker = const NovelTextChunker(),
  });

  /// Injectable for tests.
  final NovelImportActions? actions;
  final Future<({String name, String text})?> Function()? pickTextFile;
  final NovelTextChunker chunker;

  @override
  State<NovelImportPage> createState() => _NovelImportPageState();
}

class _NovelImportPageState extends State<NovelImportPage> {
  final _body = TextEditingController();
  final _note = TextEditingController();
  final _title = TextEditingController();

  _NovelImportPhase _phase = _NovelImportPhase.input;
  NovelImportStep? _step;
  NovelImportDraft? _draft;
  String? _status;
  String? _fileTitle;
  bool _busy = false;

  @override
  void dispose() {
    _body.dispose();
    _note.dispose();
    _title.dispose();
    super.dispose();
  }

  NovelImportActions _actions() =>
      widget.actions ??
      NovelImportActions(
        textClient: AppScope.textClientOf(context),
        minGraphStations: AppScope.settingsOf(context).ai.minGraphStations,
      );

  NovelTextScope get _scope => widget.chunker.scope(_body.text);

  Future<({String name, String text})?> _defaultPick() async {
    final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final picked = await FilePicker.pickFiles(
      type: android ? FileType.any : FileType.custom,
      allowedExtensions: android ? null : const ['txt', 'md'],
    );
    if (picked.isEmpty) return null;
    final file = picked.single;
    final name = file.name;
    final lower = name.toLowerCase();
    if (!lower.endsWith('.txt') && !lower.endsWith('.md')) {
      throw const _NovelImportFileTypeException();
    }
    final bytes = await file.readAsBytes();
    final text = utf8.decode(bytes, allowMalformed: true);
    return (name: name, text: text);
  }

  Future<void> _pickFile() async {
    if (_busy) return;
    setState(() => _status = null);
    try {
      final picked = await (widget.pickTextFile ?? _defaultPick)();
      if (!mounted) return;
      if (picked == null) return;
      final base = p.basenameWithoutExtension(picked.name);
      _body.text = picked.text;
      setState(() {
        _fileTitle = base.trim().isEmpty ? null : base.trim();
        _status = null;
        _phase = _NovelImportPhase.input;
        _draft = null;
      });
      AppLog.instance.info(
        '导入文本 ${picked.name}（${picked.text.length} 字）',
        tag: 'novel.import',
      );
    } on _NovelImportFileTypeException {
      if (!mounted) return;
      setState(() => _status = context.strings.novelImportWrongFileType);
    } catch (error, stack) {
      AppLog.instance.error(
        '导入文本失败',
        tag: 'novel.import',
        error: error,
        stackTrace: stack,
      );
      if (!mounted) return;
      setState(() => _status = context.strings.novelImportFailed);
    }
  }

  Future<void> _generate() async {
    if (_busy) return;
    final strings = context.strings;
    final body = _body.text.trim();
    if (body.isEmpty) {
      setState(() => _status = strings.novelImportNeedBody);
      return;
    }

    final endpoint = AppScope.settingsOf(context).ai.text;
    if (!endpoint.isConfigured ||
        (endpoint.needsApiKey && endpoint.apiKey.trim().isEmpty)) {
      setState(() => _status = strings.novelImportNeedService);
      return;
    }

    setState(() {
      _busy = true;
      _phase = _NovelImportPhase.running;
      _step = NovelImportStep.outline;
      _status = strings.novelImportStepOutline;
      _draft = null;
    });

    try {
      final draft = await _actions().runPipeline(
        ctx: AppScope.settingsOf(context).textPromptContext(),
        sourceText: body,
        note: _note.text,
        preferredTitle: _fileTitle,
        onProgress: (step) {
          if (!mounted) return;
          setState(() {
            _step = step;
            _status = switch (step) {
              NovelImportStep.outline => strings.novelImportStepOutline,
              NovelImportStep.world => strings.novelImportStepWorld,
              NovelImportStep.cast => strings.novelImportStepCast,
              NovelImportStep.main => strings.novelImportStepMain,
            };
          });
        },
      );
      if (!mounted) return;
      _title.text = draft.title.trim().isEmpty
          ? (_fileTitle ?? strings.untitledStory)
          : draft.title;
      setState(() {
        _draft = draft;
        _phase = _NovelImportPhase.review;
        _busy = false;
        _status = null;
        _step = null;
      });
    } on AiTextException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _phase = _NovelImportPhase.input;
        _status = error.message;
        _step = null;
      });
    } catch (error, stack) {
      AppLog.instance.error(
        '拆故事失败',
        tag: 'novel.import',
        error: error,
        stackTrace: stack,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _phase = _NovelImportPhase.input;
        _status = strings.novelImportFailed;
        _step = null;
      });
    }
  }

  Future<void> _write() async {
    final draft = _draft;
    if (draft == null || _busy) return;
    final strings = context.strings;
    final titled = draft.copyWith(title: _title.text.trim());
    if (!titled.hasSkeleton) {
      setState(() => _status = strings.novelImportFailed);
      return;
    }

    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final project = await _actions().commit(
        projects: AppScope.projectsOf(context),
        draft: titled,
      );
      if (!mounted) return;
      await pushStoryRouteReplacement<void>(
        context,
        ProjectHubPage(projectId: project.meta.id),
      );
    } on AiTextException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = error.message;
      });
    } catch (error, stack) {
      AppLog.instance.error(
        '写入故事失败',
        tag: 'novel.import',
        error: error,
        stackTrace: stack,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = strings.novelImportWriteFailed(error);
      });
    }
  }

  void _removeStation(String nodeId) {
    final draft = _draft;
    if (draft == null || _busy) return;
    final next = draft.withoutStation(nodeId);
    if (next.main.nodes.length < 2) {
      setState(() => _status = context.strings.novelImportFailed);
      return;
    }
    setState(() {
      _draft = next;
      _status = null;
    });
  }

  void _backToInput() {
    if (_busy) return;
    setState(() {
      _phase = _NovelImportPhase.input;
      _status = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return AppPage(
      title: strings.pasteStory,
      onBack: () => Navigator.of(context).maybePop(),
      body: AppPageBody.list(
        children: [
          if (_phase == _NovelImportPhase.input) ..._inputSection(strings),
          if (_phase == _NovelImportPhase.running) ..._runningSection(strings),
          if (_phase == _NovelImportPhase.review && _draft != null)
            ..._reviewSection(strings, _draft!),
        ],
      ),
    );
  }

  List<Widget> _inputSection(AppStrings strings) {
    final scope = _scope;
    return [
      AppSectionHeader(
        strings.novelImportSection,
        subtitle: strings.novelImportSectionHint,
        gutter: true,
      ),
      AppPageGutter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              label: strings.novelImportBodyLabel,
              hint: strings.novelImportBodyHint,
              controller: _body,
              maxLines: 12,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            AppButton(
              label: strings.novelImportPickFile,
              variant: AppButtonVariant.secondary,
              onPressed: _busy ? null : _pickFile,
              expanded: true,
            ),
            if (scope.totalChars > 0) ...[
              const SizedBox(height: AppTheme.spaceSm),
              AppText(
                strings.novelImportRange(scope.usedChars, scope.totalChars),
                role: AppTextRole.caption,
              ),
            ],
            const SizedBox(height: AppTheme.spaceMd),
            AppTextField(
              label: strings.novelImportNoteLabel,
              hint: strings.novelImportNoteHint,
              controller: _note,
              maxLines: 2,
            ),
            if (_status != null) ...[
              const SizedBox(height: AppTheme.spaceMd),
              AppText(_status!, role: AppTextRole.caption),
            ],
            const SizedBox(height: AppTheme.spaceMd),
            AppButton(
              label: strings.novelImportGenerate,
              onPressed: _busy ? null : _generate,
              expanded: true,
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _runningSection(AppStrings strings) {
    return [
      const SizedBox(height: AppTheme.spaceLg),
      AppPageGutter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppBusyIndicator(),
            const SizedBox(height: AppTheme.spaceMd),
            AppText(
              _status ?? strings.novelImportStepOutline,
              role: AppTextRole.body,
            ),
            if (_step != null) ...[
              const SizedBox(height: AppTheme.spaceXs),
              AppText(
                switch (_step!) {
                  NovelImportStep.outline => '1 / 4',
                  NovelImportStep.world => '2 / 4',
                  NovelImportStep.cast => '3 / 4',
                  NovelImportStep.main => '4 / 4',
                },
                role: AppTextRole.caption,
              ),
            ],
          ],
        ),
      ),
    ];
  }

  List<Widget> _reviewSection(AppStrings strings, NovelImportDraft draft) {
    final range = draft.sourceRange;
    return [
      AppSectionHeader(
        strings.novelImportReviewSection,
        subtitle: strings.novelImportReviewHint,
        gutter: true,
      ),
      AppPageGutter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              label: strings.novelImportTitleLabel,
              controller: _title,
            ),
            if (range.totalChars > 0) ...[
              const SizedBox(height: AppTheme.spaceSm),
              AppText(
                strings.novelImportRange(range.usedChars, range.totalChars),
                role: AppTextRole.caption,
              ),
            ],
            if (draft.outline.summary.trim().isNotEmpty) ...[
              const SizedBox(height: AppTheme.spaceSm),
              AppText(draft.outline.summary, role: AppTextRole.caption),
            ],
            if (_status != null) ...[
              const SizedBox(height: AppTheme.spaceSm),
              AppText(_status!, role: AppTextRole.caption),
            ],
          ],
        ),
      ),
      const SizedBox(height: AppTheme.spaceLg),
      AppSectionHeader(strings.novelImportWorldSection, gutter: true),
      AppListTileStack(
        tiles: [
          for (final entry in draft.worldBook.entries)
            AppListTile(
              title: entry.title,
              subtitle: entry.body,
              icon: Icons.menu_book_outlined,
            ),
        ],
      ),
      const SizedBox(height: AppTheme.spaceLg),
      AppSectionHeader(strings.novelImportCastSection, gutter: true),
      AppListTileStack(
        tiles: [
          for (final member in draft.cast)
            AppListTile(
              title: member.name,
              subtitle: member.summary,
              icon: Icons.person_outline,
            ),
        ],
      ),
      const SizedBox(height: AppTheme.spaceLg),
      AppSectionHeader(
        strings.novelImportStationsSection,
        subtitle: strings.novelImportStationsHint,
        gutter: true,
      ),
      AppListTileStack(
        tiles: [
          for (var i = 0; i < draft.main.nodes.length; i++)
            AppListTile(
              title: '${i + 1}. ${draft.main.nodes[i].title}',
              subtitle: draft.main.nodes[i].synopsis,
              icon: Icons.flag_outlined,
              trailing: AppIconButton(
                icon: Icons.delete_outline,
                tooltip: strings.novelImportRemoveStation,
                onPressed: _busy
                    ? null
                    : () => _removeStation(draft.main.nodes[i].id),
              ),
            ),
        ],
      ),
      const SizedBox(height: AppTheme.spaceLg),
      AppPageGutter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppButton(
              label: strings.novelImportWrite,
              onPressed: _busy ? null : _write,
              expanded: true,
            ),
            const SizedBox(height: AppTheme.spaceSm),
            AppText(strings.novelImportWriteHint, role: AppTextRole.caption),
            const SizedBox(height: AppTheme.spaceSm),
            AppButton(
              label: strings.novelImportRetry,
              variant: AppButtonVariant.secondary,
              onPressed: _busy ? null : _backToInput,
              expanded: true,
            ),
          ],
        ),
      ),
    ];
  }
}

class _NovelImportFileTypeException implements Exception {
  const _NovelImportFileTypeException();
}
