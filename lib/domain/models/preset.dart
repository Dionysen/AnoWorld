import 'package:anoworld/domain/models/json_map.dart';

/// How AI should write — separate from world facts (Background).
class Preset {
  const Preset({
    required this.id,
    required this.name,
    this.styleNotes = '',
    this.outputBans = const <String>[],
    this.outputPreferences = const <String>[],
    this.applyToCreator = true,
    this.applyToRuntimeChat = true,
  });

  final String id;
  final String name;
  final String styleNotes;
  final List<String> outputBans;
  final List<String> outputPreferences;
  final bool applyToCreator;
  final bool applyToRuntimeChat;

  static const String defaultId = 'preset_default';

  factory Preset.builtinDefault() {
    return const Preset(
      id: defaultId,
      name: '默认',
      styleNotes: '简洁对白，少系统腔；场景描写克制。',
      outputBans: <String>['剧透后续主线', 'OOC 系统说明'],
      outputPreferences: <String>['选项短而可执行', '先给可玩段落再润色'],
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'styleNotes': styleNotes,
        'outputBans': outputBans,
        'outputPreferences': outputPreferences,
        'applyToCreator': applyToCreator,
        'applyToRuntimeChat': applyToRuntimeChat,
      };

  factory Preset.fromJson(Map<String, dynamic> json) {
    return Preset(
      id: json.requireString('id'),
      name: json.requireString('name'),
      styleNotes: json.optionalString('styleNotes') ?? '',
      outputBans: json.stringList('outputBans', required: false),
      outputPreferences: json.stringList('outputPreferences', required: false),
      applyToCreator: json.optionalBool('applyToCreator') ?? true,
      applyToRuntimeChat: json.optionalBool('applyToRuntimeChat') ?? true,
    );
  }

  Preset copyWith({
    String? id,
    String? name,
    String? styleNotes,
    List<String>? outputBans,
    List<String>? outputPreferences,
    bool? applyToCreator,
    bool? applyToRuntimeChat,
  }) {
    return Preset(
      id: id ?? this.id,
      name: name ?? this.name,
      styleNotes: styleNotes ?? this.styleNotes,
      outputBans: outputBans ?? this.outputBans,
      outputPreferences: outputPreferences ?? this.outputPreferences,
      applyToCreator: applyToCreator ?? this.applyToCreator,
      applyToRuntimeChat: applyToRuntimeChat ?? this.applyToRuntimeChat,
    );
  }
}
