import 'package:anoworld/domain/models/json_map.dart';

/// World facts for a project.
///
/// Entries are the AnoWorld take on lorebook-style chunks: some always inject
/// (基调 / 硬规则), others trigger by keywords during bridge generation.
/// Not a SillyTavern World Info engine — no recursion, regex keys, or insert
/// depth matrix.
class Background {
  const Background({this.entries = const <BackgroundEntry>[]});

  final List<BackgroundEntry> entries;

  /// Always-on entries first, then the rest (stable for prompts / previews).
  String get combinedText {
    if (entries.isEmpty) return '';
    final always = entries.where((e) => e.alwaysOn);
    final keyed = entries.where((e) => !e.alwaysOn);
    return <BackgroundEntry>[...always, ...keyed]
        .map(_formatEntry)
        .join('\n\n');
  }

  String get alwaysOnText {
    final blocks = entries.where((e) => e.alwaysOn).map(_formatEntry);
    return blocks.join('\n\n');
  }

  static String _formatEntry(BackgroundEntry entry) {
    if (entry.title.isEmpty) return entry.body;
    return '## ${entry.title}\n${entry.body}';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'entries': entries.map((e) => e.toJson()).toList(growable: false),
      };

  factory Background.fromJson(Map<String, dynamic> json) {
    final rawEntries = json.optionalList('entries');
    if (rawEntries.isNotEmpty) {
      return Background(
        entries: rawEntries
            .map(
              (item) => BackgroundEntry.fromJson(
                asJsonMap(item, path: 'entries[]'),
              ),
            )
            .toList(growable: false),
      );
    }
    // Legacy: sections[] → always-on entries.
    final rawSections = json.optionalList('sections');
    if (rawSections.isEmpty) return const Background();
    return Background(
      entries: rawSections
          .map((item) {
            final map = asJsonMap(item, path: 'sections[]');
            return BackgroundEntry(
              id: map.requireString('id'),
              title: map.requireString('title'),
              body: map.requireString('body'),
              alwaysOn: true,
            );
          })
          .toList(growable: false),
    );
  }

  Background copyWith({List<BackgroundEntry>? entries}) {
    return Background(entries: entries ?? this.entries);
  }
}

class BackgroundEntry {
  const BackgroundEntry({
    required this.id,
    required this.title,
    required this.body,
    this.keys = const <String>[],
    this.alwaysOn = false,
  });

  final String id;
  final String title;
  final String body;

  /// Plain keywords that can pull this entry into bridge context.
  final List<String> keys;

  /// When true, inject without keyword match (基调 / 硬规则).
  final bool alwaysOn;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'body': body,
        'keys': keys,
        'alwaysOn': alwaysOn,
      };

  factory BackgroundEntry.fromJson(Map<String, dynamic> json) {
    return BackgroundEntry(
      id: json.requireString('id'),
      title: json.requireString('title'),
      body: json.requireString('body'),
      keys: json.stringList('keys', required: false),
      alwaysOn: json.optionalBool('alwaysOn') ?? false,
    );
  }

  BackgroundEntry copyWith({
    String? id,
    String? title,
    String? body,
    List<String>? keys,
    bool? alwaysOn,
  }) {
    return BackgroundEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      keys: keys ?? this.keys,
      alwaysOn: alwaysOn ?? this.alwaysOn,
    );
  }
}
