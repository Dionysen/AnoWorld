import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:anoworld/data/project/project_paths.dart';
import 'package:anoworld/domain/models/json_map.dart';
import 'package:anoworld/domain/models/project_folder.dart';
import 'package:anoworld/domain/repositories/project_folder_repository.dart';
import 'package:path/path.dart' as p;

/// Persists library folders beside project packages:
/// `{library}/folders.json`
class FileProjectFolderRepository implements ProjectFolderRepository {
  FileProjectFolderRepository({
    ProjectPaths? paths,
    String Function()? idGenerator,
  })  : _paths = paths ?? ProjectPaths(),
        _idGenerator = idGenerator ?? _defaultId;

  static const String fileName = 'folders.json';

  final ProjectPaths _paths;
  final String Function() _idGenerator;
  static final _random = Random();

  static String _defaultId() {
    final millis = DateTime.now().toUtc().millisecondsSinceEpoch;
    final suffix = _random.nextInt(1 << 20).toRadixString(16).padLeft(5, '0');
    return 'f_$millis$suffix';
  }

  Future<File> _file() async {
    final root = await _paths.libraryRoot();
    return File(p.join(root, fileName));
  }

  Future<_FolderStore> _load() async {
    final file = await _file();
    if (!await file.exists()) return _FolderStore.empty();
    try {
      final map = asJsonMap(
        jsonDecode(await file.readAsString()),
        path: file.path,
      );
      final folders = map
          .optionalList('folders')
          .map(
            (item) => ProjectFolder.fromJson(
              asJsonMap(item, path: 'folders[]'),
            ),
          )
          .toList();
      final memberships = <String, String>{};
      final raw = map.optionalMap('memberships') ?? const <String, dynamic>{};
      for (final entry in raw.entries) {
        final value = entry.value;
        if (value is String && value.isNotEmpty) {
          memberships[entry.key] = value;
        }
      }
      return _FolderStore(folders: folders, memberships: memberships);
    } on Object {
      return _FolderStore.empty();
    }
  }

