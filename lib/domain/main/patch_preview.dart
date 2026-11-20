import 'package:anoworld/domain/main/apply_cast_patch.dart';
import 'package:anoworld/domain/main/apply_main_graph_patch.dart';
import 'package:anoworld/domain/main/apply_plot_patch.dart';
import 'package:anoworld/domain/main/apply_world_book_patch.dart';
import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/world_book.dart';

/// What one diff entry refers to.
enum PatchTargetKind { worldBook, cast, node, edge, storySummary, plotElement }

/// One field difference inside a patch op.
///
/// [before] / [after] are raw values (`String`, `bool`, `List<String>`);
/// formatting is the UI's job so this layer stays presentation-free.
class PatchFieldChange {
  const PatchFieldChange({required this.field, this.before, this.after});

  final String field;
  final Object? before;
  final Object? after;

  bool get isAdded => before == null && after != null;
  bool get isRemoved => before != null && after == null;
  bool get isEdited => before != null && after != null;
}

/// One entity touched by a patch op.
class PatchEntityChange {
  const PatchEntityChange({
    required this.kind,
    required this.id,
    required this.label,
    required this.added,
    required this.removed,
    required this.fields,
  });

  final PatchTargetKind kind;
  final String id;

  /// Display name of the entity (entry title, member name, `A → B`, ...).
  final String label;
  final bool added;
  final bool removed;

  /// Changed fields only; empty for a pure removal.
  final List<PatchFieldChange> fields;
}

/// Preview of a single op inside a patch proposal.
class PatchPreviewItem {
  const PatchPreviewItem({
    required this.index,
    required this.opName,
    required this.changes,
    this.error,
  });

  /// Index into the proposal's `ops` array.
  final int index;
  final String opName;
  final List<PatchEntityChange> changes;

  /// Set when this op cannot be applied on its own (bad id, broken reference).
  final String? error;

  bool get hasChanges => changes.isNotEmpty;

  /// Ops the user can tick: no error and at least one real change.
  bool get usable => error == null && hasChanges;
}

/// Ops of one proposal plus the per-op diff used by the review sheet.
class PatchPreview<T> {
  const PatchPreview({
    required this.base,
    required this.ops,
    required this.items,
    required this.applyOps,
  });

  final T base;
  final List<Map<String, dynamic>> ops;
  final List<PatchPreviewItem> items;

  /// Replays [ops] onto [base]; supplied per layer by the builders below.
  final T Function(List<Map<String, dynamic>> ops) applyOps;

  /// Ops ticked by default: everything that applies and actually changes data.
  Set<int> get defaultSelection => {
        for (final item in items)
          if (item.usable) item.index,
      };

  /// Applies only the ticked ops (in original order) onto [base].
  T applySelected(Set<int> selected) => applyOps([
        for (var i = 0; i < ops.length; i++)
          if (selected.contains(i)) ops[i],
      ]);
}

PatchPreview<WorldBook> buildWorldBookPreview(
  WorldBook base,
  List<Map<String, dynamic>> ops,
) {
  const applier = ApplyWorldBookPatch();
  final items = <PatchPreviewItem>[];
  var current = base;
  for (var i = 0; i < ops.length; i++) {
    final op = ops[i];
    final name = _opName(op);
    if (name.isEmpty) {
      items.add(_broken(i, '', '缺少操作类型'));
      continue;
    }
    final before = _worldSnapshot(current);
    final WorldBook next;
    try {
      next = applier.apply(current, [op]);
    } on ApplyWorldBookPatchException catch (error) {
      items.add(_broken(i, name, error.message));
      continue;
    }
    items.add(
      PatchPreviewItem(
        index: i,
        opName: name,
        changes: _diff(before, _worldSnapshot(next)),
      ),
    );
    current = next;
  }
  return PatchPreview<WorldBook>(
    base: base,
    ops: ops,
    items: items,
    applyOps: (list) => applier.apply(base, list),
  );
}

