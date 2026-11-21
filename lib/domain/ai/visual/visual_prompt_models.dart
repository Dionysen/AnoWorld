import 'package:anoworld/domain/models/json_map.dart';
import 'package:anoworld/domain/models/main_story.dart';

/// Story-wide visual lock produced by the prompt stage (editable before gen).
class VisualPromptPlan {
  const VisualPromptPlan({
    required this.stylePrefix,
    required this.negativePrompt,
    required this.characters,
    required this.scenes,
  });

  final String stylePrefix;
  final String negativePrompt;
  final List<CharacterVisualPrompt> characters;
  final List<SceneVisualPrompt> scenes;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'stylePrefix': stylePrefix,
        'negativePrompt': negativePrompt,
        'characters':
            characters.map((c) => c.toJson()).toList(growable: false),
        'scenes': scenes.map((s) => s.toJson()).toList(growable: false),
      };

  factory VisualPromptPlan.fromJson(Map<String, dynamic> json) {
    return VisualPromptPlan(
      stylePrefix: json.optionalString('stylePrefix') ?? '',
      negativePrompt: json.optionalString('negativePrompt') ?? '',
      characters: json
          .optionalList('characters')
          .whereType<Map>()
          .map(
            (item) => CharacterVisualPrompt.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false),
      scenes: json
          .optionalList('scenes')
          .whereType<Map>()
          .map(
            (item) =>
                SceneVisualPrompt.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
    );
  }

  VisualPromptPlan copyWith({
    String? stylePrefix,
    String? negativePrompt,
    List<CharacterVisualPrompt>? characters,
    List<SceneVisualPrompt>? scenes,
  }) {
    return VisualPromptPlan(
      stylePrefix: stylePrefix ?? this.stylePrefix,
      negativePrompt: negativePrompt ?? this.negativePrompt,
      characters: characters ?? this.characters,
      scenes: scenes ?? this.scenes,
    );
  }
}

class CharacterVisualPrompt {
  const CharacterVisualPrompt({
    required this.characterId,
    required this.name,
    required this.visualTags,
    required this.portraitPrompt,
    this.facing = SpriteFacing.right,
  });

  final String characterId;
  final String name;

  /// Stable appearance lock (no clothing scene action).
  final String visualTags;

  /// Full positive prompt for standing portrait / avatar.
  final String portraitPrompt;

  /// Look direction baked into the portrait; stage uses the opposite slot.
  final SpriteFacing facing;

  AppearanceSlot get preferredSlot => facing.preferredSlot;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'characterId': characterId,
        'name': name,
        'visualTags': visualTags,
        'portraitPrompt': portraitPrompt,
        'facing': facing.wireName,
        'preferredSlot': preferredSlot.wireName,
      };

  factory CharacterVisualPrompt.fromJson(Map<String, dynamic> json) {
    final facing = SpriteFacingCodec.parseOr(
      json.optionalString('facing'),
      SpriteFacing.right,
    );
    return CharacterVisualPrompt(
      characterId: json.requireString('characterId'),
      name: json.optionalString('name') ?? '',
      visualTags: json.optionalString('visualTags') ?? '',
      portraitPrompt: json.optionalString('portraitPrompt') ?? '',
      facing: facing,
    );
  }

  CharacterVisualPrompt copyWith({
    String? visualTags,
    String? portraitPrompt,
    SpriteFacing? facing,
  }) {
    return CharacterVisualPrompt(
      characterId: characterId,
      name: name,
      visualTags: visualTags ?? this.visualTags,
      portraitPrompt: portraitPrompt ?? this.portraitPrompt,
      facing: facing ?? this.facing,
    );
  }
}

class SceneVisualPrompt {
  const SceneVisualPrompt({
    required this.nodeId,
    required this.title,
    required this.scenePrompt,
    this.presentCharacterIds = const <String>[],
  });

  final String nodeId;
  final String title;
  final String scenePrompt;
  final List<String> presentCharacterIds;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'nodeId': nodeId,
        'title': title,
        'scenePrompt': scenePrompt,
        'presentCharacterIds': presentCharacterIds,
      };

  factory SceneVisualPrompt.fromJson(Map<String, dynamic> json) {
    return SceneVisualPrompt(
      nodeId: json.requireString('nodeId'),
      title: json.optionalString('title') ?? '',
      scenePrompt: json.optionalString('scenePrompt') ?? '',
      presentCharacterIds:
          json.stringList('presentCharacterIds', required: false),
    );
  }

  SceneVisualPrompt copyWith({
    String? scenePrompt,
    List<String>? presentCharacterIds,
  }) {
    return SceneVisualPrompt(
      nodeId: nodeId,
      title: title,
      scenePrompt: scenePrompt ?? this.scenePrompt,
      presentCharacterIds:
          presentCharacterIds ?? this.presentCharacterIds,
    );
  }
}
