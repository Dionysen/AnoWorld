import 'package:anoworld/domain/models/json_map.dart';

/// World facts for a project (酒馆式世界书条目).
///
/// Entries inject always-on (基调 / 硬规则) or by keyword during generation.
/// Not a SillyTavern World Info engine — no recursion, regex keys, or insert
/// depth matrix.
class WorldBook {
  const WorldBook({this.entries = const <WorldBookEntry>[]});

  final List<WorldBookEntry> entries;

  /// Always-on entries first, then the rest (stable for prompts / previews).
  String get combinedText {
    if (entries.isEmpty) return '';
    final always = entries.where((e) => e.alwaysOn);
    final keyed = entries.where((e) => !e.alwaysOn);
    return <WorldBookEntry>[...always, ...keyed]
        .map(_formatEntry)
        .join('\n\n');
  }

  String get alwaysOnText {
    final blocks = entries.where((e) => e.alwaysOn).map(_formatEntry);
    return blocks.join('\n\n');
  }

  static String _formatEntry(WorldBookEntry entry) {
    if (entry.title.isEmpty) return entry.body;
    return '## ${entry.title}\n${entry.body}';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'entries': entries.map((e) => e.toJson()).toList(growable: false),
      };

  factory WorldBook.fromJson(Map<String, dynamic> json) {
    final rawEntries = json.optionalList('entries');
    if (rawEntries.isNotEmpty) {
      return WorldBook(
        entries: rawEntries
            .map(
              (item) => WorldBookEntry.fromJson(
                asJsonMap(item, path: 'entries[]'),
              ),
            )
            .toList(growable: false),
      );
    }
    // Legacy: sections[] → always-on entries.
    final rawSections = json.optionalList('sections');
    if (rawSections.isEmpty) return const WorldBook();
    return WorldBook(
      entries: rawSections
          .map((item) {
            final map = asJsonMap(item, path: 'sections[]');
            return WorldBookEntry(
              id: map.requireString('id'),
              title: map.requireString('title'),
              body: map.requireString('body'),
              alwaysOn: true,
            );
          })
          .toList(growable: false),
    );
  }

  WorldBook copyWith({List<WorldBookEntry>? entries}) {
    return WorldBook(entries: entries ?? this.entries);
  }
}

class WorldBookEntry {
  const WorldBookEntry({
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

  factory WorldBookEntry.fromJson(Map<String, dynamic> json) {
    return WorldBookEntry(
      id: json.requireString('id'),
      title: json.requireString('title'),
      body: json.requireString('body'),
      keys: json.stringList('keys', required: false),
      alwaysOn: json.optionalBool('alwaysOn') ?? false,
    );
  }

  WorldBookEntry copyWith({
    String? id,
    String? title,
    String? body,
    List<String>? keys,
    bool? alwaysOn,
  }) {
    return WorldBookEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      keys: keys ?? this.keys,
      alwaysOn: alwaysOn ?? this.alwaysOn,
    );
  }
}