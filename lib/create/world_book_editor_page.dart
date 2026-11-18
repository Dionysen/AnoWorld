import 'dart:async';

import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/models/world_book.dart';
import 'package:anoworld/domain/project/entity_id.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_circle_button.dart';
import 'package:anoworld/foundation/widgets/app_disclosure_icon.dart';
import 'package:anoworld/foundation/widgets/app_empty_state.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_page_gutter.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/foundation/widgets/app_sheet.dart';
import 'package:anoworld/foundation/widgets/app_switch.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/foundation/widgets/app_text_field.dart';
import 'package:flutter/material.dart';

/// Edit world-book entries (always-on + keyword-triggered).
class WorldBookEditorPage extends StatefulWidget {
  const WorldBookEditorPage({super.key, required this.projectId});

  final String projectId;

  @override
  State<WorldBookEditorPage> createState() => _WorldBookEditorPageState();
}

class _WorldBookEditorPageState extends State<WorldBookEditorPage> {
  Project? _project;
  Object? _error;
  bool _loading = true;
  Timer? _saveDebounce;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_project == null && _loading) {
      _load();
    }
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    super.dispose();
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

  Future<void> _persist(Project project) async {
    final stamped = project.copyWith(
      meta: project.meta.copyWith(updatedAt: DateTime.now().toUtc()),
    );
    await AppScope.projectsOf(context).save(stamped);
    if (!mounted) return;
    setState(() => _project = stamped);
  }

  void _scheduleSave(WorldBook worldBook) {
    final current = _project;
    if (current == null) return;
    final next = current.copyWith(worldBook: worldBook);
    setState(() => _project = next);
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 280), () async {
      if (!mounted) return;
      await _persist(next);
    });
  }

  String _subtitle(WorldBookEntry entry) {
    if (entry.alwaysOn) return '常驻';
    if (entry.keys.isEmpty) return '按需 · 还没写关键词';
    return '按需 · ${entry.keys.join('、')}';
  }

  void _replaceEntries(List<WorldBookEntry> entries) {
    _scheduleSave(WorldBook(entries: List.unmodifiable(entries)));
  }

  Future<void> _editEntry({WorldBookEntry? existing}) async {
    final project = _project;
    if (project == null) return;
    final draft = existing ??
        WorldBookEntry(
          id: newEntityId('wb'),
          title: '',
          body: '',
          alwaysOn: true,
        );
    final title = TextEditingController(text: draft.title);
    final body = TextEditingController(text: draft.body);
    final keys = TextEditingController(text: draft.keys.join('、'));
    var alwaysOn = draft.alwaysOn;

    final result = await showAppSheet<_EntrySheetResult>(
      context: context,
      size: AppSheetSize.half,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.pagePadding,
                    AppTheme.spaceXs,
                    AppTheme.pagePadding,
                    0,
                  ),
                  child: AppText(
                    existing == null ? '新设定' : '编辑设定',
                    role: AppTextRole.subtitle,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceMd),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.pagePadding,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AppTextField(
                              label: '标题',
                              controller: title,
                              hint: '世界观、客栈、城门规则…',
                            ),
                            const SizedBox(height: AppTheme.spaceMd),
                            AppTextField(
                              label: '正文',
                              controller: body,
                              minLines: 4,
                              maxLines: 10,
                              hint: '写给故事用的完整说明，单独成段也能读懂',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppTheme.spaceMd),
                      AppListTile(
                        title: '始终带上',
                        subtitle: '基调、硬规则适合打开',
                        icon: Icons.push_pin_outlined,
                        trailing: AppSwitch(
                          value: alwaysOn,
                          onChanged: (value) {
                            setSheetState(() => alwaysOn = value);
                          },
                        ),
                      ),
                      if (!alwaysOn)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppTheme.pagePadding,
                            AppTheme.spaceMd,
                            AppTheme.pagePadding,
                            0,
                          ),
                          child: AppTextField(
                            label: '关键词',
                            controller: keys,
                            hint: '用顿号或逗号分开',
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.pagePadding,
                    AppTheme.spaceMd,
                    AppTheme.pagePadding,
                    AppTheme.spaceMd,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppButton(
                        label: '保存',
                        expanded: true,
                        onPressed: () {
                          final nextKeys = keys.text
                              .split(RegExp(r'[,，、\s]+'))
                              .map((s) => s.trim())
                              .where((s) => s.isNotEmpty)
                              .toList(growable: false);
                          Navigator.of(sheetContext).pop(
                            _EntrySheetResult.save(
                              draft.copyWith(
                                title: title.text.trim().isEmpty
                                    ? '未命名设定'
                                    : title.text.trim(),
                                body: body.text.trim(),
                                alwaysOn: alwaysOn,
                                keys: alwaysOn ? const <String>[] : nextKeys,
                              ),
                            ),
                          );
                        },
                      ),
                      if (existing != null) ...[
                        const SizedBox(height: AppTheme.spaceSm),
                        AppButton(
                          label: '删除这条',
                          expanded: true,
                          variant: AppButtonVariant.ghost,
                          onPressed: () => Navigator.of(sheetContext).pop(
                            const _EntrySheetResult.delete(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    title.dispose();
    body.dispose();
    keys.dispose();
    if (result == null || !mounted) return;

    final entries = [...project.worldBook.entries];
    if (result.delete) {
      entries.removeWhere((e) => e.id == draft.id);
    } else {
      final saved = result.entry!;
      final index = entries.indexWhere((e) => e.id == draft.id);
      if (index < 0) {
        entries.add(saved);
      } else {
        entries[index] = saved;
      }
    }
    _replaceEntries(entries);
  }

  @override
  Widget build(BuildContext context) {
    final project = _project;
    final entries = project?.worldBook.entries ?? const <WorldBookEntry>[];
    return AppPage(
      title: '世界书',
      onBack: () => Navigator.of(context).maybePop(),
      actions: [
        AppCircleButton(
          icon: Icons.add,
          tooltip: '加一条设定',
          onPressed: _loading || _error != null ? null : () => _editEntry(),
        ),
      ],
      body: AppPageBody.list(
        children: [
          if (_loading)
            const AppPageGutter(
              child: AppText('加载中…', role: AppTextRole.caption),
            )
          else if (_error != null)
            AppPageGutter(
              child: AppEmptyState(
                message: '无法打开设定',
                detail: _error.toString(),
                action: AppButton(
                  label: '重试',
                  onPressed: _load,
                  variant: AppButtonVariant.secondary,
                ),
              ),
            )
          else if (project != null) ...[
            const AppSectionHeader(
              '设定条目',
              subtitle: '常驻会一直带上；其他条目靠关键词唤起',
              gutter: true,
            ),
            if (entries.isEmpty)
              AppPageGutter(
                child: AppEmptyState(
                  message: '还没有设定',
                  detail: '先写世界基调，再补地名与规则',
                  action: AppButton(
                    label: '加一条',
                    onPressed: () => _editEntry(),
                    variant: AppButtonVariant.secondary,
                  ),
                ),
              )
            else
              AppListTileStack(
                tiles: [
                  for (final entry in entries)
                    AppListTile(
                      title:
                          entry.title.isEmpty ? '未命名设定' : entry.title,
                      subtitle: _subtitle(entry),
                      icon: entry.alwaysOn
                          ? Icons.push_pin_outlined
                          : Icons.bookmark_border,
                      trailing: const AppForwardIcon(),
                      onTap: () => _editEntry(existing: entry),
                    ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class _EntrySheetResult {
  const _EntrySheetResult.save(this.entry) : delete = false;
  const _EntrySheetResult.delete()
      : entry = null,
        delete = true;

  final WorldBookEntry? entry;
  final bool delete;
}