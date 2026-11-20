import 'dart:async';

import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/app/project_change_watcher.dart';
import 'package:anoworld/domain/repositories/project_merge.dart';
import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/models/world_book.dart';
import 'package:anoworld/domain/project/entity_id.dart';
import 'package:anoworld/foundation/l10n/app_localizations.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_circle_button.dart';
import 'package:anoworld/foundation/widgets/app_disclosure_icon.dart';
import 'package:anoworld/foundation/widgets/app_empty_state.dart';
import 'package:anoworld/foundation/widgets/app_icon_button.dart';
import 'package:anoworld/foundation/widgets/app_list_selection_controller.dart';
import 'package:anoworld/foundation/widgets/app_list_hairline.dart';
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

class _WorldBookEditorPageState extends State<WorldBookEditorPage>
    with ProjectChangeWatcher<WorldBookEditorPage> {
  Project? _project;
  Object? _error;
  bool _loading = true;
  Timer? _saveDebounce;
  final AppListSelectionController _selection = AppListSelectionController();

  @override
  void initState() {
    super.initState();
    _selection.addListener(_onSelectionChanged);
  }

  void _onSelectionChanged() => setState(() {});

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_project == null && _loading) {
      _load();
    }
  }

  @override
  String get watchedProjectId => widget.projectId;

  /// World book written elsewhere (create assistant): show the saved entries.
  @override
  void reloadAfterExternalWrite() {
    unawaited(_load());
  }

  @override
  void dispose() {
    _selection.removeListener(_onSelectionChanged);
    _selection.dispose();
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
    final worldBook = project.worldBook;
    final saved = await saveProjectMerged(
      AppScope.projectsOf(context),
      widget.projectId,
      (latest) => latest.copyWith(worldBook: worldBook),
    );
    if (!mounted) return;
    setState(() => _project = saved);
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

  String _subtitle(AppStrings strings, WorldBookEntry entry) {
    if (entry.alwaysOn) return strings.tagAlwaysOn;
    if (entry.keys.isEmpty) return strings.worldBookNoKeywords;
    return strings.worldBookKeywords(entry.keys.join(strings.listSeparator));
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

    final result = await showAppSheet<_EntrySheetResult>(
      context: context,
      size: AppSheetSize.half,
      builder: (sheetContext) => _WorldBookEntrySheet(
        draft: draft,
        existing: existing,
      ),
    );

    if (result == null || !mounted) return;

    final saved = result.entry;
    final entries = [...project.worldBook.entries];
    final index = entries.indexWhere((e) => e.id == draft.id);
    if (index < 0) {
      entries.add(saved);
    } else {
      entries[index] = saved;
    }
    _replaceEntries(entries);
  }

  void _removeEntriesById(Iterable<String> ids) {
    final idSet = ids.toSet();
    final project = _project;
    if (project == null || idSet.isEmpty) return;
    final entries =
        project.worldBook.entries.where((e) => !idSet.contains(e.id)).toList();
    _replaceEntries(entries);
  }

  Future<bool> _confirmDelete({required String title, required String detail}) async {
    final ui = context.ui;
    final confirmed = await showAppSheet<bool>(
          context: context,
          builder: (ctx) => Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.pagePadding,
              AppTheme.spaceSm,
              AppTheme.pagePadding,
              AppTheme.pagePadding,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppText(title, role: AppTextRole.subtitle),
                const SizedBox(height: AppTheme.spaceXs),
                AppText(detail, role: AppTextRole.caption),
                const SizedBox(height: AppTheme.spaceMd),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: ui.cancel,
                        variant: AppButtonVariant.secondary,
                        onPressed: () => Navigator.of(ctx).pop(false),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceSm),
                    Expanded(
                      child: AppButton(
                        label: ui.delete,
                        variant: AppButtonVariant.danger,
                        onPressed: () => Navigator.of(ctx).pop(true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
    return confirmed == true;
  }

  Future<void> _deleteSelected() async {
    final ids = _selection.ids.toList(growable: false);
    if (ids.isEmpty) return;
    final strings = context.strings;
    final confirmed = await _confirmDelete(
      title: ids.length == 1
          ? strings.worldBookDeleteOneTitle
          : strings.worldBookDeleteManyTitle(ids.length),
      detail: strings.worldBookDeleteDetail,
    );
    if (!confirmed || !mounted) return;
    _removeEntriesById(ids);
    _selection.exit();
  }

  Widget _entryLeading(WorldBookEntry entry, {required bool selected}) {
    final scheme = Theme.of(context).colorScheme;
    if (_selection.active) {
      return Icon(
        selected ? Icons.check_circle : Icons.circle_outlined,
        color: selected ? scheme.primary : scheme.outline,
      );
    }
    return Icon(
      entry.alwaysOn ? Icons.push_pin_outlined : Icons.bookmark_border,
      size: AppListTile.iconSize,
      color: scheme.onSurfaceVariant,
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final ui = context.ui;
    final project = _project;
    final entries = project?.worldBook.entries ?? const <WorldBookEntry>[];
    final selectionMode = _selection.active;
    final title = selectionMode
        ? (_selection.count == 0
              ? strings.worldBookSelectEntries
              : strings.worldBookSelectedCount(_selection.count))
        : strings.worldBookTitle;

    final List<Widget> actions;
    if (selectionMode) {
      actions = [
        AppIconButton(
          icon: _selection.hasSelection ? Icons.deselect : Icons.select_all,
          tooltip: _selection.hasSelection
              ? strings.worldBookDeselectAll
              : strings.worldBookSelectAll,
          onPressed: project == null
              ? null
              : () => _selection.toggleAll(entries.map((e) => e.id)),
        ),
        if (_selection.hasSelection)
          AppIconButton(
            icon: Icons.delete_outline,
            tooltip: ui.delete,
            danger: true,
            onPressed: _deleteSelected,
          ),
      ];
    } else {
      actions = [
        AppCircleButton(
          icon: Icons.add,
          tooltip: strings.worldBookAddEntry,
          onPressed: _loading || _error != null ? null : () => _editEntry(),
        ),
      ];
    }

    return PopScope(
      canPop: !selectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _selection.exit();
      },
      child: AppPage(
        title: title,
        onBack: selectionMode
            ? _selection.exit
            : () => Navigator.of(context).maybePop(),
        actions: actions,
      body: AppPageBody.list(
        children: [
          if (_loading)
            AppPageGutter(
              child: AppText(ui.loading, role: AppTextRole.caption),
            )
          else if (_error != null)
            AppPageGutter(
              child: AppEmptyState(
                message: strings.worldBookOpenFailed,
                detail: _error.toString(),
                action: AppButton(
                  label: ui.retry,
                  onPressed: _load,
                  variant: AppButtonVariant.secondary,
                ),
              ),
            )
          else if (project != null) ...[
            AppSectionHeader(
              strings.worldBookEntriesSection,
              subtitle: strings.worldBookSectionHint,
              gutter: true,
            ),
            if (entries.isEmpty)
              AppPageGutter(
                child: AppEmptyState(
                  message: strings.worldBookEmpty,
                  detail: strings.worldBookEmptyDetail,
                  action: AppButton(
                    label: strings.addOne,
                    onPressed: () => _editEntry(),
                    variant: AppButtonVariant.secondary,
                  ),
                ),
              )
            else
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < entries.length; i++) ...[
                    AppListTile(
                      title:
                          entries[i].title.isEmpty
                              ? strings.worldBookUnnamedEntry
                              : entries[i].title,
                      subtitle: _subtitle(strings, entries[i]),
                      leading: _entryLeading(
                        entries[i],
                        selected: _selection.isSelected(entries[i].id),
                      ),
                      icon: null,
                      trailing:
                          selectionMode ? null : const AppForwardIcon(),
                      selected:
                          selectionMode && _selection.isSelected(entries[i].id),
                      showDivider: false,
                      onTap: () {
                        if (selectionMode) {
                          _selection.toggle(entries[i].id);
                        } else {
                          _editEntry(existing: entries[i]);
                        }
                      },
                      onLongPress: () => _selection.enter(id: entries[i].id),
                    ),
                    if (i < entries.length - 1) const AppListHairline(),
                  ],
                ],
              ),
          ],
        ],
      ),
    ),
    );
  }
}

