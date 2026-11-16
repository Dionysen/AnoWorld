import 'package:anoworld/domain/models/json_map.dart';

enum ProjectAssetKind { background, sprite, avatar, other }

extension ProjectAssetKindCodec on ProjectAssetKind {
  String get wireName => name;

  static ProjectAssetKind parse(String raw) {
    return switch (raw) {
      'background' => ProjectAssetKind.background,
      'sprite' => ProjectAssetKind.sprite,
      'avatar' => ProjectAssetKind.avatar,
      'other' => ProjectAssetKind.other,
      _ => throw FormatException('Unknown asset kind "$raw"'),
    };
  }
}

/// Catalog entry for a file under the project `assets/` folder.
class ProjectAsset {
  const ProjectAsset({
    required this.id,
    required this.kind,
    required this.relativePath,
  });

  final String id;
  final ProjectAssetKind kind;

  /// Path relative to the project `assets/` directory (POSIX-style).
  final String relativePath;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'kind': kind.wireName,
        'relativePath': relativePath,
      };

  factory ProjectAsset.fromJson(Map<String, dynamic> json) {
    return ProjectAsset(
      id: json.requireString('id'),
      kind: ProjectAssetKindCodec.parse(json.requireString('kind')),
      relativePath: json.requireString('relativePath'),
    );
  }
}
