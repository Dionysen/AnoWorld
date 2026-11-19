import 'package:anoworld/domain/models/json_map.dart';
import 'package:anoworld/domain/models/plot_element.dart';
import 'package:anoworld/domain/models/plot_element_category.dart';
import 'package:anoworld/domain/models/plot_element_pack.dart';
import 'package:anoworld/domain/settings/built_in_plot_elements.dart';

/// Global plot-element library: seeds + overrides + deletions + custom rows,
/// plus the categories and packs used to group them in the library UI.
class PlotElementCatalog {
  PlotElementCatalog({
    Map<String, PlotElementOverride>? overrides,
    Set<String>? deletedBuiltInIds,
    List<PlotElement>? custom,
    List<PlotElementCategory>? customCategories,
    Map<String, String>? categoryRenames,
    List<PlotElementPack>? packs,
  }) : overrides = Map.unmodifiable(overrides ?? const {}),
       deletedBuiltInIds = Set.unmodifiable(deletedBuiltInIds ?? const {}),
       custom = List.unmodifiable(custom ?? const []),
       customCategories = List.unmodifiable(customCategories ?? const []),
       categoryRenames = Map.unmodifiable(categoryRenames ?? const {}),
       packs = List.unmodifiable(packs ?? const []);

  final Map<String, PlotElementOverride> overrides;
  final Set<String> deletedBuiltInIds;
  final List<PlotElement> custom;

  /// User-created categories, shown after the built-in ones.
  final List<PlotElementCategory> customCategories;

  /// Renamed built-in categories (id → new name).
  final Map<String, String> categoryRenames;

  /// User-created element bundles, applied as a whole in stories.
  final List<PlotElementPack> packs;

  /// Label for elements with no (or no longer existing) category.
  static const String uncategorizedLabel = '未分类';

  bool isBuiltInId(String id) => BuiltInPlotElements.containsId(id);

  bool isDeletedBuiltIn(String id) => deletedBuiltInIds.contains(id);

  bool isModifiedBuiltIn(String id) =>
      isBuiltInId(id) && overrides.containsKey(id);

  PlotElement? seedOf(String id) => BuiltInPlotElements.byId[id];

  bool isBuiltInCategoryId(String id) =>
      BuiltInPlotElementCategories.containsId(id);

  /// All categories in display order: built-ins (with renames), then custom.
  /// Cached — the catalog is immutable and row titles read this per item.
  late final List<PlotElementCategory> categories = List.unmodifiable([
    for (final seed in BuiltInPlotElementCategories.all)
      categoryRenames[seed.id] == null
          ? seed
          : seed.copyWith(name: categoryRenames[seed.id]),
    ...customCategories,
  ]);

  late final Map<String, PlotElementCategory> _categoryById = {
    for (final category in categories) category.id: category,
  };

  PlotElementCategory? categoryById(String id) {
    if (id.isEmpty) return null;
    return _categoryById[id];
  }

  String categoryNameOf(String id) =>
      categoryById(id)?.name ?? uncategorizedLabel;

  /// Visible library for pickers and management UI. Cached: rebuilding this
  /// on every row/title read made long libraries sluggish.
  late final List<PlotElement> effectiveList = _buildEffectiveList();

