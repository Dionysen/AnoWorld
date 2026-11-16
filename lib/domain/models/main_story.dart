import 'package:anoworld/domain/models/json_map.dart';

/// Main line graph: nodes, edges, and the shared Beat pool.
/// Field names follow docs/MainBeat.md.
class MainStory {
  const MainStory({
    required this.summary,
    required this.startNodeId,
    required this.nodes,
    required this.edges,
    required this.beats,
  });

  final String summary;
  final String startNodeId;
  final List<StoryNode> nodes;
  final List<StoryEdge> edges;
  final List<Beat> beats;

  StoryNode? nodeById(String id) {
    for (final node in nodes) {
      if (node.id == id) return node;
    }
    return null;
  }

  Beat? beatById(String id) {
    for (final beat in beats) {
      if (beat.id == id) return beat;
    }
    return null;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'summary': summary,
        'startNodeId': startNodeId,
        'nodes': nodes.map((n) => n.toJson()).toList(growable: false),
        'edges': edges.map((e) => e.toJson()).toList(growable: false),
        'beats': beats.map((b) => b.toJson()).toList(growable: false),
      };

  factory MainStory.fromJson(Map<String, dynamic> json) {
    return MainStory(
      summary: json.requireString('summary'),
      startNodeId: json.requireString('startNodeId'),
      nodes: json
          .requireList('nodes')
          .map((item) => StoryNode.fromJson(asJsonMap(item, path: 'nodes[]')))
          .toList(growable: false),
      edges: json
          .requireList('edges')
          .map((item) => StoryEdge.fromJson(asJsonMap(item, path: 'edges[]')))
          .toList(growable: false),
      beats: json
          .requireList('beats')
          .map((item) => Beat.fromJson(asJsonMap(item, path: 'beats[]')))
          .toList(growable: false),
    );
  }

  MainStory copyWith({
    String? summary,
    String? startNodeId,
    List<StoryNode>? nodes,
    List<StoryEdge>? edges,
    List<Beat>? beats,
  }) {
    return MainStory(
      summary: summary ?? this.summary,
      startNodeId: startNodeId ?? this.startNodeId,
      nodes: nodes ?? this.nodes,
      edges: edges ?? this.edges,
      beats: beats ?? this.beats,
    );
  }
}

class StoryNode {
  const StoryNode({
    required this.id,
    required this.title,
    required this.beatIds,
    this.synopsis,
    this.layout,
    this.tags = const <String>[],
  });

  final String id;
  final String title;
  final String? synopsis;
  final List<String> beatIds;
  final NodeLayout? layout;
  final List<String> tags;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        if (synopsis != null) 'synopsis': synopsis,
        'beatIds': beatIds,
        if (layout != null) 'layout': layout!.toJson(),
        if (tags.isNotEmpty) 'tags': tags,
      };

  factory StoryNode.fromJson(Map<String, dynamic> json) {
    return StoryNode(
      id: json.requireString('id'),
      title: json.requireString('title'),
      synopsis: json.optionalString('synopsis'),
      beatIds: json.stringList('beatIds'),
      layout: json.optionalMap('layout') == null
          ? null
          : NodeLayout.fromJson(json.requireMap('layout')),
      tags: json.stringList('tags', required: false),
    );
  }
}

class NodeLayout {
  const NodeLayout({required this.x, required this.y});

  final double x;
  final double y;

  Map<String, dynamic> toJson() => <String, dynamic>{'x': x, 'y': y};

  factory NodeLayout.fromJson(Map<String, dynamic> json) {
    return NodeLayout(
      x: (json.optionalNum('x') ?? 0).toDouble(),
      y: (json.optionalNum('y') ?? 0).toDouble(),
    );
  }
}

enum EdgeKind { defaultEdge, branch }

extension EdgeKindCodec on EdgeKind {
  String get wireName => switch (this) {
        EdgeKind.defaultEdge => 'default',
        EdgeKind.branch => 'branch',
      };

  static EdgeKind parse(String raw) {
    return switch (raw) {
      'default' => EdgeKind.defaultEdge,
      'branch' => EdgeKind.branch,
      _ => throw FormatException('Unknown edge kind "$raw"'),
    };
  }
}

