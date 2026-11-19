import 'package:anoworld/domain/models/json_map.dart';
import 'package:anoworld/domain/models/plot_element.dart';
import 'package:anoworld/domain/settings/built_in_plot_elements.dart';

/// Global plot-element library: seeds + overrides + deletions + custom rows.
class PlotElementCatalog {
  PlotElementCatalog({
    Map<String, PlotElementOverride>? overrides,
    Set<String>? deletedBuiltInIds,
    List<PlotElement>? custom,
  })  : overrides = Map.unmodifiable(overrides ?? const {}),
        deletedBuiltInIds = Set.unmodifiable(deletedBuiltInIds ?? const {}),
        custom = List.unmodifiable(custom ?? const []);

  final Map<String, PlotElementOverride> overrides;
  final Set<String> deletedBuiltInIds;
  final List<PlotElement> custom;

  bool isBuiltInId(String id) => BuiltInPlotElements.containsId(id);

  bool isDeletedBuiltIn(String id) => deletedBuiltInIds.contains(id);

  bool isModifiedBuiltIn(String id) =>
      isBuiltInId(id) && overrides.containsKey(id);

  PlotElement? seedOf(String id) => BuiltInPlotElements.byId[id];

  /// Visible library for pickers and management UI.
  List<PlotElement> get effectiveList {
    final rows = <PlotElement>[];
    for (final seed in BuiltInPlotElements.all) {
      if (deletedBuiltInIds.contains(seed.id)) continue;
      final over = overrides[seed.id];
      if (over == null) {
        rows.add(seed);
      } else {
        rows.add(
          PlotElement(
            id: seed.id,
            keyword: over.keyword,
            description: over.description,
          ),
        );
      }
    }
    rows.addAll(custom);
    return List.unmodifiable(rows);
  }

  PlotElement? byId(String id) {
    for (final row in effectiveList) {
      if (row.id == id) return row;
    }
    return null;
  }

  /// Resolve selected story ids to elements (skip missing).
  List<PlotElement> resolveSelected(Iterable<String> ids) {
    final out = <PlotElement>[];
    for (final id in ids) {
      final row = byId(id);
      if (row != null) out.add(row);
    }
    return List.unmodifiable(out);
  }

  /// Short prompt block for bridge / continue writing (empty if none).
  String promptBlockForSelected(Iterable<String> ids) {
    final rows = resolveSelected(ids);
    if (rows.isEmpty) return '';
    final lines = rows
        .map((e) => '- ${e.keyword}：${e.clippedDescription}')
        .join('\n');
    return '可用剧情元素（按需织入支线，勿生硬堆砌）：\n$lines';
  }

  static String clipDescription(String raw) {
    final text = raw.trim();
    if (text.length <= kPlotElementDescriptionMaxChars) return text;
    return text.substring(0, kPlotElementDescriptionMaxChars);
  }

  PlotElementCatalog copyWith({
    Map<String, PlotElementOverride>? overrides,
    Set<String>? deletedBuiltInIds,
    List<PlotElement>? custom,
  }) {
    return PlotElementCatalog(
      overrides: overrides ?? this.overrides,
      deletedBuiltInIds: deletedBuiltInIds ?? this.deletedBuiltInIds,
      custom: custom ?? this.custom,
    );
  }

  PlotElementCatalog updateBuiltIn({
    required String id,
    required String keyword,
    required String description,
  }) {
    if (!isBuiltInId(id) || deletedBuiltInIds.contains(id)) {
      return this;
    }
    final seed = BuiltInPlotElements.byId[id]!;
    final kw = keyword.trim();
    final desc = clipDescription(description);
    final nextOverrides = Map<String, PlotElementOverride>.from(overrides);
    if (kw == seed.keyword && desc == seed.description) {
      nextOverrides.remove(id);
    } else {
      nextOverrides[id] = PlotElementOverride(keyword: kw, description: desc);
    }
    return copyWith(overrides: nextOverrides);
  }

  PlotElementCatalog upsertCustom(PlotElement element) {
    final row = PlotElement(
      id: element.id,
      keyword: element.keyword.trim(),
      description: clipDescription(element.description),
    );
    if (row.keyword.isEmpty) return this;
    if (isBuiltInId(row.id)) {
      return updateBuiltIn(
        id: row.id,
        keyword: row.keyword,
        description: row.description,
      );
    }
    final next = custom.toList(growable: true);
    final index = next.indexWhere((e) => e.id == row.id);
    if (index >= 0) {
      next[index] = row;
    } else {
      next.add(row);
    }
    return copyWith(custom: next);
  }

  PlotElementCatalog delete(String id) {
    if (isBuiltInId(id)) {
      final nextDeleted = Set<String>.from(deletedBuiltInIds)..add(id);
      final nextOverrides = Map<String, PlotElementOverride>.from(overrides)
        ..remove(id);
      return copyWith(
        deletedBuiltInIds: nextDeleted,
        overrides: nextOverrides,
      );
    }
    return copyWith(
      custom: custom.where((e) => e.id != id).toList(growable: false),
    );
  }

  PlotElementCatalog restoreBuiltIn(String id) {
    if (!isBuiltInId(id)) return this;
    final nextDeleted = Set<String>.from(deletedBuiltInIds)..remove(id);
    final nextOverrides = Map<String, PlotElementOverride>.from(overrides)
      ..remove(id);
    return copyWith(
      deletedBuiltInIds: nextDeleted,
      overrides: nextOverrides,
    );
  }

  PlotElementCatalog restoreAllBuiltIns() {
    return copyWith(
      deletedBuiltInIds: const <String>{},
      overrides: const <String, PlotElementOverride>{},
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'overrides': <String, dynamic>{
          for (final e in overrides.entries) e.key: e.value.toJson(),
        },
        'deletedBuiltInIds': deletedBuiltInIds.toList(growable: false),
        'custom': custom.map((e) => e.toJson()).toList(growable: false),
      };

  factory PlotElementCatalog.fromJson(Map<String, dynamic>? json) {
    if (json == null) return PlotElementCatalog();
    final rawOverrides = json.optionalMap('overrides') ?? const {};
    final overrides = <String, PlotElementOverride>{};
    for (final entry in rawOverrides.entries) {
      overrides[entry.key] = PlotElementOverride.fromJson(
        asJsonMap(entry.value, path: 'overrides.${entry.key}'),
      );
    }
    final deleted = json
        .stringList('deletedBuiltInIds', required: false)
        .toSet();
    final custom = <PlotElement>[
      for (final item in json.optionalList('custom'))
        PlotElement.fromJson(asJsonMap(item, path: 'custom[]')),
    ];
    return PlotElementCatalog(
      overrides: overrides,
      deletedBuiltInIds: deleted,
      custom: custom,
    );
  }
}