PatchPreview<List<CastMember>> buildCastPreview(
  List<CastMember> base,
  List<Map<String, dynamic>> ops,
) {
  const applier = ApplyCastPatch();
  final items = <PatchPreviewItem>[];
  var current = base;
  for (var i = 0; i < ops.length; i++) {
    final op = ops[i];
    final name = _opName(op);
    if (name.isEmpty) {
      items.add(_broken(i, '', '缺少操作类型'));
      continue;
    }
    final before = _castSnapshot(current);
    final List<CastMember> next;
    try {
      next = applier.apply(current, [op]);
    } on ApplyCastPatchException catch (error) {
      items.add(_broken(i, name, error.message));
      continue;
    }
    items.add(
      PatchPreviewItem(
        index: i,
        opName: name,
        changes: _diff(before, _castSnapshot(next)),
      ),
    );
    current = next;
  }
  return PatchPreview<List<CastMember>>(
    base: base,
    ops: ops,
    items: items,
    applyOps: (list) => applier.apply(base, list),
  );
}

PatchPreview<MainStory> buildMainGraphPreview(
  MainStory base,
  List<Map<String, dynamic>> ops,
) {
  const applier = ApplyMainGraphPatch();
  final items = <PatchPreviewItem>[];
  var current = base;
  for (var i = 0; i < ops.length; i++) {
    final op = ops[i];
    final name = _opName(op);
    if (name.isEmpty) {
      items.add(_broken(i, '', '缺少操作类型'));
      continue;
    }
    final before = _graphSnapshot(current);
    final MainStory next;
    try {
      next = applier.apply(current, [op]);
    } on ApplyMainGraphPatchException catch (error) {
      items.add(_broken(i, name, error.message));
      continue;
    }
    items.add(
      PatchPreviewItem(
        index: i,
        opName: name,
        changes: _diff(before, _graphSnapshot(next)),
      ),
    );
    current = next;
  }
  return PatchPreview<MainStory>(
    base: base,
    ops: ops,
    items: items,
    applyOps: (list) => applier.apply(base, list),
  );
}

PatchPreview<PlotPatchState> buildPlotPreview(
  PlotPatchState base,
  List<Map<String, dynamic>> ops,
) {
  const applier = ApplyPlotPatch();
  final items = <PatchPreviewItem>[];
  var current = base;
  for (var i = 0; i < ops.length; i++) {
    final op = ops[i];
    final name = _opName(op);
    if (name.isEmpty) {
      items.add(_broken(i, '', '缺少操作类型'));
      continue;
    }
    final before = _plotSnapshot(current);
    final PlotPatchState next;
    try {
      next = applier.apply(current, <Map<String, dynamic>>[op]);
    } on ApplyPlotPatchException catch (error) {
      items.add(_broken(i, name, error.message));
      continue;
    }
    items.add(
      PatchPreviewItem(
        index: i,
        opName: name,
        changes: _diff(before, _plotSnapshot(next)),
      ),
    );
    current = next;
  }
  return PatchPreview<PlotPatchState>(
    base: base,
    ops: ops,
    items: items,
    applyOps: (list) => applier.apply(
      PlotPatchState(catalog: base.catalog, selection: base.selection),
      list,
    ),
  );
}

PatchPreviewItem _broken(int index, String opName, String message) =>
    PatchPreviewItem(
      index: index,
      opName: opName,
      changes: const [],
      error: message,
    );

String _opName(Map<String, dynamic> op) => (op['op']?.toString() ?? '').trim();

/// Value snapshot of one entity; `fields` holds the addressable attrs.
class _Entity {
  const _Entity({
    required this.kind,
    required this.id,
    required this.label,
    required this.fields,
  });

  final PatchTargetKind kind;
  final String id;
  final String label;
  final Map<String, Object?> fields;
}

const String _storySummaryKey = '#summary';

Map<String, _Entity> _worldSnapshot(WorldBook book) => {
      for (final entry in book.entries)
        entry.id: _Entity(
          kind: PatchTargetKind.worldBook,
          id: entry.id,
          label: entry.title,
          fields: {
            'title': entry.title,
            'body': entry.body,
            'alwaysOn': entry.alwaysOn,
            'keys': entry.keys,
          },
        ),
    };

