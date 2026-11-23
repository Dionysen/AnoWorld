import 'package:anoworld/domain/models/json_map.dart';
import 'package:anoworld/domain/models/main_story.dart';

class CastMember {
  const CastMember({
    required this.id,
    required this.name,
    this.aliases = const <String>[],
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

  /// Story nicknames / titles the same character answers to (老公、苏姐 …).
  /// Matched through [normalizeCastName] so a stray「（冷笑）」still lands.
  final List<String> aliases;

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
        if (aliases.isNotEmpty) 'aliases': aliases,
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
      aliases: json.stringList('aliases', required: false),
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
    List<String>? aliases,
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
      aliases: aliases ?? this.aliases,
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

final RegExp _castNameTrailingNote =
    RegExp(r'\s*[（(][^（()）]*[)）]\s*$');
const String _castNameEdgeChars = ' \t\r\n　「」『』"\'“”‘’';

String _trimCastNameEdges(String text) {
  var start = 0;
  var end = text.length;
  while (start < end && _castNameEdgeChars.contains(text[start])) {
    start++;
  }
  while (end > start && _castNameEdgeChars.contains(text[end - 1])) {
    end--;
  }
  return text.substring(start, end);
}

/// Canonical form for matching a speaker string against cast names / aliases.
///
/// Strips outer quotes, spacing (half/full width) and a trailing
/// `（冷笑）` / `(laughs)` stage direction, so `「梦涵（冷笑）」` meets `梦涵`.
String normalizeCastName(String raw) {
  var text = raw.trim();
  if (text.isEmpty) return '';
  // Drop one trailing parenthetical note: 名字（冷笑） / 名字 (smiles).
  text = text.replaceFirst(_castNameTrailingNote, '');
  // Collapse inner spaces (梦 涵 → 梦涵).
  text = text.replaceAll(RegExp(r'\s+'), '');
  // Peel wrapping quotes, repeating for 「『梦涵』」.
  while (true) {
    final next = _trimCastNameEdges(text);
    if (next == text) break;
    text = next;
  }
  return text;
}

/// The cast member a speaker string refers to, by id, name or alias.
///
/// Returns null when the string is not a defined character; callers treat that
/// as narration rather than inventing a speaker.
CastMember? castMemberForSpeaker(Iterable<CastMember> cast, String speaker) {
  final raw = speaker.trim();
  if (raw.isEmpty) return null;
  for (final member in cast) {
    if (member.id == raw) return member;
  }
  final needle = normalizeCastName(raw);
  if (needle.isEmpty) return null;
  for (final member in cast) {
    if (normalizeCastName(member.name) == needle) return member;
    for (final alias in member.aliases) {
      if (normalizeCastName(alias) == needle) return member;
    }
  }
  return null;
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