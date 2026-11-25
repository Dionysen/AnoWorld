import 'dart:convert';
import 'dart:io';

import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/project/project_hub_page.dart';
import 'package:anoworld/data/card_import/card_cover_sidecar.dart';
import 'package:anoworld/data/project/project_cover_files.dart';
import 'package:anoworld/home/story_assistant_navigation.dart';
import 'package:anoworld/domain/card_import/card_sanitize_action.dart';
import 'package:anoworld/domain/card_import/st_card_project_mapper.dart';
import 'package:anoworld/domain/card_import/st_character_card.dart';
import 'package:anoworld/domain/card_import/st_character_card_parser.dart';
import 'package:anoworld/domain/models/story_card_meta.dart';
import 'package:anoworld/foundation/logging/app_log.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_empty_state.dart';
import 'package:anoworld/foundation/widgets/app_image.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_page_gutter.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/foundation/widgets/app_switch.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/foundation/widgets/app_text_field.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

/// One picked card file (path and/or bytes).
class PickedCharacterCardFile {
  const PickedCharacterCardFile({
    required this.name,
    this.path,
    this.bytes,
    this.coverBytes,
  });

  final String name;
  final String? path;
  final Uint8List? bytes;

  /// PNG sitting beside a JSON card (same base name), when found.
  final Uint8List? coverBytes;
}

/// Path 1: pick SillyTavern cards → confirm mapped material → write project.
class CharacterCardImportPage extends StatefulWidget {
  const CharacterCardImportPage({
    super.key,
    this.pickCardFiles,
    this.parser = const StCharacterCardParser(),
    this.mapper = const StCardProjectMapper(),
  });

  /// Injectable picker for tests.
  final Future<List<PickedCharacterCardFile>> Function()? pickCardFiles;
  final StCharacterCardParser parser;
  final StCardProjectMapper mapper;

  @override
  State<CharacterCardImportPage> createState() =>
      _CharacterCardImportPageState();
}

