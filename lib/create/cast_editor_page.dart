import 'dart:async';

import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/models/project.dart';
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

/// Edit cast members for a project.
class CastEditorPage extends StatefulWidget {
  const CastEditorPage({super.key, required this.projectId});

  final String projectId;

  @override
  State<CastEditorPage> createState() => _CastEditorPageState();
}

class _CastEditorPageState extends State<CastEditorPage> {
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

  void _scheduleSave(List<CastMember> cast) {
    final current = _project;
    if (current == null) return;
    final next = current.copyWith(cast: List.unmodifiable(cast));
    setState(() => _project = next);
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 280), () async {
      if (!mounted) return;
      await _persist(next);
    });
  }

  String _subtitle(CastMember member) {
    if (member.summary.trim().isNotEmpty) return member.summary.trim();
    if (member.personality.trim().isNotEmpty) return member.personality.trim();
    return '还没写简介';
  }

  Future<void> _editMember({CastMember? existing}) async {
    final project = _project;
    if (project == null) return;
    final draft = existing ??
        CastMember(
          id: newEntityId('c'),
          name: '',
        );
    final defaultProtagonist = draft.isProtagonist ||
        (existing == null &&
            project.cast.isEmpty &&
            !project.cast.any((c) => c.isProtagonist));

    final result = await showAppSheet<_CastSheetResult>(
      context: context,
      size: AppSheetSize.half,
      builder: (_) => _CastMemberSheet(
        draft: draft,
        existing: existing,
        defaultProtagonist: defaultProtagonist,
      ),
    );

    if (result == null || !mounted) return;

    var cast = [...project.cast];
    if (result.delete) {
      cast.removeWhere((c) => c.id == draft.id);
    } else {
      final saved = result.member!;
      final index = cast.indexWhere((c) => c.id == draft.id);
      if (index < 0) {
        cast.add(saved);
      } else {
        cast[index] = saved;
      }
      cast = castWithProtagonist(
        cast,
        memberId: saved.id,
        isProtagonist: saved.isProtagonist,
      );
    }
    _scheduleSave(cast);
  }

  @override
  Widget build(BuildContext context) {
    final project = _project;
    final cast = project?.cast ?? const <CastMember>[];
    return AppPage(
      title: '角色',
      onBack: () => Navigator.of(context).maybePop(),
      actions: [
        AppCircleButton(
          icon: Icons.add,
          tooltip: '加一个角色',
          onPressed: _loading || _error != null ? null : () => _editMember(),
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
                message: '无法打开角色',
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
              '登场人物',
              subtitle: '可勾选一名主角，作为酒馆里的当前角色',
              gutter: true,
            ),
            if (cast.isEmpty)
              AppPageGutter(
                child: AppEmptyState(
                  message: '还没有角色',
                  detail: '先加主角和关键配角',
                  action: AppButton(
                    label: '加一个',
                    onPressed: () => _editMember(),
                    variant: AppButtonVariant.secondary,
                  ),
                ),
              )
            else
              AppListTileStack(
                tiles: [
                  for (final member in cast)
                    AppListTile(
                      title: member.name,
                      subtitle: member.isProtagonist
                          ? '主角 · ${_subtitle(member)}'
                          : _subtitle(member),
                      icon: member.isProtagonist
                          ? Icons.star_outline
                          : Icons.person_outline,
                      trailing: const AppForwardIcon(),
                      onTap: () => _editMember(existing: member),
                    ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class _CastSheetResult {
  const _CastSheetResult.save(this.member) : delete = false;
  const _CastSheetResult.delete()
      : member = null,
        delete = true;

  final CastMember? member;
  final bool delete;
}

class _CastMemberSheet extends StatefulWidget {
  const _CastMemberSheet({
    required this.draft,
    required this.existing,
    required this.defaultProtagonist,
  });

  final CastMember draft;
  final CastMember? existing;
  final bool defaultProtagonist;

  @override
  State<_CastMemberSheet> createState() => _CastMemberSheetState();
}

class _CastMemberSheetState extends State<_CastMemberSheet> {
  late final TextEditingController _name;
  late final TextEditingController _summary;
  late final TextEditingController _personality;
  late final TextEditingController _speech;
  late final TextEditingController _examples;
  late final CastMember _baseline;
  late bool _isProtagonist;

  @override
  void initState() {
    super.initState();
    _baseline = widget.draft.copyWith(isProtagonist: widget.defaultProtagonist);
    _name = TextEditingController(text: widget.draft.name);
    _summary = TextEditingController(text: widget.draft.summary);
    _personality = TextEditingController(text: widget.draft.personality);
    _speech = TextEditingController(text: widget.draft.speechStyle);
    _examples = TextEditingController(text: widget.draft.exampleLines.join('\n'));
    _isProtagonist = widget.defaultProtagonist;
    for (final c in [_name, _summary, _personality, _speech, _examples]) {
      c.addListener(_markDirty);
    }
  }

  void _markDirty() => setState(() {});

  @override
  void dispose() {
    for (final c in [_name, _summary, _personality, _speech, _examples]) {
      c.removeListener(_markDirty);
    }
    _name.dispose();
    _summary.dispose();
    _personality.dispose();
    _speech.dispose();
    _examples.dispose();
    super.dispose();
  }

  CastMember _snapshot() {
    final nextName = _name.text.trim();
    return widget.draft.copyWith(
      name: nextName,
      summary: _summary.text.trim(),
      personality: _personality.text.trim(),
      speechStyle: _speech.text.trim(),
      exampleLines: _examples.text
          .split(RegExp(r'[\r\n]+'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(growable: false),
      isProtagonist: _isProtagonist,
    );
  }

  bool get _isDirty => !_membersEqual(_snapshot(), _baseline);

  static bool _membersEqual(CastMember a, CastMember b) {
    return a.name == b.name &&
        a.summary == b.summary &&
        a.personality == b.personality &&
        a.speechStyle == b.speechStyle &&
        a.isProtagonist == b.isProtagonist &&
        _listEqual(a.exampleLines, b.exampleLines);
  }

  static bool _listEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _save() {
    final next = _snapshot();
    Navigator.of(context).pop(
      _CastSheetResult.save(
        next.copyWith(name: next.name.isEmpty ? '未命名角色' : next.name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    return AppSheetEditForm(
      title: existing == null ? '新角色' : '编辑角色',
      isDirty: _isDirty,
      onSave: _save,
      body: AppSheetScrollBody(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.pagePadding,
          0,
          AppTheme.pagePadding,
          AppTheme.spaceMd,
        ),
        children: [
          AppTextField(
            label: '名字',
            controller: _name,
          ),
          const SizedBox(height: AppTheme.spaceMd),
          AppTextField(
            label: '简介',
            controller: _summary,
            minLines: 2,
            maxLines: 4,
          ),
          const SizedBox(height: AppTheme.spaceMd),
          AppTextField(
            label: '性格',
            controller: _personality,
            minLines: 2,
            maxLines: 4,
          ),
          const SizedBox(height: AppTheme.spaceMd),
          AppTextField(
            label: '说话方式',
            controller: _speech,
            minLines: 2,
            maxLines: 4,
          ),
          const SizedBox(height: AppTheme.spaceMd),
          AppTextField(
            label: '示例对白',
            controller: _examples,
            minLines: 3,
            maxLines: 6,
            hint: '一行一句',
          ),
          const SizedBox(height: AppTheme.spaceMd),
          AppListTile(
            title: '主角',
            subtitle: '酒馆里「当前角色」的名字与设定来源',
            icon: Icons.star_outline,
            trailing: AppSwitch(
              value: _isProtagonist,
              onChanged: (value) => setState(() => _isProtagonist = value),
            ),
          ),
          if (existing != null) ...[
            const SizedBox(height: AppTheme.spaceLg),
            AppButton(
              label: '删除这个角色',
              expanded: true,
              variant: AppButtonVariant.danger,
              onPressed: () => Navigator.of(context).pop(
                const _CastSheetResult.delete(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
