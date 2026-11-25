import 'package:anoworld/domain/models/json_map.dart';

/// Card-level provenance taken from a SillyTavern card (or filled in by hand)
/// and kept on the story so nothing about the original author is lost.
///
/// Stored under `meta.card` in the story package; every field is optional and
/// editable from the story detail page. Dates align with CCv3
/// `creation_date` / `modification_date` (and ST `create_date` when present).
class StoryCardMeta {
  const StoryCardMeta({
    this.creator = '',
    this.version = '',
    this.creatorNotes = '',
    this.tags = const <String>[],
    this.createdAt = '',
    this.modifiedAt = '',
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

  /// Creation time: formatted from CCv3 `creation_date`, or raw ST `create_date`.
  final String createdAt;

  /// Last change time from CCv3 `modification_date` (formatted for display).
  final String modifiedAt;

  bool get isEmpty =>
      creator.trim().isEmpty &&
      version.trim().isEmpty &&
      creatorNotes.trim().isEmpty &&
      tags.isEmpty &&
      createdAt.trim().isEmpty &&
      modifiedAt.trim().isEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (creator.trim().isNotEmpty) 'creator': creator,
        if (version.trim().isNotEmpty) 'version': version,
        if (creatorNotes.trim().isNotEmpty) 'creatorNotes': creatorNotes,
        if (tags.isNotEmpty) 'tags': tags,
        if (createdAt.trim().isNotEmpty) 'createdAt': createdAt.trim(),
        if (modifiedAt.trim().isNotEmpty) 'modifiedAt': modifiedAt.trim(),
      };

  factory StoryCardMeta.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const StoryCardMeta();
    return StoryCardMeta(
      creator: (json.optionalString('creator') ?? '').trim(),
      version: (json.optionalString('version') ?? '').trim(),
      creatorNotes: json.optionalString('creatorNotes') ?? '',
      tags: json.stringList('tags', required: false),
      createdAt: (json.optionalString('createdAt') ?? '').trim(),
      modifiedAt: (json.optionalString('modifiedAt') ?? '').trim(),
    );
  }

  StoryCardMeta copyWith({
    String? creator,
    String? version,
    String? creatorNotes,
    List<String>? tags,
    String? createdAt,
    String? modifiedAt,
  }) {
    return StoryCardMeta(
      creator: creator ?? this.creator,
      version: version ?? this.version,
      creatorNotes: creatorNotes ?? this.creatorNotes,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
    );
  }

  /// Formats a CCv3 unix timestamp (seconds or ms) or ISO / free-text date.
  ///
  /// Unparseable free text (e.g. ST humanized `create_date`) is kept as-is.
  /// Zero / empty means unknown → empty string.
  static String formatCardDate(Object? raw) {
    if (raw == null) return '';
    if (raw is String) {
      final text = raw.trim();
      if (text.isEmpty) return '';
      final asNum = num.tryParse(text);
      if (asNum != null) return formatCardDate(asNum);
      final parsed = DateTime.tryParse(text);
      if (parsed != null) return _formatLocal(parsed);
      return text;
    }
    if (raw is! num) return '';
    final n = raw.toInt();
    if (n <= 0) return '';
    // Heuristic: values past year ~5138 in seconds are milliseconds.
    final utc = n > 100000000000
        ? DateTime.fromMillisecondsSinceEpoch(n, isUtc: true)
        : DateTime.fromMillisecondsSinceEpoch(n * 1000, isUtc: true);
    return _formatLocal(utc);
  }

  static String _formatLocal(DateTime value) {
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}