class _CharacterCardImportPageState extends State<CharacterCardImportPage> {
  StCardImportDraft? _draft;
  String? _status;
  bool _busy = false;
  final _title = TextEditingController();
  final _sanitizeAction = const CardSanitizeAction();

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<List<PickedCharacterCardFile>> _defaultPick() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json', 'png'],
    );
    if (files.isEmpty) return const [];
    final out = <PickedCharacterCardFile>[];
    for (final file in files) {
      if (file.name.isEmpty) continue;
      final path = file.path;
      final isJson = file.name.toLowerCase().endsWith('.json');
      out.add(
        PickedCharacterCardFile(
          name: file.name,
          path: path,
          bytes: await file.readAsBytes(),
          coverBytes: isJson && path != null
              ? await readCardCoverSidecar(path)
              : null,
        ),
      );
    }
    return out;
  }

  Future<void> _pickCards() async {
    setState(() {
      _status = null;
      _busy = true;
    });
    try {
      final files = await (widget.pickCardFiles ?? _defaultPick)();
      if (!mounted) return;
      if (files.isEmpty) {
        setState(() => _busy = false);
        return;
      }
      final cards = <StCharacterCard>[];
      for (final file in files) {
        cards.add(await _parseFile(file));
      }
      final draft = widget.mapper.fromCards(cards);
      _title.text = draft.title;
      setState(() {
        _draft = draft;
        _busy = false;
        _status = context.strings.cardReadCount(cards.length);
      });
      AppLog.instance.info(
        '读入角色卡 ${cards.length} 张 → ${draft.title}',
        tag: 'card.import',
      );
    } on StCharacterCardParseException catch (error) {
      if (!mounted) return;
      AppLog.instance.warning(error.message, tag: 'card.import');
      setState(() {
        _busy = false;
        _status = error.message;
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      AppLog.instance.error(
        '读卡平台异常',
        tag: 'card.import',
        error: error,
      );
      setState(() {
        _busy = false;
        _status = _platformReadError(context.strings, error);
      });
    } catch (error, stack) {
      if (!mounted) return;
      AppLog.instance.error(
        '读卡失败',
        tag: 'card.import',
        error: error,
        stackTrace: stack,
      );
      setState(() {
        _busy = false;
        _status = context.strings.cardReadFailed(error);
      });
    }
  }

  static String _platformReadError(AppStrings strings, PlatformException error) {
    final code = error.code.toUpperCase();
    if (code.contains('ENTITLEMENT') ||
        (error.message ?? '').toUpperCase().contains('ENTITLEMENT')) {
      return strings.cardReadUnavailable;
    }
    return strings.cardReadFailed(error.message ?? error.code);
  }

  Future<StCharacterCard> _parseFile(PickedCharacterCardFile file) async {
    final strings = context.strings;
    final lower = file.name.toLowerCase();
    final label = file.name;
    if (lower.endsWith('.png')) {
      final bytes = file.bytes ??
          (file.path == null ? null : await File(file.path!).readAsBytes());
      if (bytes == null) {
        throw StCharacterCardParseException(strings.cardCannotRead(file.name));
      }
      return widget.parser.parsePngBytes(bytes, sourceLabel: label);
    }
    if (lower.endsWith('.json')) {
      String? raw;
      if (file.bytes != null) {
        raw = utf8.decode(file.bytes!, allowMalformed: true);
      } else if (file.path != null) {
        raw = await File(file.path!).readAsString();
      }
      if (raw == null) {
        throw StCharacterCardParseException(strings.cardCannotRead(file.name));
      }
      final card = widget.parser.parseJsonString(raw, sourceLabel: label);
      final cover = file.coverBytes;
      if (card.coverImageBytes == null && cover != null && cover.isNotEmpty) {
        return card.copyWith(coverImageBytes: cover);
      }
      return card;
    }
    throw StCharacterCardParseException(
      strings.cardUnsupportedFormat(p.extension(file.name)),
    );
  }

  void _setCastIncluded(String id, bool included) {
    final draft = _draft;
    if (draft == null) return;
    setState(() {
      _draft = draft.copyWith(
        castItems: [
          for (final item in draft.castItems)
            if (item.id == id) item.copyWith(included: included) else item,
        ],
      );
    });
  }

  void _setWorldBookIncluded(String id, bool included) {
    final draft = _draft;
    if (draft == null) return;
    setState(() {
      _draft = draft.copyWith(
        worldBookItems: [
          for (final item in draft.worldBookItems)
            if (item.id == id) item.copyWith(included: included) else item,
        ],
      );
    });
  }

  Future<void> _sanitizeDraft() async {
    final draft = _draft;
    if (draft == null || _busy) return;
    final strings = context.strings;
    final result = _sanitizeAction.run(draft);
    setState(() {
      _draft = result.draft;
      _status = result.changedFieldCount == 0
          ? strings.cardSanitizeNoChange
          : strings.cardSanitizeChanged(result.changedFieldCount);
    });
  }

  Future<void> _writeProject() async {
    final draft = _draft;
    if (draft == null || _busy) return;
    final strings = context.strings;
    final titled = draft.copyWith(title: _title.text.trim());
    if (!titled.castItems.any((e) => e.included)) {
      setState(() => _status = strings.cardNeedOneCast);
      return;
    }
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final projects = AppScope.projectsOf(context);
      final created = await projects.create(title: titled.title);
      var filled = titled.toProject(id: created.meta.id);
      await projects.save(filled);

      final coverBytes = titled.coverImageBytes;
      final projectDir = await projects.directoryFor(filled.meta.id);
      if (coverBytes != null &&
          coverBytes.isNotEmpty &&
          projectDir != null &&
          !projectDir.startsWith('memory://')) {
        final relative = await ProjectCoverFiles.importFromBytes(
          projectDir: projectDir,
          bytes: coverBytes,
          extension: 'png',
        );
        filled = filled.copyWith(
          meta: filled.meta.copyWith(coverPath: relative),
        );
        await projects.save(filled);
        AppLog.instance.info('写入角色卡封面', tag: 'card.import');
      }

      if (!mounted) return;
      AppLog.instance.info(
        '写入故事：${filled.meta.title}',
        tag: 'card.import',
      );
      await pushStoryRouteReplacement<void>(
        context,
        ProjectHubPage(projectId: filled.meta.id),
      );
    } catch (error, stack) {
      AppLog.instance.error(
        '写入故事失败',
        tag: 'card.import',
        error: error,
        stackTrace: stack,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = strings.cardWriteFailed(error);
      });
    }
  }

  Widget _coverPreview(BuildContext context, StCardImportDraft draft) {
    final strings = context.strings;
    final bytes = draft.coverImageBytes;
    if (bytes == null || bytes.isEmpty) {
      return AppText(strings.cardCoverMissing, role: AppTextRole.caption);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: AppImage(
            bytes: bytes,
            fallback: ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spaceXs),
        AppText(strings.cardCoverHint, role: AppTextRole.caption),
      ],
    );
  }

  /// One caption line per non-empty field, so the user sees what comes along.
  Widget _cardMetaSummary(BuildContext context, StoryCardMeta card) {
    final strings = context.strings;
    final lines = <String>[
      if (card.creator.trim().isNotEmpty)
        '${strings.cardInfoCreator} · ${card.creator.trim()}',
      if (card.version.trim().isNotEmpty)
        '${strings.cardInfoVersion} · ${card.version.trim()}',
      if (card.tags.isNotEmpty)
        '${strings.cardInfoTags} · ${card.tags.join(strings.listSeparator)}',
      if (card.createdAt.trim().isNotEmpty)
        '${strings.cardInfoCreatedAt} · ${card.createdAt.trim()}',
      if (card.modifiedAt.trim().isNotEmpty)
        '${strings.cardInfoModifiedAt} · ${card.modifiedAt.trim()}',
    ];
    return AppText(lines.join('\n'), role: AppTextRole.caption);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final draft = _draft;
    return AppPage(
      title: strings.importCard,
      onBack: () => Navigator.of(context).maybePop(),
      body: AppPageBody.list(
        children: [
          AppSectionHeader(
            strings.cardImportSection,
            subtitle: strings.cardImportSectionHint,
            gutter: true,
          ),
          AppPageGutter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppButton(
                  label: draft == null
                      ? strings.cardPickCards
                      : strings.cardRepick,
                  onPressed: _busy ? null : _pickCards,
                  expanded: true,
                ),
                const SizedBox(height: AppTheme.spaceSm),
                AppText(
                  strings.cardPickHint,
                  role: AppTextRole.caption,
                ),
                if (_status != null) ...[
                  const SizedBox(height: AppTheme.spaceMd),
                  AppText(_status!, role: AppTextRole.caption),
                ],
                if (_busy && draft == null) ...[
                  const SizedBox(height: AppTheme.spaceMd),
                  AppText(strings.cardReading, role: AppTextRole.caption),
                ],
                if (draft == null && !_busy) ...[
                  const SizedBox(height: AppTheme.spaceLg),
                  AppEmptyState(
                    message: strings.cardEmptyTitle,
                    detail: strings.cardEmptyDetail,
                  ),
                ],
              ],
            ),
          ),
          if (draft != null) ...[
            const SizedBox(height: AppTheme.spaceLg),
            AppPageGutter(
              child: AppTextField(
                label: strings.cardStoryNameLabel,
                controller: _title,
              ),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            AppPageGutter(child: _coverPreview(context, draft)),
            if (!draft.cardMeta.isEmpty) ...[
              const SizedBox(height: AppTheme.spaceSm),
              AppPageGutter(child: _cardMetaSummary(context, draft.cardMeta)),
            ],
            const SizedBox(height: AppTheme.spaceLg),
            AppSectionHeader(
              strings.cardTidySection,
              subtitle: strings.cardTidyHint,
              gutter: true,
            ),
            AppPageGutter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppButton(
                    label: strings.cardSanitize,
                    variant: AppButtonVariant.secondary,
                    onPressed: _busy ? null : _sanitizeDraft,
                    expanded: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            AppSectionHeader(
              strings.cardCastSection,
              subtitle: strings.cardCastSectionHint,
              gutter: true,
            ),
            AppListTileStack(
              tiles: [
                for (final item in draft.castItems)
                  AppListTile(
                    title: item.title,
                    subtitle: item.preview,
                    icon: Icons.person_outline,
                    trailing: AppSwitch(
                      value: item.included,
                      onChanged: (value) => _setCastIncluded(item.id, value),
                    ),
                    onTap: () => _setCastIncluded(item.id, !item.included),
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceLg),
            AppSectionHeader(
              strings.cardWorldBookSection,
              subtitle: strings.cardWorldBookSectionHint,
              gutter: true,
            ),
            if (draft.worldBookItems.isEmpty)
              AppPageGutter(
                child: AppText(
                  strings.cardNoWorldBookEntries,
                  role: AppTextRole.caption,
                ),
              )
            else
              AppListTileStack(
                tiles: [
                  for (final item in draft.worldBookItems)
                    AppListTile(
                      title: item.title,
                      subtitle: item.preview,
                      icon: item.value.alwaysOn
                          ? Icons.push_pin_outlined
                          : Icons.bookmark_border,
                      trailing: AppSwitch(
                        value: item.included,
                        onChanged: (value) =>
                            _setWorldBookIncluded(item.id, value),
                      ),
                      onTap: () =>
                          _setWorldBookIncluded(item.id, !item.included),
                    ),
                ],
              ),
            if (draft.cardAiNote != null) ...[
              const SizedBox(height: AppTheme.spaceLg),
              AppSectionHeader(
                strings.cardAiNoteSection,
                subtitle: strings.cardAiNoteHint,
                gutter: true,
              ),
              AppPageGutter(
                child: AppText(draft.cardAiNote!, role: AppTextRole.caption),
              ),
            ],
            const SizedBox(height: AppTheme.spaceLg),
            AppPageGutter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppButton(
                    label: strings.cardWrite,
                    onPressed: _busy ? null : _writeProject,
                    expanded: true,
                  ),
                  const SizedBox(height: AppTheme.spaceSm),
                  AppText(
                    strings.cardWriteHint,
                    role: AppTextRole.caption,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
