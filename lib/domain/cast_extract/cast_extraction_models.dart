/// One character the model pulled out of a world-book window.
///
/// Already gated (literal names/examples verified against the source) by
/// [gateExtractedCast] before it reaches the preview.
class ExtractedCast {
  const ExtractedCast({
    required this.name,
    this.aliases = const <String>[],
    this.summary = '',
    this.personality = '',
    this.speechStyle = '',
    this.exampleLines = const <String>[],
    this.visualTags = '',
    this.sourceEntry = '',
  });

  final String name;
  final List<String> aliases;
  final String summary;
  final String personality;
  final String speechStyle;
  final List<String> exampleLines;
  final String visualTags;
  final String sourceEntry;

  ExtractedCast copyWith({
    String? name,
    List<String>? aliases,
    String? summary,
    String? personality,
    String? speechStyle,
    List<String>? exampleLines,
    String? visualTags,
    String? sourceEntry,
  }) {
    return ExtractedCast(
      name: name ?? this.name,
      aliases: aliases ?? this.aliases,
      summary: summary ?? this.summary,
      personality: personality ?? this.personality,
      speechStyle: speechStyle ?? this.speechStyle,
      exampleLines: exampleLines ?? this.exampleLines,
      visualTags: visualTags ?? this.visualTags,
      sourceEntry: sourceEntry ?? this.sourceEntry,
    );
  }

  /// Tolerant mapper for one `characters[]` row.
  factory ExtractedCast.fromJson(Map<Object?, Object?> json) {
    String text(String key) => '${json[key] ?? ''}'.trim();
    List<String> list(String key) {
      final raw = json[key];
      if (raw is List) {
        return raw
            .map((item) => '$item'.trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false);
      }
      final single = '${raw ?? ''}'.trim();
      return single.isEmpty ? const <String>[] : <String>[single];
    }

    return ExtractedCast(
      name: text('name'),
      aliases: list('aliases'),
      summary: text('summary'),
      personality: text('personality'),
      speechStyle: text('speechStyle'),
      exampleLines: list('exampleLines'),
      visualTags: text('visualTags'),
      sourceEntry: text('source'),
    );
  }
}
