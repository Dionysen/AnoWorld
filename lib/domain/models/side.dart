import 'package:anoworld/domain/models/json_map.dart';

/// Side quests. MVP keeps an empty instance list; shape stays stable.
class SideBundle {
  const SideBundle({this.instances = const <SideInstance>[]});

  final List<SideInstance> instances;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'instances': instances.map((i) => i.toJson()).toList(growable: false),
      };

  factory SideBundle.fromJson(Map<String, dynamic> json) {
    return SideBundle(
      instances: json
          .optionalList('instances')
          .map(
            (item) =>
                SideInstance.fromJson(asJsonMap(item, path: 'instances[]')),
          )
          .toList(growable: false),
    );
  }
}

class SideInstance {
  const SideInstance({
    required this.id,
    required this.title,
    required this.templateId,
    this.beatIds = const <String>[],
  });

  final String id;
  final String title;
  final String templateId;
  final List<String> beatIds;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'templateId': templateId,
        'beatIds': beatIds,
      };

  factory SideInstance.fromJson(Map<String, dynamic> json) {
    return SideInstance(
      id: json.requireString('id'),
      title: json.requireString('title'),
      templateId: json.requireString('templateId'),
      beatIds: json.stringList('beatIds', required: false),
    );
  }
}
