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

/// What switching a pack on would change in a story selection.
///
/// Packs are not mutually exclusive: applying one only adds its own ids, and
/// the already-selected ones stay. The lists below exist so the UI can say
/// exactly what will be affected before touching anything.
class PackApplyPlan {
  const PackApplyPlan({
    required this.addedIds,
    required this.manualSharedIds,
    required this.overlappedIds,
    required this.overlapNames,
  });

  /// Ids that will be newly selected.
  final List<String> addedIds;

  /// Ids already selected without any applied pack covering them, i.e. the
  /// user picked them one by one. Un-applying the pack later will clear them.
  final List<String> manualSharedIds;

  /// Ids already selected because other applied packs contain them.
  final List<String> overlappedIds;

  /// Names of those other applied packs, in first-seen order.
  final List<String> overlapNames;

  bool get isEmpty =>
      addedIds.isEmpty && manualSharedIds.isEmpty && overlappedIds.isEmpty;

  /// True when applying would silently change something the user set before.
  bool get needsConfirm =>
      manualSharedIds.isNotEmpty || overlappedIds.isNotEmpty;
}

/// What switching a pack off would change in a story selection.
class PackRemovePlan {
  const PackRemovePlan({
    required this.removedIds,
    required this.keptIds,
    required this.keptByNames,
  });

  /// Ids that will be deselected.
  final List<String> removedIds;

  /// Ids still covered by another applied pack, so they stay selected.
  final List<String> keptIds;

  /// Names of the packs keeping those ids, in first-seen order.
  final List<String> keptByNames;

  bool get needsConfirm => keptIds.isNotEmpty;
}

