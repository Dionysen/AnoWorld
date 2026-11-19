import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/runtime/play_pointer.dart';

/// Shared Main advancement for VN and chat (docs/MainBeat.md §3).
class MainRuntime {
  MainRuntime(MainStory main, {MainSavePointer? save})
      : main = main,
        pointer = _initialPointer(main, save);

  MainStory main;
  PlayPointer pointer;

  static PlayPointer _initialPointer(MainStory main, MainSavePointer? save) {
    if (save != null) {
      final node = main.nodeById(save.nodeId);
      if (node != null) {
        if (save.beatId.isNotEmpty) {
          final beat = main.beatById(save.beatId);
          if (beat != null && beat.nodeId == node.id) {
            return _restoreBeat(
              main,
              nodeId: node.id,
              beatId: beat.id,
              lineIndex: save.lineIndex,
              phaseName: save.phase,
            );
          }
        }
        return enterNode(main, node.id);
      }
    }
    return enterStart(main);
  }

  /// Resume a beat, honoring saved [lineIndex] / phase when present.
  static PlayPointer _restoreBeat(
    MainStory main, {
    required String nodeId,
    required String beatId,
    int? lineIndex,
    String? phaseName,
  }) {
    final entered = _enterBeat(main, nodeId: nodeId, beatId: beatId);
    final beat = main.beatById(beatId);
    if (beat == null || lineIndex == null && phaseName == null) {
      return entered;
    }

    PlayPhase? phase;
    if (phaseName != null) {
      for (final value in PlayPhase.values) {
        if (value.name == phaseName) {
          phase = value;
          break;
        }
      }
    }

    if (phase == PlayPhase.choices && beat.choices.isNotEmpty) {
      final last = beat.lines.isEmpty ? -1 : beat.lines.length - 1;
      return PlayPointer(
        nodeId: nodeId,
        beatId: beatId,
        lineIndex: lineIndex ?? last,
        phase: PlayPhase.choices,
      );
    }
    if (phase == PlayPhase.needsBridge || phase == PlayPhase.ended) {
      return PlayPointer(
        nodeId: nodeId,
        beatId: beatId,
        lineIndex: lineIndex ?? entered.lineIndex,
        phase: phase!,
      );
    }

    if (beat.lines.isEmpty) return entered;
    final clamped = (lineIndex ?? 0).clamp(0, beat.lines.length - 1);
    return PlayPointer(
      nodeId: nodeId,
      beatId: beatId,
      lineIndex: clamped,
      phase: PlayPhase.lines,
    );
  }

  static PlayPointer enterStart(MainStory main) {
    return enterNode(main, main.startNodeId);
  }

  static PlayPointer enterNode(MainStory main, String nodeId) {
    final node = main.nodeById(nodeId);
    if (node == null) {
      return PlayPointer(
        nodeId: nodeId,
        beatId: '',
        lineIndex: -1,
        phase: PlayPhase.ended,
      );
    }
    if (node.tags.contains('ending') && node.beatIds.isEmpty) {
      return PlayPointer(
        nodeId: node.id,
        beatId: '',
        lineIndex: -1,
        phase: PlayPhase.ended,
      );
    }
    if (node.beatIds.isEmpty) {
      return PlayPointer(
        nodeId: node.id,
        beatId: '',
        lineIndex: -1,
        phase: PlayPhase.needsBridge,
      );
    }
    return _enterBeat(main, nodeId: node.id, beatId: node.beatIds.first);
  }

  static PlayPointer _enterBeat(
    MainStory main, {
    required String nodeId,
    required String beatId,
  }) {
    final beat = main.beatById(beatId);
    if (beat == null) {
      return PlayPointer(
        nodeId: nodeId,
        beatId: beatId,
        lineIndex: -1,
        phase: PlayPhase.needsBridge,
      );
    }
    if (beat.lines.isEmpty) {
      if (beat.choices.isNotEmpty) {
        return PlayPointer(
          nodeId: beat.nodeId,
          beatId: beat.id,
          lineIndex: -1,
          phase: PlayPhase.choices,
        );
      }
      final runtime = MainRuntime._withPointer(
        main,
        PlayPointer(
          nodeId: beat.nodeId,
          beatId: beat.id,
          lineIndex: -1,
          phase: PlayPhase.lines,
        ),
      );
      runtime._finishBeat();
      return runtime.pointer;
    }
    return PlayPointer(
      nodeId: beat.nodeId,
      beatId: beat.id,
      lineIndex: 0,
      phase: PlayPhase.lines,
    );
  }

  MainRuntime._withPointer(this.main, this.pointer);

  Beat? get currentBeat =>
      pointer.beatId.isEmpty ? null : main.beatById(pointer.beatId);

  StoryNode? get currentNode => main.nodeById(pointer.nodeId);

  DialogueLine? get currentLine {
    final beat = currentBeat;
    if (beat == null) return null;
    if (pointer.lineIndex < 0 || pointer.lineIndex >= beat.lines.length) {
      return null;
    }
    return beat.lines[pointer.lineIndex];
  }

  List<DialogueLine> get revealedLines {
    final beat = currentBeat;
    if (beat == null || pointer.lineIndex < 0) return const [];
    final end = (pointer.lineIndex + 1).clamp(0, beat.lines.length);
    return beat.lines.sublist(0, end);
  }

  List<Choice> get visibleChoices =>
      pointer.phase == PlayPhase.choices
          ? (currentBeat?.choices ?? const <Choice>[])
          : const <Choice>[];

