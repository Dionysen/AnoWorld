import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/json_map.dart';

enum PlayPhase {
  /// Showing dialogue lines for the current beat.
  lines,

  /// All lines shown; waiting for a choice.
  choices,

  /// Current node needs a bridge AI beat (empty or continue interval).
  needsBridge,

  /// Main reached an end transition.
  ended,
}

/// Runtime cursor into Main. [lineIndex] is UI-only; saves use [toSave].
class PlayPointer {
  const PlayPointer({
    required this.nodeId,
    required this.beatId,
    required this.lineIndex,
    required this.phase,
  });

  final String nodeId;
  final String beatId;

  /// Index of the currently visible line in VN; in chat, lines `0..lineIndex`
  /// are revealed. `-1` when the beat has no lines yet / empty beat.
  final int lineIndex;
  final PlayPhase phase;

  bool get isEnded => phase == PlayPhase.ended;

  MainSavePointer toSave() => MainSavePointer(nodeId: nodeId, beatId: beatId);

  PlayPointer copyWith({
    String? nodeId,
    String? beatId,
    int? lineIndex,
    PlayPhase? phase,
  }) {
    return PlayPointer(
      nodeId: nodeId ?? this.nodeId,
      beatId: beatId ?? this.beatId,
      lineIndex: lineIndex ?? this.lineIndex,
      phase: phase ?? this.phase,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'nodeId': nodeId,
        'beatId': beatId,
        'lineIndex': lineIndex,
        'phase': phase.name,
      };

  factory PlayPointer.fromJson(Map<String, dynamic> json) {
    final phaseRaw = json.optionalString('phase') ?? PlayPhase.lines.name;
    final phase = PlayPhase.values.firstWhere(
      (p) => p.name == phaseRaw,
      orElse: () => PlayPhase.lines,
    );
    return PlayPointer(
      nodeId: json.requireString('nodeId'),
      beatId: json.requireString('beatId'),
      lineIndex: (json.optionalNum('lineIndex') ?? 0).toInt(),
      phase: phase,
    );
  }
}
