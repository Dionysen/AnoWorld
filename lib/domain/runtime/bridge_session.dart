import 'package:anoworld/domain/models/json_map.dart';
import 'package:anoworld/domain/models/main_story.dart';

/// In-play AI interval (not written into the project pack).
///
/// [generatedBeats] keeps **all** beats produced this session (across nodes)
/// so VN history can later support rollback. [nodeId] / [turnCount] /
/// [summary] describe the **current** open interval only.
class BridgeSession {
  const BridgeSession({
    required this.nodeId,
    this.generatedBeats = const <Beat>[],
    this.turnCount = 0,
    this.summary = '',
  });

  final String nodeId;
  final List<Beat> generatedBeats;
  final int turnCount;
  final String summary;

  static const int defaultMaxBeats = 4;

  /// Beats already generated for [nodeId] (used when entering a station).
  int turnsForNode(String id) =>
      generatedBeats.where((b) => b.nodeId == id).length;

  BridgeSession copyWith({
    String? nodeId,
    List<Beat>? generatedBeats,
    int? turnCount,
    String? summary,
  }) {
    return BridgeSession(
      nodeId: nodeId ?? this.nodeId,
      generatedBeats: generatedBeats ?? this.generatedBeats,
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
    );
  }
}