  Future<void> _save(_FolderStore store) async {
    final file = await _file();
    final payload = <String, dynamic>{
      'folders': store.folders.map((f) => f.toJson()).toList(growable: false),
      'memberships': store.memberships,
    };
    await file.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(payload)}\n',
    );
  }

  ProjectFolder _withCounts(_FolderStore store, ProjectFolder folder) {
    final projectCount =
        store.memberships.values.where((id) => id == folder.id).length;
    final childFolderCount =
        store.folders.where((f) => f.parentId == folder.id).length;
    return folder.copyWith(
      projectCount: projectCount,
      childFolderCount: childFolderCount,
    );
  }

  @override
  Future<List<ProjectFolder>> listFolders({String? parentId}) async {
    final store = await _load();
    final list = store.folders
        .where((f) => f.parentId == parentId)
        .map((f) => _withCounts(store, f))
        .toList(growable: false);
    list.sort((a, b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      if (byOrder != 0) return byOrder;
      return a.name.compareTo(b.name);
    });
    return list;
  }

  @override
  Future<ProjectFolder?> getFolder(String folderId) async {
    final store = await _load();
    for (final folder in store.folders) {
      if (folder.id == folderId) return _withCounts(store, folder);
    }
    return null;
  }

  @override
  Future<List<ProjectFolder>> breadcrumbs(String folderId) async {
    final store = await _load();
    final byId = {for (final f in store.folders) f.id: f};
    final chain = <ProjectFolder>[];
    var current = byId[folderId];
    while (current != null) {
      chain.insert(0, _withCounts(store, current));
      final parent = current.parentId;
      current = parent == null ? null : byId[parent];
    }
    return chain;
  }

  @override
  Future<ProjectFolder> createFolder({
    required String name,
    String? parentId,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Folder name is empty');
    }
    final store = await _load();
    if (parentId != null &&
        !store.folders.any((f) => f.id == parentId)) {
      throw StateError('Unknown parent folder "$parentId"');
    }
    final siblings =
        store.folders.where((f) => f.parentId == parentId).toList();
    final sortOrder = siblings.isEmpty
        ? 0
        : siblings.map((f) => f.sortOrder).reduce(max) + 1;
    final folder = ProjectFolder(
      id: _idGenerator(),
      name: trimmed,
      parentId: parentId,
      sortOrder: sortOrder,
      createdAt: DateTime.now().toUtc(),
    );
    store.folders.add(folder);
    await _save(store);
    return _withCounts(store, folder);
  }

  @override
  Future<void> renameFolder({
    required String folderId,
    required String name,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Folder name is empty');
    }
    final store = await _load();
    final index = store.folders.indexWhere((f) => f.id == folderId);
    if (index < 0) throw StateError('Unknown folder "$folderId"');
    store.folders[index] = store.folders[index].copyWith(name: trimmed);
    await _save(store);
  }

  @override
  Future<void> moveFolder({
    required String folderId,
    String? parentId,
  }) async {
    final store = await _load();
    final index = store.folders.indexWhere((f) => f.id == folderId);
    if (index < 0) throw StateError('Unknown folder "$folderId"');
    if (parentId == folderId) {
      throw ArgumentError('Cannot move folder into itself');
    }
    if (parentId != null) {
      final byId = {for (final f in store.folders) f.id: f};
      if (!byId.containsKey(parentId)) {
        throw StateError('Unknown parent folder "$parentId"');
      }
      var walk = parentId;
      while (true) {
        if (walk == folderId) {
          throw ArgumentError('Cannot move folder under its descendant');
        }
        final parent = byId[walk]?.parentId;
        if (parent == null) break;
        walk = parent;
      }
    }
    store.folders[index] = store.folders[index].copyWith(
      parentId: parentId,
      clearParentId: parentId == null,
    );
    await _save(store);
  }

  Set<String> _descendants(_FolderStore store, String folderId) {
    final ids = <String>{folderId};
    var grew = true;
    while (grew) {
      grew = false;
      for (final folder in store.folders) {
        final parent = folder.parentId;
        if (parent != null && ids.contains(parent) && ids.add(folder.id)) {
          grew = true;
        }
      }
    }
    return ids;
  }

  @override
  Future<void> deleteFolder(String folderId) async {
    final store = await _load();
    final doomed = _descendants(store, folderId);
    store.folders.removeWhere((f) => doomed.contains(f.id));
    store.memberships.removeWhere((_, value) => doomed.contains(value));
    await _save(store);
  }

  @override
  Future<void> dissolveFolder(String folderId) async {
    final store = await _load();
    final index = store.folders.indexWhere((f) => f.id == folderId);
    if (index < 0) throw StateError('Unknown folder "$folderId"');
    final parentId = store.folders[index].parentId;
    for (var i = 0; i < store.folders.length; i++) {
      if (store.folders[i].parentId == folderId) {
        store.folders[i] = store.folders[i].copyWith(
          parentId: parentId,
          clearParentId: parentId == null,
        );
      }
    }
    for (final entry in store.memberships.entries.toList()) {
      if (entry.value == folderId) {
        if (parentId == null) {
          store.memberships.remove(entry.key);
        } else {
          store.memberships[entry.key] = parentId;
        }
      }
    }
    store.folders.removeAt(index);
    await _save(store);
  }

  @override
  Future<String?> folderIdForProject(String projectId) async {
    final store = await _load();
    return store.memberships[projectId];
  }

  @override
  Future<List<String>> projectIdsInFolder(String? folderId) async {
    final store = await _load();
    if (folderId == null) {
      // Root membership is implicit (absent from the map). Callers filter
      // library projects whose folderIdForProject is null.
      return const <String>[];
    }
    return store.memberships.entries
        .where((e) => e.value == folderId)
        .map((e) => e.key)
        .toList(growable: false);
  }

  @override
  Future<void> moveProjects({
    required Iterable<String> projectIds,
    String? folderId,
  }) async {
    final store = await _load();
    if (folderId != null &&
        !store.folders.any((f) => f.id == folderId)) {
      throw StateError('Unknown folder "$folderId"');
    }
    for (final id in projectIds) {
      if (folderId == null) {
        store.memberships.remove(id);
      } else {
        store.memberships[id] = folderId;
      }
    }
    await _save(store);
  }

  @override
  Future<void> removeProjectMembership(String projectId) async {
    final store = await _load();
    store.memberships.remove(projectId);
    await _save(store);
  }
}

class _FolderStore {
  _FolderStore({
    required this.folders,
    required this.memberships,
  });

  factory _FolderStore.empty() => _FolderStore(
        folders: <ProjectFolder>[],
        memberships: <String, String>{},
      );

  final List<ProjectFolder> folders;
  final Map<String, String> memberships;
}