class StoryEdge {
  const StoryEdge({
    required this.id,
    required this.from,
    required this.to,
    required this.kind,
    this.label,
    this.detail,
    this.priority = 0,
  });

  final String id;
  final String from;
  final String to;
  final EdgeKind kind;

  /// Short title on the canvas port button.
  final String? label;

  /// Longer notes for authors / AI (choice motive, what happens on this path).
  final String? detail;
  final int priority;

  StoryEdge copyWith({
    String? id,
    String? from,
    String? to,
    EdgeKind? kind,
    String? label,
    String? detail,
    int? priority,
    bool clearLabel = false,
    bool clearDetail = false,
  }) {
    return StoryEdge(
      id: id ?? this.id,
      from: from ?? this.from,
      to: to ?? this.to,
      kind: kind ?? this.kind,
      label: clearLabel ? null : (label ?? this.label),
      detail: clearDetail ? null : (detail ?? this.detail),
      priority: priority ?? this.priority,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'from': from,
        'to': to,
        'kind': kind.wireName,
        if (label != null) 'label': label,
        if (detail != null) 'detail': detail,
        if (priority != 0) 'priority': priority,
      };

  factory StoryEdge.fromJson(Map<String, dynamic> json) {
    return StoryEdge(
      id: json.requireString('id'),
      from: json.requireString('from'),
      to: json.requireString('to'),
      kind: EdgeKindCodec.parse(json.requireString('kind')),
      label: json.optionalString('label'),
      detail: json.optionalString('detail'),
      priority: (json.optionalNum('priority') ?? 0).toInt(),
    );
  }
}

class Beat {
  const Beat({
    required this.id,
    required this.nodeId,
    required this.scene,
    required this.appearances,
    required this.lines,
    required this.choices,
    this.note,
    this.tags = const <String>[],
  });

  final String id;
  final String nodeId;
  final Scene scene;
  final List<Appearance> appearances;
  final List<DialogueLine> lines;
  final List<Choice> choices;
  final String? note;
  final List<String> tags;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'nodeId': nodeId,
        'scene': scene.toJson(),
        'appearances':
            appearances.map((a) => a.toJson()).toList(growable: false),
        'lines': lines.map((l) => l.toJson()).toList(growable: false),
        'choices': choices.map((c) => c.toJson()).toList(growable: false),
        if (note != null) 'note': note,
        if (tags.isNotEmpty) 'tags': tags,
      };

  factory Beat.fromJson(Map<String, dynamic> json) {
    return Beat(
      id: json.requireString('id'),
      nodeId: json.requireString('nodeId'),
      scene: Scene.fromJson(json.requireMap('scene')),
      appearances: json
          .requireList('appearances')
          .map(
            (item) =>
                Appearance.fromJson(asJsonMap(item, path: 'appearances[]')),
          )
          .toList(growable: false),
      lines: json
          .requireList('lines')
          .map(
            (item) =>
                DialogueLine.fromJson(asJsonMap(item, path: 'lines[]')),
          )
          .toList(growable: false),
      choices: json
          .requireList('choices')
          .map((item) => Choice.fromJson(asJsonMap(item, path: 'choices[]')))
          .toList(growable: false),
      note: json.optionalString('note'),
      tags: json.stringList('tags', required: false),
    );
  }
}

class Scene {
  const Scene({this.locationText, this.backgroundAssetId});

  final String? locationText;
  final String? backgroundAssetId;

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (locationText != null) 'locationText': locationText,
        if (backgroundAssetId != null) 'backgroundAssetId': backgroundAssetId,
      };

  factory Scene.fromJson(Map<String, dynamic> json) {
    return Scene(
      locationText: json.optionalString('locationText'),
      backgroundAssetId: json.optionalString('backgroundAssetId'),
    );
  }
}

enum AppearanceSlot { left, center, right }

extension AppearanceSlotCodec on AppearanceSlot {
  String get wireName => name;

  static AppearanceSlot? tryParse(String? raw) {
    if (raw == null) return null;
    return switch (raw) {
      'left' => AppearanceSlot.left,
      'center' => AppearanceSlot.center,
      'right' => AppearanceSlot.right,
      _ => throw FormatException('Unknown appearance slot "$raw"'),
    };
  }
}

