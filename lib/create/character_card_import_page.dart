import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/create/create_hub_page.dart';
import 'package:anoworld/domain/card_import/st_card_project_mapper.dart';
import 'package:anoworld/domain/card_import/st_character_card.dart';
import 'package:anoworld/domain/card_import/st_character_card_parser.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_empty_state.dart';
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
  });

  final String name;
  final String? path;
  final Uint8List? bytes;
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
      out.add(
        PickedCharacterCardFile(
          name: file.name,
          path: file.path,
          bytes: await file.readAsBytes(),
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
        _status = '已读入 ${cards.length} 张卡，可勾选要留下的内容';
      });
    } on StCharacterCardParseException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = error.message;
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = _platformReadError(error);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = '读卡失败：$error';
      });
    }
  }

  static String _platformReadError(PlatformException error) {
    final code = error.code.toUpperCase();
    if (code.contains('ENTITLEMENT') ||
        (error.message ?? '').toUpperCase().contains('ENTITLEMENT')) {
      return '无法读取所选文件，请完全退出应用后重开再试';
    }
    return '读卡失败：${error.message ?? error.code}';
  }

  Future<StCharacterCard> _parseFile(PickedCharacterCardFile file) async {
    final lower = file.name.toLowerCase();
    final label = file.name;
    if (lower.endsWith('.png')) {
      final bytes = file.bytes ??
          (file.path == null ? null : await File(file.path!).readAsBytes());
      if (bytes == null) {
        throw StCharacterCardParseException('无法读取 ${file.name}');
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
        throw StCharacterCardParseException('无法读取 ${file.name}');
      }
      return widget.parser.parseJsonString(raw, sourceLabel: label);
    }
    throw StCharacterCardParseException(
      '暂只支持 .json / .png（${p.extension(file.name)}）',
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

  Future<void> _writeProject() async {
    final draft = _draft;
    if (draft == null || _busy) return;
    final titled = draft.copyWith(title: _title.text.trim());
    if (!titled.castItems.any((e) => e.included)) {
      setState(() => _status = '至少留下一个角色');
      return;
    }
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final projects = AppScope.projectsOf(context);
      final created = await projects.create(title: titled.title);
      final filled = titled.toProject(id: created.meta.id);
      await projects.save(filled);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          pageBuilder: (_, _, _) =>
              CreateHubPage(projectId: filled.meta.id),
          transitionsBuilder: (_, animation, _, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = '写入失败：$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    return AppPage(
      title: '导入角色卡',
      onBack: () => Navigator.of(context).maybePop(),
      body: AppPageBody.list(
        children: [
          const AppSectionHeader(
            '从酒馆卡摘素材',
            subtitle: '只取设定与角色，不跑插件和正则',
            gutter: true,
          ),
          AppPageGutter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppButton(
                  label: draft == null ? '选择角色卡' : '重新选卡',
                  onPressed: _busy ? null : _pickCards,
                  expanded: true,
                ),
                const SizedBox(height: AppTheme.spaceSm),
                const AppText(
                  '可选多张：第一张作主角与故事名，其余当配角',
                  role: AppTextRole.caption,
                ),
                if (_status != null) ...[
                  const SizedBox(height: AppTheme.spaceMd),
                  AppText(_status!, role: AppTextRole.caption),
                ],
                if (_busy && draft == null) ...[
                  const SizedBox(height: AppTheme.spaceMd),
                  const AppText('读取中…', role: AppTextRole.caption),
                ],
                if (draft == null && !_busy) ...[
                  const SizedBox(height: AppTheme.spaceLg),
                  const AppEmptyState(
                    message: '还没有读入角色卡',
                    detail: '支持 .json 与带角色数据的 .png',
                  ),
                ],
              ],
            ),
          ),
          if (draft != null) ...[
            const SizedBox(height: AppTheme.spaceLg),
            AppPageGutter(
              child: AppTextField(
                label: '故事名',
                controller: _title,
              ),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            const AppSectionHeader(
              '角色',
              subtitle: '描述、性格与示例对白',
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
            const AppSectionHeader(
              '世界书',
              subtitle: '情景、开场素材与角色书条目',
              gutter: true,
            ),
            if (draft.worldBookItems.isEmpty)
              const AppPageGutter(
                child: AppText(
                  '这张卡没有可摘的设定条目',
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
              const AppSectionHeader(
                '卡内 AI 说明',
                subtitle: '不会写进故事，写对白请在设置里改 AI 预设',
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
                    label: '写入故事',
                    onPressed: _busy ? null : _writeProject,
                    expanded: true,
                  ),
                  const SizedBox(height: AppTheme.spaceSm),
                  const AppText(
                    '写入后可在创作里继续改设定、角色与情节',
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