  List<PlotElement> _buildEffectiveList() {
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
            categoryId: over.categoryId ?? seed.categoryId,
          ),
        );
      }
    }
    rows.addAll(custom);
    return List.unmodifiable(rows);
  }

  late final Map<String, PlotElement> _byId = {
    for (final row in effectiveList) row.id: row,
  };

  late final Map<String, List<PlotElement>> _byCategory = _groupByCategory();

  Map<String, List<PlotElement>> _groupByCategory() {
    final grouped = <String, List<PlotElement>>{};
    for (final row in effectiveList) {
      (grouped[row.categoryId] ??= <PlotElement>[]).add(row);
    }
    return {
      for (final entry in grouped.entries)
        entry.key: List.unmodifiable(entry.value),
    };
  }

  /// Elements grouped under [categoryId] (empty string = uncategorized).
  List<PlotElement> elementsOfCategory(String categoryId) =>
      _byCategory[categoryId] ?? const <PlotElement>[];

  /// Elements whose category was removed or never set.
  List<PlotElement> get uncategorizedElements => elementsOfCategory('');

  PlotElement? byId(String id) => _byId[id];

  late final Map<String, PlotElementPack> _packById = {
    for (final pack in packs) pack.id: pack,
  };

  PlotElementPack? packById(String id) => _packById[id];

  /// Resolvable rows of [pack]; ids of deleted elements are skipped.
  List<PlotElement> elementsOfPack(PlotElementPack pack) =>
      resolveSelected(pack.elementIds);

  /// Adds or replaces a pack; drops ids that no longer exist in the library.
  PlotElementCatalog upsertPack(PlotElementPack pack) {
    final name = pack.name.trim();
    if (name.isEmpty) return this;
    final ids = <String>[];
    for (final id in pack.elementIds) {
      if (byId(id) != null && !ids.contains(id)) ids.add(id);
    }
    final row = pack.copyWith(name: name, elementIds: List.unmodifiable(ids));
    final next = packs.toList(growable: true);
    final index = next.indexWhere((p) => p.id == row.id);
    if (index >= 0) {
      next[index] = row;
    } else {
      next.add(row);
    }
    return copyWith(packs: next);
  }

  PlotElementCatalog deletePack(String id) {
    if (packById(id) == null) return this;
    return copyWith(
      packs: packs.where((p) => p.id != id).toList(growable: false),
    );
  }

  PlotElementCatalog renamePack(String id, String name) {
    final pack = packById(id);
    if (pack == null) return this;
    return upsertPack(pack.copyWith(name: name));
  }

  /// Applied packs that still exist in the library, in recorded order.
  List<PlotElementPack> appliedPacks(Iterable<String> appliedPackIds) {
    final out = <PlotElementPack>[];
    for (final id in appliedPackIds) {
      final pack = _packById[id];
      if (pack != null && !out.contains(pack)) out.add(pack);
    }
    return List.unmodifiable(out);
  }

  /// Every element id covered by [appliedPackIds] (union of their members).
  Set<String> coveredIds(Iterable<String> appliedPackIds) => <String>{
    for (final pack in appliedPacks(appliedPackIds))
      for (final element in elementsOfPack(pack)) element.id,
  };

  /// Simulates switching [pack] on without mutating any selection.
  PackApplyPlan planPackApply(
    PlotElementPack pack,
    PlotElementSelection selection,
  ) {
    final selected = selection.selectedIds.toSet();
    final owners = _packOwners(selection.appliedPackIds, exceptId: pack.id);
    final added = <String>[];
    final manual = <String>[];
    final overlapped = <String>[];
    final names = <String>[];
    for (final element in elementsOfPack(pack)) {
      if (!selected.contains(element.id)) {
        added.add(element.id);
        continue;
      }
      final sources = owners[element.id];
      if (sources == null) {
        manual.add(element.id);
        continue;
      }
      overlapped.add(element.id);
      for (final name in sources) {
        if (!names.contains(name)) names.add(name);
      }
    }
    return PackApplyPlan(
      addedIds: List.unmodifiable(added),
      manualSharedIds: List.unmodifiable(manual),
      overlappedIds: List.unmodifiable(overlapped),
      overlapNames: List.unmodifiable(names),
    );
  }

  /// Simulates switching [pack] off: ids other applied packs still need stay.
  PackRemovePlan planPackRemove(
    PlotElementPack pack,
    PlotElementSelection selection,
  ) {
    final selected = selection.selectedIds.toSet();
    final owners = _packOwners(selection.appliedPackIds, exceptId: pack.id);
    final removed = <String>[];
    final kept = <String>[];
    final names = <String>[];
    for (final element in elementsOfPack(pack)) {
      if (!selected.contains(element.id)) continue;
      final sources = owners[element.id];
      if (sources == null) {
        removed.add(element.id);
        continue;
      }
      kept.add(element.id);
      for (final name in sources) {
        if (!names.contains(name)) names.add(name);
      }
    }
    return PackRemovePlan(
      removedIds: List.unmodifiable(removed),
      keptIds: List.unmodifiable(kept),
      keptByNames: List.unmodifiable(names),
    );
  }

  /// element id → names of the packs covering it, ignoring [exceptId].
  Map<String, List<String>> _packOwners(
    Iterable<String> appliedPackIds, {
    required String exceptId,
  }) {
    final owners = <String, List<String>>{};
    for (final pack in appliedPacks(appliedPackIds)) {
      if (pack.id == exceptId) continue;
      for (final element in elementsOfPack(pack)) {
        (owners[element.id] ??= <String>[]).add(pack.name);
      }
    }
    return owners;
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
    List<PlotElementCategory>? customCategories,
    Map<String, String>? categoryRenames,
    List<PlotElementPack>? packs,
  }) {
    return PlotElementCatalog(
      overrides: overrides ?? this.overrides,
      deletedBuiltInIds: deletedBuiltInIds ?? this.deletedBuiltInIds,
      custom: custom ?? this.custom,
      customCategories: customCategories ?? this.customCategories,
      categoryRenames: categoryRenames ?? this.categoryRenames,
      packs: packs ?? this.packs,
    );
  }

  PlotElementCatalog updateBuiltIn({
    required String id,
    required String keyword,
    required String description,
    String? categoryId,
  }) {
    if (!isBuiltInId(id) || deletedBuiltInIds.contains(id)) {
      return this;
    }
    final seed = BuiltInPlotElements.byId[id]!;
    final kw = keyword.trim();
    final desc = clipDescription(description);
    final cat = categoryId ?? overrides[id]?.categoryId ?? seed.categoryId;
    final nextOverrides = Map<String, PlotElementOverride>.from(overrides);
    if (kw == seed.keyword &&
        desc == seed.description &&
        cat == seed.categoryId) {
      nextOverrides.remove(id);
    } else {
      nextOverrides[id] = PlotElementOverride(
        keyword: kw,
        description: desc,
        categoryId: cat == seed.categoryId ? null : cat,
      );
    }
    return copyWith(overrides: nextOverrides);
  }

  PlotElementCatalog upsertCustom(PlotElement element) {
    final row = PlotElement(
      id: element.id,
      keyword: element.keyword.trim(),
      description: clipDescription(element.description),
      categoryId: element.categoryId,
    );
    if (row.keyword.isEmpty) return this;
    if (isBuiltInId(row.id)) {
      return updateBuiltIn(
        id: row.id,
        keyword: row.keyword,
        description: row.description,
        categoryId: row.categoryId,
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
    List<PlotElementPack>? nextPacks;
    if (packs.any((pack) => pack.contains(id))) {
      nextPacks = [
        for (final pack in packs)
          pack.contains(id)
              ? pack.copyWith(
                  elementIds: List.unmodifiable(
                    pack.elementIds.where((e) => e != id),
                  ),
                )
              : pack,
      ];
    }
    if (isBuiltInId(id)) {
      final nextDeleted = Set<String>.from(deletedBuiltInIds)..add(id);
      final nextOverrides = Map<String, PlotElementOverride>.from(overrides)
        ..remove(id);
      return copyWith(
        deletedBuiltInIds: nextDeleted,
        overrides: nextOverrides,
        packs: nextPacks,
      );
    }
    return copyWith(
      custom: custom.where((e) => e.id != id).toList(growable: false),
      packs: nextPacks,
    );
  }

  PlotElementCatalog restoreBuiltIn(String id) {
    if (!isBuiltInId(id)) return this;
    final nextDeleted = Set<String>.from(deletedBuiltInIds)..remove(id);
    final nextOverrides = Map<String, PlotElementOverride>.from(overrides)
      ..remove(id);
    return copyWith(deletedBuiltInIds: nextDeleted, overrides: nextOverrides);
  }

  PlotElementCatalog restoreAllBuiltIns() {
    return copyWith(
      deletedBuiltInIds: const <String>{},
      overrides: const <String, PlotElementOverride>{},
      categoryRenames: const <String, String>{},
    );
  }

  PlotElementCatalog assignCategory(String elementId, String categoryId) {
    final element = byId(elementId);
    if (element == null) return this;
    final next = categoryById(categoryId) == null ? '' : categoryId;
    if (element.categoryId == next) return this;
    if (isBuiltInId(elementId)) {
      return updateBuiltIn(
        id: elementId,
        keyword: element.keyword,
        description: element.description,
        categoryId: next,
      );
    }
    return upsertCustom(element.copyWith(categoryId: next));
  }

  /// Adds a user category; ignores blank names and duplicate ids.
  PlotElementCatalog addCategory(PlotElementCategory category) {
    final name = category.name.trim();
    if (name.isEmpty || categoryById(category.id) != null) return this;
    return copyWith(
      customCategories: [
        ...customCategories,
        category.copyWith(name: name),
      ],
    );
  }

  /// Renames a built-in (sticky) or user-created category.
  PlotElementCatalog renameCategory(String id, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return this;
    final seed = BuiltInPlotElementCategories.byId[id];
    if (seed != null) {
      final next = Map<String, String>.from(categoryRenames);
      if (trimmed == seed.name) {
        next.remove(id);
      } else {
        next[id] = trimmed;
      }
      return copyWith(categoryRenames: next);
    }
    final index = customCategories.indexWhere((c) => c.id == id);
    if (index < 0) return this;
    final next = List<PlotElementCategory>.of(customCategories);
    next[index] = next[index].copyWith(name: trimmed);
    return copyWith(customCategories: next);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'overrides': <String, dynamic>{
      for (final e in overrides.entries) e.key: e.value.toJson(),
    },
    'deletedBuiltInIds': deletedBuiltInIds.toList(growable: false),
    'custom': custom.map((e) => e.toJson()).toList(growable: false),
    'customCategories': customCategories
        .map((e) => e.toJson())
        .toList(growable: false),
    'categoryRenames': categoryRenames,
    'packs': packs.map((e) => e.toJson()).toList(growable: false),
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
    final customCategories = <PlotElementCategory>[
      for (final item in json.optionalList('customCategories'))
        PlotElementCategory.fromJson(
          asJsonMap(item, path: 'customCategories[]'),
        ),
    ];
    final rawRenames = json.optionalMap('categoryRenames') ?? const {};
    final categoryRenames = <String, String>{
      for (final entry in rawRenames.entries)
        if (entry.value is String && entry.key.isNotEmpty)
          entry.key: (entry.value as String).trim(),
    }..removeWhere((_, name) => name.isEmpty);
    final packs = <PlotElementPack>[
      for (final item in json.optionalList('packs'))
        PlotElementPack.fromJson(asJsonMap(item, path: 'packs[]')),
    ].where((pack) => pack.name.isNotEmpty).toList(growable: false);
    return PlotElementCatalog(
      overrides: overrides,
      deletedBuiltInIds: deleted,
      custom: custom,
      customCategories: customCategories,
      categoryRenames: categoryRenames,
      packs: packs,
    );
  }
}