Map<String, _Entity> _castSnapshot(List<CastMember> cast) => {
      for (final member in cast)
        member.id: _Entity(
          kind: PatchTargetKind.cast,
          id: member.id,
          label: member.name,
          fields: {
            'name': member.name,
            'summary': member.summary,
            'personality': member.personality,
            'speechStyle': member.speechStyle,
            'exampleLines': member.exampleLines,
            'isProtagonist': member.isProtagonist,
          },
        ),
    };

Map<String, _Entity> _plotSnapshot(PlotPatchState state) => {
      for (final element in state.catalog.effectiveList)
        element.id: _Entity(
          kind: PatchTargetKind.plotElement,
          id: element.id,
          label: element.keyword,
          fields: {
            'keyword': element.keyword,
            'category': state.catalog.categoryNameOf(element.categoryId),
            'description': element.description,
            'selected': state.selection.selectedIds.contains(element.id),
          },
        ),
    };

Map<String, _Entity> _graphSnapshot(MainStory main) {
  final titles = {for (final node in main.nodes) node.id: node.title};
  return {
    _storySummaryKey: _Entity(
      kind: PatchTargetKind.storySummary,
      id: '',
      label: '',
      fields: {'storySummary': main.summary},
    ),
    for (final node in main.nodes)
      'node:${node.id}': _Entity(
        kind: PatchTargetKind.node,
        id: node.id,
        label: node.title,
        fields: {
          'title': node.title,
          'synopsis': node.synopsis ?? '',
          'tags': node.tags,
        },
      ),
    for (final edge in main.edges)
      'edge:${edge.id}': _Entity(
        kind: PatchTargetKind.edge,
        id: edge.id,
        label: '${titles[edge.from] ?? edge.from} → '
            '${titles[edge.to] ?? edge.to}',
        fields: {
          'from': edge.from,
          'to': edge.to,
          'kind': edge.kind == EdgeKind.branch ? 'branch' : 'default',
          'label': edge.label ?? '',
          'detail': edge.detail ?? '',
        },
      ),
  };
}

List<PatchEntityChange> _diff(
  Map<String, _Entity> before,
  Map<String, _Entity> after,
) {
  final changes = <PatchEntityChange>[];
  for (final entry in after.entries) {
    final next = entry.value;
    final prev = before[entry.key];
    if (prev == null) {
      changes.add(
        PatchEntityChange(
          kind: next.kind,
          id: next.id,
          label: next.label,
          added: true,
          removed: false,
          fields: _filledFields(next),
        ),
      );
      continue;
    }
    final changed = _changedFields(prev.fields, next.fields);
    if (changed.isEmpty && prev.label == next.label) continue;
    changes.add(
      PatchEntityChange(
        kind: next.kind,
        id: next.id,
        label: next.label,
        added: false,
        removed: false,
        fields: changed,
      ),
    );
  }
  for (final entry in before.entries) {
    if (after.containsKey(entry.key)) continue;
    changes.add(
      PatchEntityChange(
        kind: entry.value.kind,
        id: entry.value.id,
        label: entry.value.label,
        added: false,
        removed: true,
        fields: const [],
      ),
    );
  }
  return changes;
}

/// Non-empty fields of a newly added entity, so the sheet can show its content.
List<PatchFieldChange> _filledFields(_Entity entity) {
  const skipOnAdd = {'from', 'to'};
  return [
    for (final entry in entity.fields.entries)
      if (!skipOnAdd.contains(entry.key) && !_isBlank(entry.value))
        PatchFieldChange(field: entry.key, after: entry.value),
  ];
}

List<PatchFieldChange> _changedFields(
  Map<String, Object?> before,
  Map<String, Object?> after,
) {
  final out = <PatchFieldChange>[];
  for (final entry in after.entries) {
    final prev = before[entry.key];
    if (_same(prev, entry.value)) continue;
    out.add(
      PatchFieldChange(field: entry.key, before: prev, after: entry.value),
    );
  }
  return out;
}

bool _isBlank(Object? value) {
  if (value == null) return true;
  if (value is String) return value.trim().isEmpty;
  if (value is List) return value.isEmpty;
  return false;
}

bool _same(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_same(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}