  bool get canAdvance =>
      pointer.phase == PlayPhase.lines && !pointer.isEnded;

  bool get needsBridge => pointer.phase == PlayPhase.needsBridge;

  List<StoryEdge> outboundFromCurrent() {
    final node = currentNode;
    if (node == null) return const [];
    return main.edges
        .where((e) => e.from == node.id)
        .toList(growable: false);
  }

  String? get resolvedBackgroundAssetId {
    final node = currentNode;
    final beat = currentBeat;
    if (node == null || beat == null) return null;
    final direct = beat.scene.backgroundAssetId;
    if (direct != null && direct.isNotEmpty) return direct;
    final index = node.beatIds.indexOf(beat.id);
    for (var i = index - 1; i >= 0; i--) {
      final prev = main.beatById(node.beatIds[i]);
      final bg = prev?.scene.backgroundAssetId;
      if (bg != null && bg.isNotEmpty) return bg;
    }
    return null;
  }

  String? get locationText => currentBeat?.scene.locationText;

  List<Appearance> get appearances =>
      currentBeat?.appearances ?? const <Appearance>[];

  /// Adds a generated beat into the working main and enters it.
  void adoptBridgeBeat(Beat beat) {
    final node = main.nodeById(beat.nodeId);
    if (node == null) return;
    final beats = [...main.beats.where((b) => b.id != beat.id), beat];
    final beatIds = [...node.beatIds.where((id) => id != beat.id), beat.id];
    final nodes = main.nodes
        .map(
          (n) => n.id == node.id
              ? StoryNode(
                  id: n.id,
                  title: n.title,
                  synopsis: n.synopsis,
                  beatIds: beatIds,
                  layout: n.layout,
                  tags: n.tags,
                )
              : n,
        )
        .toList(growable: false);
    main = MainStory(
      summary: main.summary,
      startNodeId: main.startNodeId,
      nodes: nodes,
      edges: main.edges,
      beats: beats,
    );
    pointer = _enterBeat(main, nodeId: beat.nodeId, beatId: beat.id);
  }

  void advance() {
    if (!canAdvance) return;
    final beat = currentBeat;
    if (beat == null) {
      pointer = pointer.copyWith(phase: PlayPhase.ended);
      return;
    }
    if (pointer.lineIndex < beat.lines.length - 1) {
      pointer = pointer.copyWith(lineIndex: pointer.lineIndex + 1);
      return;
    }
    _finishBeat();
  }

  void choose(String choiceId) {
    if (pointer.phase != PlayPhase.choices) return;
    final beat = currentBeat;
    if (beat == null) return;
    Choice? match;
    for (final choice in beat.choices) {
      if (choice.id == choiceId) {
        match = choice;
        break;
      }
    }
    if (match == null) return;
    _applyTransition(match.target);
  }

  void jumpToNode(String nodeId) {
    _applyTransition(Transition.toNode(nodeId));
  }

  void endStory() {
    pointer = pointer.copyWith(phase: PlayPhase.ended);
  }

  void requestBridge() {
    pointer = PlayPointer(
      nodeId: pointer.nodeId,
      beatId: pointer.beatId,
      lineIndex: -1,
      phase: PlayPhase.needsBridge,
    );
  }

  void _finishBeat() {
    final beat = currentBeat;
    final node = currentNode;
    if (beat == null || node == null) {
      pointer = pointer.copyWith(phase: PlayPhase.ended);
      return;
    }
    if (beat.choices.isNotEmpty) {
      pointer = pointer.copyWith(phase: PlayPhase.choices);
      return;
    }
    final beatIndex = node.beatIds.indexOf(beat.id);
    if (beatIndex >= 0 && beatIndex + 1 < node.beatIds.length) {
      final nextId = node.beatIds[beatIndex + 1];
      pointer = _enterBeat(main, nodeId: node.id, beatId: nextId);
      return;
    }
    final defaults = main.edges
        .where((e) => e.from == node.id && e.kind == EdgeKind.defaultEdge)
        .toList(growable: false)
      ..sort((a, b) => a.priority.compareTo(b.priority));
    if (defaults.isNotEmpty) {
      _applyTransition(Transition.toNode(defaults.first.to));
      return;
    }
    // No default edge: keep bridging (open interval or branch waiting).
    // Soft-end only via explicit end choice / ending-tagged node.
    pointer = pointer.copyWith(phase: PlayPhase.needsBridge);
  }

  void _applyTransition(Transition transition) {
    switch (transition.type) {
      case TransitionType.end:
        pointer = pointer.copyWith(phase: PlayPhase.ended);
      case TransitionType.beat:
        final beatId = transition.beatId;
        if (beatId == null) {
          pointer = pointer.copyWith(phase: PlayPhase.needsBridge);
          return;
        }
        final beat = main.beatById(beatId);
        if (beat == null) {
          // Bridge "stay" marker when beat was not persisted as a new id.
          pointer = pointer.copyWith(phase: PlayPhase.needsBridge);
          return;
        }
        pointer = _enterBeat(main, nodeId: beat.nodeId, beatId: beat.id);
      case TransitionType.node:
        final nodeId = transition.nodeId;
        if (nodeId == null) {
          pointer = pointer.copyWith(phase: PlayPhase.ended);
          return;
        }
        pointer = enterNode(main, nodeId);
    }
  }

  MainSavePointer toSave() => pointer.toSave();

  void restore(MainSavePointer save) {
    pointer = _initialPointer(main, save);
  }
}
