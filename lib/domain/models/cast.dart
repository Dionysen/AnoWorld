import 'package:anoworld/domain/models/json_map.dart';

class CastMember {
  const CastMember({
    required this.id,
    required this.name,
    this.summary = '',
    this.personality = '',
    this.speechStyle = '',
    this.exampleLines = const <String>[],
    this.avatarAssetId,
  });

  final String id;
  final String name;
  final String summary;
  final String personality;
  final String speechStyle;
  final List<String> exampleLines;
  final String? avatarAssetId;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'summary': summary,
        'personality': personality,
        'speechStyle': speechStyle,
        'exampleLines': exampleLines,
        if (avatarAssetId != null) 'avatarAssetId': avatarAssetId,
      };

  factory CastMember.fromJson(Map<String, dynamic> json) {
    return CastMember(
      id: json.requireString('id'),
      name: json.requireString('name'),
      summary: json.optionalString('summary') ?? '',
      personality: json.optionalString('personality') ?? '',
      speechStyle: json.optionalString('speechStyle') ?? '',
      exampleLines: json.stringList('exampleLines', required: false),
      avatarAssetId: json.optionalString('avatarAssetId'),
    );
  }

  CastMember copyWith({
    String? id,
    String? name,
    String? summary,
    String? personality,
    String? speechStyle,
    List<String>? exampleLines,
    String? avatarAssetId,
  }) {
    return CastMember(
      id: id ?? this.id,
      name: name ?? this.name,
      summary: summary ?? this.summary,
      personality: personality ?? this.personality,
      speechStyle: speechStyle ?? this.speechStyle,
      exampleLines: exampleLines ?? this.exampleLines,
      avatarAssetId: avatarAssetId ?? this.avatarAssetId,
    );
  }
}