class Appearance {
  const Appearance({
    required this.characterId,
    this.spriteAssetId,
    this.expression,
    this.slot,
  });

  final String characterId;
  final String? spriteAssetId;
  final String? expression;
  final AppearanceSlot? slot;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'characterId': characterId,
        if (spriteAssetId != null) 'spriteAssetId': spriteAssetId,
        if (expression != null) 'expression': expression,
        if (slot != null) 'slot': slot!.wireName,
      };

  factory Appearance.fromJson(Map<String, dynamic> json) {
    return Appearance(
      characterId: json.requireString('characterId'),
      spriteAssetId: json.optionalString('spriteAssetId'),
      expression: json.optionalString('expression'),
      slot: AppearanceSlotCodec.tryParse(json.optionalString('slot')),
    );
  }
}

enum DialogueKind { speech, narration }

extension DialogueKindCodec on DialogueKind {
  String get wireName => name;

  static DialogueKind parse(String? raw) {
    if (raw == null || raw.isEmpty) return DialogueKind.speech;
    return switch (raw) {
      'speech' => DialogueKind.speech,
      'narration' => DialogueKind.narration,
      _ => throw FormatException('Unknown dialogue kind "$raw"'),
    };
  }
}

class DialogueLine {
  const DialogueLine({
    required this.id,
    required this.text,
    this.speakerId,
    this.kind = DialogueKind.speech,
  });

  final String id;
  final String? speakerId;
  final String text;
  final DialogueKind kind;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        if (speakerId != null) 'speakerId': speakerId,
        'text': text,
        'kind': kind.wireName,
      };

  factory DialogueLine.fromJson(Map<String, dynamic> json) {
    return DialogueLine(
      id: json.requireString('id'),
      speakerId: json.optionalString('speakerId'),
      text: json.requireString('text'),
      kind: DialogueKindCodec.parse(json.optionalString('kind')),
    );
  }
}

class Choice {
  const Choice({
    required this.id,
    required this.text,
    required this.target,
  });

  final String id;
  final String text;
  final Transition target;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'text': text,
        'target': target.toJson(),
      };

  factory Choice.fromJson(Map<String, dynamic> json) {
    return Choice(
      id: json.requireString('id'),
      text: json.requireString('text'),
      target: Transition.fromJson(json.requireMap('target')),
    );
  }
}

enum TransitionType { beat, node, end }

extension TransitionTypeCodec on TransitionType {
  String get wireName => name;

  static TransitionType parse(String raw) {
    return switch (raw) {
      'beat' => TransitionType.beat,
      'node' => TransitionType.node,
      'end' => TransitionType.end,
      _ => throw FormatException('Unknown transition type "$raw"'),
    };
  }
}

class Transition {
  const Transition({
    required this.type,
    this.beatId,
    this.nodeId,
  });

  final TransitionType type;
  final String? beatId;
  final String? nodeId;

  factory Transition.toBeat(String beatId) =>
      Transition(type: TransitionType.beat, beatId: beatId);

  factory Transition.toNode(String nodeId) =>
      Transition(type: TransitionType.node, nodeId: nodeId);

  factory Transition.end() => const Transition(type: TransitionType.end);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type.wireName,
        if (beatId != null) 'beatId': beatId,
        if (nodeId != null) 'nodeId': nodeId,
      };

  factory Transition.fromJson(Map<String, dynamic> json) {
    final type = TransitionTypeCodec.parse(json.requireString('type'));
    return Transition(
      type: type,
      beatId: json.optionalString('beatId'),
      nodeId: json.optionalString('nodeId'),
    );
  }
}

/// Runtime / save pointer into Main (docs/MainBeat.md §5).
class MainSavePointer {
  const MainSavePointer({required this.nodeId, required this.beatId});

  final String nodeId;
  final String beatId;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'nodeId': nodeId,
        'beatId': beatId,
      };

  factory MainSavePointer.fromJson(Map<String, dynamic> json) {
    return MainSavePointer(
      nodeId: json.requireString('nodeId'),
      beatId: json.requireString('beatId'),
    );
  }
}
