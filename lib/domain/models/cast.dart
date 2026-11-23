import 'package:anoworld/domain/models/json_map.dart';
import 'package:anoworld/domain/models/main_story.dart';

class CastMember {
  const CastMember({
    required this.id,
    required this.name,
    this.summary = '',
    this.personality = '',
    this.speechStyle = '',
    this.exampleLines = const <String>[],
    this.visualTags = '',
    this.portraitPrompt = '',
    this.avatarAssetId,
    this.facing = SpriteFacing.right,
    this.isProtagonist = false,
  });

  final String id;
  final String name;
  final String summary;
  final String personality;
  final String speechStyle;
  final List<String> exampleLines;

  /// Locked Danbooru-style appearance tags for image gen (face/hair/body).
  /// Kept stable across scenes so characters stay recognizable.
  final String visualTags;

  /// Full standing-portrait prompt kept from the visual stage. Empty falls
  /// back to a prompt rebuilt from [visualTags] + [facing].
  final String portraitPrompt;

  final String? avatarAssetId;

  /// Portrait look direction; stage slot is the opposite side (center-facing).
  final SpriteFacing facing;

  /// Drives {{char}} and ST char* prompt sections when this member is selected.
  final bool isProtagonist;

  /// Preferred VN stand when [Appearance.slot] is omitted.
  AppearanceSlot get preferredSlot => facing.preferredSlot;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'summary': summary,
        'personality': personality,
        'speechStyle': speechStyle,
        'exampleLines': exampleLines,
        if (visualTags.trim().isNotEmpty) 'visualTags': visualTags,
        if (portraitPrompt.trim().isNotEmpty) 'portraitPrompt': portraitPrompt,
        if (avatarAssetId != null) 'avatarAssetId': avatarAssetId,
        if (facing != SpriteFacing.right) 'facing': facing.wireName,
        if (isProtagonist) 'isProtagonist': true,
      };

  factory CastMember.fromJson(Map<String, dynamic> json) {
    return CastMember(
      id: json.requireString('id'),
      name: json.requireString('name'),
      summary: json.optionalString('summary') ?? '',
      personality: json.optionalString('personality') ?? '',
      speechStyle: json.optionalString('speechStyle') ?? '',
      exampleLines: json.stringList('exampleLines', required: false),
      visualTags: json.optionalString('visualTags') ?? '',
      portraitPrompt: json.optionalString('portraitPrompt') ?? '',
      avatarAssetId: json.optionalString('avatarAssetId'),
      facing: SpriteFacingCodec.parseOr(
        json.optionalString('facing'),
        SpriteFacing.right,
      ),
      isProtagonist: json.optionalBool('isProtagonist') ?? false,
    );
  }

  CastMember copyWith({
    String? id,
    String? name,
    String? summary,
    String? personality,
    String? speechStyle,
    List<String>? exampleLines,
    String? visualTags,
    String? portraitPrompt,
    String? avatarAssetId,
    bool clearAvatarAssetId = false,
    SpriteFacing? facing,
    bool? isProtagonist,
  }) {
    return CastMember(
      id: id ?? this.id,
      name: name ?? this.name,
      summary: summary ?? this.summary,
      personality: personality ?? this.personality,
      speechStyle: speechStyle ?? this.speechStyle,
      exampleLines: exampleLines ?? this.exampleLines,
      visualTags: visualTags ?? this.visualTags,
      portraitPrompt: portraitPrompt ?? this.portraitPrompt,
      avatarAssetId:
          clearAvatarAssetId ? null : (avatarAssetId ?? this.avatarAssetId),
      facing: facing ?? this.facing,
      isProtagonist: isProtagonist ?? this.isProtagonist,
    );
  }
}

/// At most one protagonist; used for macro / prompt assembly focus.
List<CastMember> castWithProtagonist(
  List<CastMember> cast, {
  required String memberId,
  required bool isProtagonist,
}) {
  if (!isProtagonist) {
    return cast
        .map(
          (c) => c.id == memberId ? c.copyWith(isProtagonist: false) : c,
        )
        .toList(growable: false);
  }
  return cast
      .map((c) => c.copyWith(isProtagonist: c.id == memberId))
      .toList(growable: false);
}

CastMember? protagonistOf(Iterable<CastMember> cast) {
  for (final member in cast) {
    if (member.isProtagonist) return member;
  }
  return null;
}