class _EntrySheetResult {
  const _EntrySheetResult(this.entry);

  final WorldBookEntry entry;
}

/// Owns [TextEditingController]s for the entry sheet so they outlive the
/// modal route close animation (parent must not dispose right after [pop]).
class _WorldBookEntrySheet extends StatefulWidget {
  const _WorldBookEntrySheet({
    required this.draft,
    required this.existing,
  });

  final WorldBookEntry draft;
  final WorldBookEntry? existing;

  @override
  State<_WorldBookEntrySheet> createState() => _WorldBookEntrySheetState();
}

class _WorldBookEntrySheetState extends State<_WorldBookEntrySheet> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late final TextEditingController _keys;
  late final WorldBookEntry _baseline;
  late bool _alwaysOn;

  @override
  void initState() {
    super.initState();
    _baseline = widget.draft;
    _title = TextEditingController(text: widget.draft.title);
    _body = TextEditingController(text: widget.draft.body);
    _keys = TextEditingController(text: widget.draft.keys.join('、'));
    _alwaysOn = widget.draft.alwaysOn;
    for (final c in [_title, _body, _keys]) {
      c.addListener(_markDirty);
    }
  }

  void _markDirty() => setState(() {});

  @override
  void dispose() {
    for (final c in [_title, _body, _keys]) {
      c.removeListener(_markDirty);
    }
    _title.dispose();
    _body.dispose();
    _keys.dispose();
    super.dispose();
  }

  List<String> _parseKeys() => _keys.text
      .split(RegExp(r'[,，、\s]+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList(growable: false);

  WorldBookEntry _snapshot() {
    final nextKeys = _alwaysOn ? const <String>[] : _parseKeys();
    return widget.draft.copyWith(
      title: _title.text.trim(),
      body: _body.text.trim(),
      alwaysOn: _alwaysOn,
      keys: nextKeys,
    );
  }

  bool get _isDirty => !_entriesEqual(_snapshot(), _baseline);

  static bool _entriesEqual(WorldBookEntry a, WorldBookEntry b) {
    return a.title == b.title &&
        a.body == b.body &&
        a.alwaysOn == b.alwaysOn &&
        _listEqual(a.keys, b.keys);
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
      _EntrySheetResult(
        next.copyWith(
          title: next.title.isEmpty
              ? context.strings.worldBookUnnamedEntry
              : next.title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final existing = widget.existing;
    return AppSheetEditForm(
      title: existing == null
          ? strings.worldBookNewEntry
          : strings.worldBookEditEntry,
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
            label: strings.titleLabel,
            controller: _title,
            hint: strings.worldBookTitleHint,
          ),
          const SizedBox(height: AppTheme.spaceMd),
          AppTextField(
            label: strings.bodyLabel,
            controller: _body,
            minLines: 4,
            maxLines: 10,
            hint: strings.worldBookBodyHint,
          ),
          const SizedBox(height: AppTheme.spaceMd),
          AppListTile(
            title: strings.worldBookAlwaysOn,
            subtitle: strings.worldBookAlwaysOnHint,
            icon: Icons.push_pin_outlined,
            trailing: AppSwitch(
              value: _alwaysOn,
              onChanged: (value) => setState(() => _alwaysOn = value),
            ),
          ),
          if (!_alwaysOn) ...[
            const SizedBox(height: AppTheme.spaceMd),
            AppTextField(
              label: strings.keywordLabel,
              controller: _keys,
              hint: strings.worldBookKeywordsHint,
            ),
          ],
        ],
      ),
    );
  }
}