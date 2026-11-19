import 'package:anoworld/domain/models/json_map.dart';

/// Max characters for [PlotElement.description] (说明 + 示例剧情).
const int kPlotElementDescriptionMaxChars = 300;

/// One reusable plot element (keyword + short description with example beat).
class PlotElement {
  const PlotElement({
    required this.id,
    required this.keyword,
    required this.description,
    this.categoryId = '',
  });

  final String id;
  final String keyword;
  final String description;

  /// Global [PlotElementCategory] id; empty means uncategorized.
  final String categoryId;

  String get clippedDescription {
    final text = description.trim();
    if (text.length <= kPlotElementDescriptionMaxChars) return text;
    return text.substring(0, kPlotElementDescriptionMaxChars);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'keyword': keyword,
    'description': description,
    if (categoryId.isNotEmpty) 'categoryId': categoryId,
  };

  factory PlotElement.fromJson(Map<String, dynamic> json) {
    return PlotElement(
      id: json.requireString('id'),
      keyword: json.requireString('keyword').trim(),
      description: json.requireString('description').trim(),
      categoryId: json.optionalString('categoryId') ?? '',
    );
  }

  PlotElement copyWith({
    String? id,
    String? keyword,
    String? description,
    String? categoryId,
  }) {
    return PlotElement(
      id: id ?? this.id,
      keyword: keyword ?? this.keyword,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
    );
  }
}

/// Keyword / description / category override for a built-in seed id.
class PlotElementOverride {
  const PlotElementOverride({
    required this.keyword,
    required this.description,
    this.categoryId,
  });

  final String keyword;
  final String description;

  /// Null keeps the seed's own category.
  final String? categoryId;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'keyword': keyword,
    'description': description,
    if (categoryId != null) 'categoryId': categoryId,
  };

  factory PlotElementOverride.fromJson(Map<String, dynamic> json) {
    return PlotElementOverride(
      keyword: json.requireString('keyword').trim(),
      description: json.requireString('description').trim(),
      categoryId: json.optionalString('categoryId'),
    );
  }
}

/// Per-story selection of global plot-element ids.
class PlotElementSelection {
  const PlotElementSelection({
    this.selectedIds = const <String>[],
    this.appliedPackIds = const <String>[],
  });

  final List<String> selectedIds;

  /// Packs the user switched on; used to know which selected ids a pack owns.
  final List<String> appliedPackIds;

  bool get isEmpty => selectedIds.isEmpty;

  int get count => selectedIds.length;

  bool hasPack(String packId) => appliedPackIds.contains(packId);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'selectedIds': selectedIds,
    if (appliedPackIds.isNotEmpty) 'appliedPackIds': appliedPackIds,
  };

  factory PlotElementSelection.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PlotElementSelection();
    return PlotElementSelection(
      selectedIds: json.stringList('selectedIds', required: false),
      appliedPackIds: json.stringList('appliedPackIds', required: false),
    );
  }

  PlotElementSelection copyWith({
    List<String>? selectedIds,
    List<String>? appliedPackIds,
  }) {
    return PlotElementSelection(
      selectedIds: selectedIds ?? this.selectedIds,
      appliedPackIds: appliedPackIds ?? this.appliedPackIds,
    );
  }

  PlotElementSelection withToggle(String id, {required bool selected}) {
    final next = selectedIds.toList(growable: true);
    if (selected) {
      if (!next.contains(id)) next.add(id);
    } else {
      next.remove(id);
    }
    return PlotElementSelection(
      selectedIds: List.unmodifiable(next),
      appliedPackIds: appliedPackIds,
    );
  }

  /// Applies (or clears) a whole set of ids at once, e.g. a plot-element pack.
  PlotElementSelection withIds(
    Iterable<String> ids, {
    required bool selected,
  }) {
    final targets = ids.toSet();
    if (targets.isEmpty) return this;
    final next = selectedIds.toList(growable: true);
    if (selected) {
      for (final id in targets) {
        if (!next.contains(id)) next.add(id);
      }
    } else {
      next.removeWhere(targets.contains);
    }
    return PlotElementSelection(
      selectedIds: List.unmodifiable(next),
      appliedPackIds: appliedPackIds,
    );
  }

  /// Marks [packId] as switched on/off without touching the element ids.
  PlotElementSelection withPackApplied(
    String packId, {
    required bool applied,
  }) {
    final current = appliedPackIds.contains(packId);
    if (current == applied) return this;
    final next = appliedPackIds.toList(growable: true);
    if (applied) {
      next.add(packId);
    } else {
      next.remove(packId);
    }
    return copyWith(appliedPackIds: List.unmodifiable(next));
  }
}
