import 'package:anoworld/domain/models/json_map.dart';
import 'package:anoworld/domain/models/main_story.dart';

/// One decision in the play lineage: choosing [choiceId] on [fromBeatId]
/// leads to [toBeatId].
class BridgeBranchEdge {
  const BridgeBranchEdge({
    required this.fromBeatId,
    required this.choiceId,
    required this.toBeatId,
  });

  final String fromBeatId;
  final String choiceId;
  final String toBeatId;

  BridgeBranchEdge copyWith({
    String? fromBeatId,
    String? choiceId,
    String? toBeatId,
  }) {
    return BridgeBranchEdge(
      fromBeatId: fromBeatId ?? this.fromBeatId,
      choiceId: choiceId ?? this.choiceId,
      toBeatId: toBeatId ?? this.toBeatId,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'fromBeatId': fromBeatId,
        'choiceId': choiceId,
        'toBeatId': toBeatId,
      };

  factory BridgeBranchEdge.fromJson(Map<String, dynamic> json) {
    return BridgeBranchEdge(
      fromBeatId: json.requireString('fromBeatId'),
      choiceId: json.requireString('choiceId'),
      toBeatId: json.requireString('toBeatId'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BridgeBranchEdge &&
      other.fromBeatId == fromBeatId &&
      other.choiceId == choiceId &&
      other.toBeatId == toBeatId;

  @override
  int get hashCode => Object.hash(fromBeatId, choiceId, toBeatId);
}

/// In-play AI interval (not written into the project pack).
///
/// [generatedBeats] keeps **all** beats produced this session (across nodes
/// and branches) so VN history and alternate paths stay available.
/// [branchEdges] records the story tree: choice → next beat.
/// [nodeId] / [turnCount] / [summary] describe the **current** open interval.
class BridgeSession {
  const BridgeSession({
    required this.nodeId,
    this.generatedBeats = const <Beat>[],
    this.branchEdges = const <BridgeBranchEdge>[],
    this.turnCount = 0,
    this.summary = '',
  });

  final String nodeId;
  final List<Beat> generatedBeats;
  final List<BridgeBranchEdge> branchEdges;
  final int turnCount;
  final String summary;

  static const int defaultMaxBeats = 4;

  /// Hard cap on choices per AI-generated beat / branch fan-out.
  static const int maxChoicesPerBeat = 3;

  /// Beats already generated for [nodeId] (used when entering a station).
  int turnsForNode(String id) =>
      generatedBeats.where((b) => b.nodeId == id).length;

  Beat? beatById(String id) {
    for (final beat in generatedBeats) {
      if (beat.id == id) return beat;
    }
    return null;
  }

  /// Next beat after choosing [choiceId] on [fromBeatId], if already grown.
  String? toBeatId(String fromBeatId, String choiceId) {
    for (final edge in branchEdges) {
      if (edge.fromBeatId == fromBeatId && edge.choiceId == choiceId) {
        return edge.toBeatId;
      }
    }
    return null;
  }

  /// [rootBeatId] plus every beat reachable via [branchEdges].
  Set<String> subtreeBeatIds(String rootBeatId) {
    final ids = <String>{rootBeatId};
    var grew = true;
    while (grew) {
      grew = false;
      for (final edge in branchEdges) {
        if (ids.contains(edge.fromBeatId) && ids.add(edge.toBeatId)) {
          grew = true;
        }
      }
    }
    return ids;
  }

  /// Drop [rootBeatId] and its descendants from the beat library and edges.
  /// Sibling branches from ancestors are kept.
  BridgeSession pruneSubtree(String rootBeatId) {
    final drop = subtreeBeatIds(rootBeatId);
    return copyWith(
      generatedBeats: generatedBeats
          .where((b) => !drop.contains(b.id))
          .toList(growable: false),
      branchEdges: branchEdges
          .where(
            (e) => !drop.contains(e.fromBeatId) && !drop.contains(e.toBeatId),
          )
          .toList(growable: false),
    );
  }

  /// Upsert [beat] into the library (replace same id).
  BridgeSession withBeat(Beat beat) {
    final others =
        generatedBeats.where((b) => b.id != beat.id).toList(growable: true);
    others.add(beat);
    return copyWith(generatedBeats: List<Beat>.unmodifiable(others));
  }

  /// Add or replace the edge for [fromBeatId] + [choiceId].
  BridgeSession withBranchEdge({
    required String fromBeatId,
    required String choiceId,
    required String toBeatId,
  }) {
    final edge = BridgeBranchEdge(
      fromBeatId: fromBeatId,
      choiceId: choiceId,
      toBeatId: toBeatId,
    );
    final others = branchEdges
        .where(
          (e) => !(e.fromBeatId == fromBeatId && e.choiceId == choiceId),
        )
        .toList(growable: true);
    others.add(edge);
    return copyWith(branchEdges: List<BridgeBranchEdge>.unmodifiable(others));
  }

  BridgeSession copyWith({
    String? nodeId,
    List<Beat>? generatedBeats,
    List<BridgeBranchEdge>? branchEdges,
    int? turnCount,
    String? summary,
  }) {
    return BridgeSession(
      nodeId: nodeId ?? this.nodeId,
      generatedBeats: generatedBeats ?? this.generatedBeats,
      branchEdges: branchEdges ?? this.branchEdges,
      turnCount: turnCount ?? this.turnCount,
      summary: summary ?? this.summary,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'nodeId': nodeId,
        'turnCount': turnCount,
        'summary': summary,
        'generatedBeats':
            generatedBeats.map((b) => b.toJson()).toList(growable: false),
        if (branchEdges.isNotEmpty)
          'branchEdges':
              branchEdges.map((e) => e.toJson()).toList(growable: false),
      };

  factory BridgeSession.fromJson(Map<String, dynamic> json) {
    return BridgeSession(
      nodeId: json.requireString('nodeId'),
      turnCount: (json.optionalNum('turnCount') ?? 0).toInt(),
      summary: json.optionalString('summary') ?? '',
      generatedBeats: json
          .optionalList('generatedBeats')
          .map(
            (item) =>
                Beat.fromJson(asJsonMap(item, path: 'generatedBeats[]')),
          )
          .toList(growable: false),
      branchEdges: json
          .optionalList('branchEdges')
          .map(
            (item) => BridgeBranchEdge.fromJson(
              asJsonMap(item, path: 'branchEdges[]'),
            ),
          )
          .toList(growable: false),
    );
  }
}
