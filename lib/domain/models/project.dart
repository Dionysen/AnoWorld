import 'package:anoworld/domain/models/world_book.dart';
import 'package:anoworld/domain/models/cast.dart' show CastMember, protagonistOf;
import 'package:anoworld/domain/models/json_map.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/plot_element.dart';
import 'package:anoworld/domain/models/project_asset.dart';
import 'package:anoworld/domain/models/side.dart';
import 'package:anoworld/domain/models/story_card_meta.dart';

Map<String, dynamic> _worldBookJson(Map<String, dynamic> json) {
  final legacy = json.optionalMap('background');
  if (legacy != null) return legacy;
  return json.requireMap('worldBook');
}

/// On-disk / in-memory work package (docs/Core.md Project).
class Project {
  const Project({
    required this.meta,
    required this.worldBook,
    required this.cast,
    required this.main,
    this.side = const SideBundle(),
    this.assets = const <ProjectAsset>[],
    this.plotElements = const PlotElementSelection(),
  });

  final ProjectMeta meta;
  final WorldBook worldBook;
  final List<CastMember> cast;
  final MainStory main;
  final SideBundle side;
  final List<ProjectAsset> assets;

  /// Selected global plot-element ids for this story.
  final PlotElementSelection plotElements;

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
        'worldBook': worldBook.toJson(),
        'cast': cast.map((c) => c.toJson()).toList(growable: false),
        'main': main.toJson(),
        'side': side.toJson(),
        'assets': assets.map((a) => a.toJson()).toList(growable: false),
        'plotElements': plotElements.toJson(),
      };

  factory Project.fromJson(Map<String, dynamic> json) {
    // Legacy v1: `presets` / `activePresetId` are ignored (global AiPreset).
    return Project(
      meta: ProjectMeta.fromJson(json.requireMap('meta')),
      worldBook: WorldBook.fromJson(_worldBookJson(json)),
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
      plotElements: PlotElementSelection.fromJson(
        json.optionalMap('plotElements'),
      ),
    );
  }

  Project copyWith({
    ProjectMeta? meta,
    WorldBook? worldBook,
    List<CastMember>? cast,
    MainStory? main,
    SideBundle? side,
    List<ProjectAsset>? assets,
    PlotElementSelection? plotElements,
  }) {
    return Project(
      meta: meta ?? this.meta,
      worldBook: worldBook ?? this.worldBook,
      cast: cast ?? this.cast,
      main: main ?? this.main,
      side: side ?? this.side,
      assets: assets ?? this.assets,
      plotElements: plotElements ?? this.plotElements,
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
    this.card = StoryCardMeta.empty,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;

  /// Relative path under project `assets/` (e.g. `cover.jpg`).
  final String? coverPath;

  /// Author / version / tags / creator notes carried over from a card import.
  final StoryCardMeta card;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'schemaVersion': schemaVersion,
        if (coverPath != null && coverPath!.trim().isNotEmpty)
          'coverPath': coverPath,
        if (!card.isEmpty) 'card': card.toJson(),
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
      card: StoryCardMeta.fromJson(json.optionalMap('card')),
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
    StoryCardMeta? card,
  }) {
    return ProjectMeta(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      coverPath: clearCoverPath ? null : (coverPath ?? this.coverPath),
      card: card ?? this.card,
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
  static const int currentSchemaVersion = 3;

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
    this.coverPath,
  });

  final String id;
  final String title;
  final DateTime updatedAt;
  final String directoryPath;

  /// Relative `cover.*` under the project `assets/` folder, when present.
  final String? coverPath;
}