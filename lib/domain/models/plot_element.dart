import 'package:anoworld/domain/models/json_map.dart';

/// Max characters for [PlotElement.description] (说明 + 示例剧情).
const int kPlotElementDescriptionMaxChars = 300;

/// One reusable plot element (keyword + short description with example beat).
class PlotElement {
  const PlotElement({
    required this.id,
    required this.keyword,
    required this.description,
  });

  final String id;
  final String keyword;
  final String description;

  String get clippedDescription {
    final text = description.trim();
    if (text.length <= kPlotElementDescriptionMaxChars) return text;
    return text.substring(0, kPlotElementDescriptionMaxChars);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'keyword': keyword,
        'description': description,
      };

  factory PlotElement.fromJson(Map<String, dynamic> json) {
    return PlotElement(
      id: json.requireString('id'),
      keyword: json.requireString('keyword').trim(),
      description: json.requireString('description').trim(),
    );
  }

  PlotElement copyWith({
    String? id,
    String? keyword,
    String? description,
  }) {
    return PlotElement(
      id: id ?? this.id,
      keyword: keyword ?? this.keyword,
      description: description ?? this.description,
    );
  }
}

/// Keyword / description override for a built-in seed id.
class PlotElementOverride {
  const PlotElementOverride({
    required this.keyword,
    required this.description,
  });

  final String keyword;
  final String description;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'keyword': keyword,
        'description': description,
      };

  factory PlotElementOverride.fromJson(Map<String, dynamic> json) {
    return PlotElementOverride(
      keyword: json.requireString('keyword').trim(),
      description: json.requireString('description').trim(),
    );
  }
}

/// Per-story selection of global plot-element ids.
class PlotElementSelection {
  const PlotElementSelection({this.selectedIds = const <String>[]});

  final List<String> selectedIds;

  bool get isEmpty => selectedIds.isEmpty;

  int get count => selectedIds.length;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'selectedIds': selectedIds,
      };

  factory PlotElementSelection.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PlotElementSelection();
    return PlotElementSelection(
      selectedIds: json.stringList('selectedIds', required: false),
    );
  }

  PlotElementSelection copyWith({List<String>? selectedIds}) {
    return PlotElementSelection(
      selectedIds: selectedIds ?? this.selectedIds,
    );
  }

  PlotElementSelection withToggle(String id, {required bool selected}) {
    final next = selectedIds.toList(growable: true);
    if (selected) {
      if (!next.contains(id)) next.add(id);
    } else {
      next.remove(id);
    }
    return PlotElementSelection(selectedIds: List.unmodifiable(next));
  }
}
