import 'package:anoworld/domain/models/json_map.dart';

/// World facts. Sections are free-form titled blocks for MVP.
class Background {
  const Background({this.sections = const <BackgroundSection>[]});

  final List<BackgroundSection> sections;

  String get combinedText {
    if (sections.isEmpty) return '';
    return sections
        .map((s) => s.title.isEmpty ? s.body : '## ${s.title}\n${s.body}')
        .join('\n\n');
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'sections': sections.map((s) => s.toJson()).toList(growable: false),
      };

  factory Background.fromJson(Map<String, dynamic> json) {
    return Background(
      sections: json
          .optionalList('sections')
          .map(
            (item) => BackgroundSection.fromJson(
              asJsonMap(item, path: 'sections[]'),
            ),
          )
          .toList(growable: false),
    );
  }

  Background copyWith({List<BackgroundSection>? sections}) {
    return Background(sections: sections ?? this.sections);
  }
}

class BackgroundSection {
  const BackgroundSection({
    required this.id,
    required this.title,
    required this.body,
  });

  final String id;
  final String title;
  final String body;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'body': body,
      };

  factory BackgroundSection.fromJson(Map<String, dynamic> json) {
    return BackgroundSection(
      id: json.requireString('id'),
      title: json.requireString('title'),
      body: json.requireString('body'),
    );
  }
}
