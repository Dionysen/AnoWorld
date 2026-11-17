import 'package:anoworld/domain/models/background.dart';
import 'package:anoworld/domain/models/cast.dart' show CastMember, protagonistOf;
import 'package:anoworld/domain/models/json_map.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/project_asset.dart';
import 'package:anoworld/domain/models/side.dart';

/// On-disk / in-memory work package (docs/Core.md Project).
class Project {
  const Project({
    required this.meta,
    required this.background,
    required this.cast,
    required this.main,
    this.side = const SideBundle(),
    this.assets = const <ProjectAsset>[],
  });

  final ProjectMeta meta;
  final Background background;
  final List<CastMember> cast;
  final MainStory main;
  final SideBundle side;
  final List<ProjectAsset> assets;

  CastMember? castById(String id) {
    for (final member in cast) {
      if (member.id == id) return member;
    }
    return null;
  }

  /// Member勾选了「主角」，供 {{char}} 与酒馆角色段；未勾选时返回 null。
  CastMember? get protagonist => protagonistOf(cast);

  ProjectAsset? assetById(String id) {
    for (final asset in assets) {
      if (asset.id == id) return asset;
    }
    return null;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'meta': meta.toJson(),
        'background': background.toJson(),
        'cast': cast.map((c) => c.toJson()).toList(growable: false),
        'main': main.toJson(),
        'side': side.toJson(),
        'assets': assets.map((a) => a.toJson()).toList(growable: false),
      };

  factory Project.fromJson(Map<String, dynamic> json) {
    // Legacy v1: `presets` / `activePresetId` are ignored (global AiPreset).
    return Project(
      meta: ProjectMeta.fromJson(json.requireMap('meta')),
      background: Background.fromJson(json.requireMap('background')),
      cast: json
          .requireList('cast')
          .map((item) => CastMember.fromJson(asJsonMap(item, path: 'cast[]')))
          .toList(growable: false),
      main: MainStory.fromJson(json.requireMap('main')),
      side: json.optionalMap('side') == null
          ? const SideBundle()
          : SideBundle.fromJson(json.requireMap('side')),
      assets: json
          .optionalList('assets')
          .map(
            (item) =>
                ProjectAsset.fromJson(asJsonMap(item, path: 'assets[]')),
          )
          .toList(growable: false),
    );
  }

  Project copyWith({
    ProjectMeta? meta,
    Background? background,
    List<CastMember>? cast,
    MainStory? main,
    SideBundle? side,
    List<ProjectAsset>? assets,
  }) {
    return Project(
      meta: meta ?? this.meta,
      background: background ?? this.background,
      cast: cast ?? this.cast,
      main: main ?? this.main,
      side: side ?? this.side,
      assets: assets ?? this.assets,
    );
  }
}

class ProjectMeta {
  const ProjectMeta({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.schemaVersion = ProjectManifest.currentSchemaVersion,
    this.coverPath,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;

  /// Relative path under project `assets/` (e.g. `cover.jpg`).
  final String? coverPath;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'schemaVersion': schemaVersion,
        if (coverPath != null && coverPath!.trim().isNotEmpty)
          'coverPath': coverPath,
      };

  factory ProjectMeta.fromJson(Map<String, dynamic> json) {
    final cover = json.optionalString('coverPath')?.trim();
    return ProjectMeta(
      id: json.requireString('id'),
      title: json.requireString('title'),
      createdAt: DateTime.parse(json.requireString('createdAt')),
      updatedAt: DateTime.parse(json.requireString('updatedAt')),
      schemaVersion:
          (json.optionalNum('schemaVersion') ??
                  ProjectManifest.currentSchemaVersion)
              .toInt(),
      coverPath: (cover == null || cover.isEmpty) ? null : cover,
    );
  }

  ProjectMeta copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? schemaVersion,
    String? coverPath,
    bool clearCoverPath = false,
  }) {
    return ProjectMeta(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      coverPath: clearCoverPath ? null : (coverPath ?? this.coverPath),
    );
  }
}

/// Folder package header (NativeTavern-style manifest gate).
class ProjectManifest {
  const ProjectManifest({
    required this.projectId,
    required this.title,
    required this.updatedAt,
    this.format = formatName,
    this.schemaVersion = currentSchemaVersion,
  });

  static const String formatName = 'anoworld-project';
  static const int currentSchemaVersion = 2;

  final String format;
  final int schemaVersion;
  final String projectId;
  final String title;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'format': format,
        'schemaVersion': schemaVersion,
        'projectId': projectId,
        'title': title,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory ProjectManifest.fromJson(Map<String, dynamic> json) {
    final format = json.requireString('format');
    if (format != formatName) {
      throw FormatException('Unsupported project format "$format"');
    }
    final schemaVersion = (json.optionalNum('schemaVersion') ?? 1).toInt();
    if (schemaVersion > currentSchemaVersion) {
      throw FormatException(
        'Project schemaVersion $schemaVersion is newer than '
        'supported $currentSchemaVersion',
      );
    }
    return ProjectManifest(
      format: format,
      schemaVersion: schemaVersion,
      projectId: json.requireString('projectId'),
      title: json.requireString('title'),
      updatedAt: DateTime.parse(json.requireString('updatedAt')),
    );
  }

  factory ProjectManifest.fromProject(Project project) {
    return ProjectManifest(
      projectId: project.meta.id,
      title: project.meta.title,
      updatedAt: project.meta.updatedAt,
      schemaVersion: project.meta.schemaVersion,
    );
  }
}

/// Lightweight row for project lists (no full main/cast payload).
class ProjectSummary {
  const ProjectSummary({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.directoryPath,
  });

  final String id;
  final String title;
  final DateTime updatedAt;
  final String directoryPath;
}