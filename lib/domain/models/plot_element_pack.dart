import 'package:anoworld/domain/models/json_map.dart';

/// A named bundle of library element ids that can be applied in one tap.
///
/// Packs only reference element ids; the keyword and description still live in
/// the global library, so editing an element updates every pack that uses it.
class PlotElementPack {
  const PlotElementPack({
    required this.id,
    required this.name,
    this.elementIds = const <String>[],
  });

  final String id;
  final String name;

  /// Referenced [PlotElement] ids; ids of deleted elements are skipped.
  final List<String> elementIds;

  int get count => elementIds.length;

  bool contains(String elementId) => elementIds.contains(elementId);

  PlotElementPack copyWith({
    String? id,
    String? name,
    List<String>? elementIds,
  }) {
    return PlotElementPack(
      id: id ?? this.id,
      name: name ?? this.name,
      elementIds: elementIds ?? this.elementIds,
    );
  }

  PlotElementPack withToggle(String elementId, {required bool selected}) {
    final next = elementIds.toList(growable: true);
    if (selected) {
      if (!next.contains(elementId)) next.add(elementId);
    } else {
      next.remove(elementId);
    }
    return copyWith(elementIds: List.unmodifiable(next));
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'elementIds': elementIds,
  };

  factory PlotElementPack.fromJson(Map<String, dynamic> json) {
    return PlotElementPack(
      id: json.requireString('id'),
      name: json.requireString('name').trim(),
      elementIds: List.unmodifiable(
        json.stringList('elementIds', required: false),
      ),
    );
  }
}
