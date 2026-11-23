import 'package:anoworld/domain/models/json_map.dart';

/// Card-level provenance taken from a SillyTavern card (or filled in by hand)
/// and kept on the story so nothing about the original author is lost.
///
/// Stored under `meta.card` in the story package; every field is optional and
/// editable from the story detail page.
class StoryCardMeta {
  const StoryCardMeta({
    this.creator = '',
    this.version = '',
    this.creatorNotes = '',
    this.tags = const <String>[],
  });

  static const StoryCardMeta empty = StoryCardMeta();

  /// Card author (`creator` on the card).
  final String creator;

  /// Card revision (`character_version` on the card).
  final String version;

  /// Notes the author wrote for the card (`creator_notes`).
  final String creatorNotes;

  /// Card tags, shown as chips on the story detail page.
  final List<String> tags;

  bool get isEmpty =>
      creator.trim().isEmpty &&
      version.trim().isEmpty &&
      creatorNotes.trim().isEmpty &&
      tags.isEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (creator.trim().isNotEmpty) 'creator': creator,
        if (version.trim().isNotEmpty) 'version': version,
        if (creatorNotes.trim().isNotEmpty) 'creatorNotes': creatorNotes,
        if (tags.isNotEmpty) 'tags': tags,
      };

  factory StoryCardMeta.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const StoryCardMeta();
    return StoryCardMeta(
      creator: (json.optionalString('creator') ?? '').trim(),
      version: (json.optionalString('version') ?? '').trim(),
      creatorNotes: json.optionalString('creatorNotes') ?? '',
      tags: json.stringList('tags', required: false),
    );
  }

  StoryCardMeta copyWith({
    String? creator,
    String? version,
    String? creatorNotes,
    List<String>? tags,
  }) {
    return StoryCardMeta(
      creator: creator ?? this.creator,
      version: version ?? this.version,
      creatorNotes: creatorNotes ?? this.creatorNotes,
      tags: tags ?? this.tags,
    );
  }
}
