import 'dart:async';

import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/domain/models/preset.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/project/entity_id.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_empty_state.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/foundation/widgets/app_text_field.dart';
import 'package:flutter/material.dart';

/// Edit project writing presets (style / bans / preferences).
class PresetEditorPage extends StatefulWidget {
  const PresetEditorPage({super.key, required this.projectId});

  final String projectId;

  @override
  State<PresetEditorPage> createState() => _PresetEditorPageState();
}

class _PresetEditorPageState extends State<PresetEditorPage> {
  Project? _project;
  Object? _error;
  bool _loading = true;
  Timer? _saveDebounce;

  final _name = TextEditingController();
  final _style = TextEditingController();
  final _bans = TextEditingController();
  final _prefs = TextEditingController();

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
    _name.dispose();
    _style.dispose();
    _bans.dispose();
    _prefs.dispose();
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
      _bindFields(project.activePreset);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  void _bindFields(Preset preset) {
    _name.text = preset.name;
    _style.text = preset.styleNotes;
    _bans.text = preset.outputBans.join('\n');
    _prefs.text = preset.outputPreferences.join('\n');
  }

  List<String> _linesOf(String raw) {
    return raw
        .split(RegExp(r'[\r\n]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _persist(Project project) async {
    final stamped = project.copyWith(
      meta: project.meta.copyWith(updatedAt: DateTime.now().toUtc()),
    );
    await AppScope.projectsOf(context).save(stamped);
    if (!mounted) return;
    setState(() => _project = stamped);
  }

  void _scheduleSave(Project Function(Project current) update) {
    final current = _project;
    if (current == null) return;
    final next = update(current);
    setState(() => _project = next);
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 280), () async {
      if (!mounted) return;
      await _persist(next);
    });
  }

  void _applyActiveFields() {
    final project = _project;
    if (project == null) return;
    final activeId = project.activePresetId;
    final presets = project.presets.map((preset) {
      if (preset.id != activeId) return preset;
      return preset.copyWith(
        name: _name.text.trim().isEmpty ? preset.name : _name.text.trim(),
        styleNotes: _style.text.trim(),
        outputBans: _linesOf(_bans.text),
        outputPreferences: _linesOf(_prefs.text),
      );
    }).toList(growable: false);
    _scheduleSave((current) => current.copyWith(presets: presets));
  }

  void _selectPreset(String id) {
    final project = _project;
    if (project == null || project.activePresetId == id) return;
    final match = project.presets.where((p) => p.id == id);
    if (match.isEmpty) return;
    _bindFields(match.first);
    _scheduleSave((current) => current.copyWith(activePresetId: id));
  }

  void _addPreset() {
    final project = _project;
    if (project == null) return;
    final preset = Preset(
      id: newEntityId('preset'),
      name: '新预设',
      styleNotes: project.activePreset.styleNotes,
      outputBans: project.activePreset.outputBans,
      outputPreferences: project.activePreset.outputPreferences,
    );
    _bindFields(preset);
    _scheduleSave(
      (current) => current.copyWith(
        presets: [...current.presets, preset],
        activePresetId: preset.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final project = _project;
    return AppPage(
      title: '预设',
      onBack: () => Navigator.of(context).maybePop(),
      body: AppPageBody(
        children: [
          if (_loading)
            const AppText('加载中…', role: AppTextRole.caption)
          else if (_error != null)
            AppEmptyState(
              message: '无法打开预设',
              detail: _error.toString(),
              action: AppButton(
                label: '重试',
                onPressed: _load,
                variant: AppButtonVariant.secondary,
              ),
            )
          else if (project != null) ...[
            const AppSectionHeader(
              '选用',
              subtitle: '创作与游玩都会跟当前这一套',
            ),
            for (var i = 0; i < project.presets.length; i++) ...[
              if (i > 0) const SizedBox(height: AppTheme.spaceSm),
              AppListTile(
                title: project.presets[i].name,
                subtitle: project.presets[i].id == project.activePresetId
                    ? '正在使用'
                    : null,
                icon: Icons.tune_outlined,
                onTap: () => _selectPreset(project.presets[i].id),
              ),
            ],
            const SizedBox(height: AppTheme.spaceSm),
            AppButton(
              label: '加一套预设',
              onPressed: _addPreset,
              variant: AppButtonVariant.secondary,
              expanded: true,
            ),
            const SizedBox(height: AppTheme.spaceLg),
            const AppSectionHeader(
              '当前内容',
              subtitle: '改完会自动保存',
            ),
            AppTextField(
              label: '名称',
              controller: _name,
              onChanged: (_) => _applyActiveFields(),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            AppTextField(
              label: '预设说明',
              controller: _style,
              minLines: 3,
              maxLines: 6,
              hint: '人称、语气、篇幅…',
              onChanged: (_) => _applyActiveFields(),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            AppTextField(
              label: '不要写这些',
              controller: _bans,
              minLines: 3,
              maxLines: 6,
              hint: '一行一条',
              onChanged: (_) => _applyActiveFields(),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            AppTextField(
              label: '更想要这些',
              controller: _prefs,
              minLines: 3,
              maxLines: 6,
              hint: '一行一条',
              onChanged: (_) => _applyActiveFields(),
            ),
          ],
        ],
      ),
    );
  }
}
