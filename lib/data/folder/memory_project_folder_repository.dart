import 'dart:math';

import 'package:anoworld/domain/models/project_folder.dart';
import 'package:anoworld/domain/repositories/project_folder_repository.dart';

class MemoryProjectFolderRepository implements ProjectFolderRepository {
  MemoryProjectFolderRepository({
    List<ProjectFolder>? folders,
    Map<String, String>? memberships,
    String Function()? idGenerator,
  })  : _folders = List<ProjectFolder>.from(folders ?? const []),
        _memberships = Map<String, String>.from(memberships ?? const {}),
        _idGenerator = idGenerator ?? _defaultId;

  final List<ProjectFolder> _folders;
  final Map<String, String> _memberships;
  final String Function() _idGenerator;
  static int _seq = 0;

  static String _defaultId() {
    _seq += 1;
    return 'f_mem_$_seq';
  }

  ProjectFolder _withCounts(ProjectFolder folder) {
    final projectCount =
        _memberships.values.where((id) => id == folder.id).length;
    final childFolderCount =
        _folders.where((f) => f.parentId == folder.id).length;
    return folder.copyWith(
      projectCount: projectCount,
      childFolderCount: childFolderCount,
    );
  }

  @override
  Future<List<ProjectFolder>> listFolders({String? parentId}) async {
    final list = _folders
        .where((f) => f.parentId == parentId)
        .map(_withCounts)
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
    for (final folder in _folders) {
      if (folder.id == folderId) return _withCounts(folder);
    }
    return null;
  }

  @override
  Future<List<ProjectFolder>> breadcrumbs(String folderId) async {
    final byId = {for (final f in _folders) f.id: f};
    final chain = <ProjectFolder>[];
    var current = byId[folderId];
    while (current != null) {
      chain.insert(0, _withCounts(current));
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
    if (trimmed.isEmpty) throw ArgumentError('Folder name is empty');
    if (parentId != null && !_folders.any((f) => f.id == parentId)) {
      throw StateError('Unknown parent folder "$parentId"');
    }
    final siblings = _folders.where((f) => f.parentId == parentId);
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
    _folders.add(folder);
    return _withCounts(folder);
  }

  @override
  Future<void> renameFolder({
    required String folderId,
    required String name,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Folder name is empty');
    final index = _folders.indexWhere((f) => f.id == folderId);
    if (index < 0) throw StateError('Unknown folder "$folderId"');
    _folders[index] = _folders[index].copyWith(name: trimmed);
  }

  @override
  Future<void> moveFolder({
    required String folderId,
    String? parentId,
  }) async {
    final index = _folders.indexWhere((f) => f.id == folderId);
    if (index < 0) throw StateError('Unknown folder "$folderId"');
    if (parentId == folderId) {
      throw ArgumentError('Cannot move folder into itself');
    }
    if (parentId != null) {
      final byId = {for (final f in _folders) f.id: f};
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
    _folders[index] = _folders[index].copyWith(
      parentId: parentId,
      clearParentId: parentId == null,
    );
  }

  Set<String> _descendants(String folderId) {
    final ids = <String>{folderId};
    var grew = true;
    while (grew) {
      grew = false;
      for (final folder in _folders) {
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
    final doomed = _descendants(folderId);
    _folders.removeWhere((f) => doomed.contains(f.id));
    _memberships.removeWhere((_, value) => doomed.contains(value));
  }

  @override
  Future<void> dissolveFolder(String folderId) async {
    final index = _folders.indexWhere((f) => f.id == folderId);
    if (index < 0) throw StateError('Unknown folder "$folderId"');
    final parentId = _folders[index].parentId;
    for (var i = 0; i < _folders.length; i++) {
      if (_folders[i].parentId == folderId) {
        _folders[i] = _folders[i].copyWith(
          parentId: parentId,
          clearParentId: parentId == null,
        );
      }
    }
    for (final entry in _memberships.entries.toList()) {
      if (entry.value == folderId) {
        if (parentId == null) {
          _memberships.remove(entry.key);
        } else {
          _memberships[entry.key] = parentId;
        }
      }
    }
    _folders.removeAt(index);
  }

  @override
  Future<String?> folderIdForProject(String projectId) async =>
      _memberships[projectId];

  @override
  Future<List<String>> projectIdsInFolder(String? folderId) async {
    if (folderId == null) return const <String>[];
    return _memberships.entries
        .where((e) => e.value == folderId)
        .map((e) => e.key)
        .toList(growable: false);
  }

  @override
  Future<void> moveProjects({
    required Iterable<String> projectIds,
    String? folderId,
  }) async {
    if (folderId != null && !_folders.any((f) => f.id == folderId)) {
      throw StateError('Unknown folder "$folderId"');
    }
    for (final id in projectIds) {
      if (folderId == null) {
        _memberships.remove(id);
      } else {
        _memberships[id] = folderId;
      }
    }
  }

  @override
  Future<void> removeProjectMembership(String projectId) async {
    _memberships.remove(projectId);
  }
}
