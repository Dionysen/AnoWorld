import 'package:anoworld/domain/models/json_map.dart';

class CastMember {
  const CastMember({
    required this.id,
    required this.name,
    this.summary = '',
    this.personality = '',
    this.speechStyle = '',
    this.exampleLines = const <String>[],
    this.visualTags = '',
    this.avatarAssetId,
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

  final String? avatarAssetId;

  /// Drives {{char}} and ST char* prompt sections when this member is selected.
  final bool isProtagonist;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'summary': summary,
        'personality': personality,
        'speechStyle': speechStyle,
        'exampleLines': exampleLines,
        if (visualTags.trim().isNotEmpty) 'visualTags': visualTags,
        if (avatarAssetId != null) 'avatarAssetId': avatarAssetId,
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
      avatarAssetId: json.optionalString('avatarAssetId'),
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
    String? avatarAssetId,
    bool clearAvatarAssetId = false,
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
      avatarAssetId:
          clearAvatarAssetId ? null : (avatarAssetId ?? this.avatarAssetId),
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