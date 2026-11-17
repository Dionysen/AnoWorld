import 'package:anoworld/domain/models/project_folder.dart';

/// Library folders and which works sit in which folder (root = null).
abstract interface class ProjectFolderRepository {
  Future<List<ProjectFolder>> listFolders({String? parentId});

  Future<ProjectFolder?> getFolder(String folderId);

  /// Ancestor chain from root → [folderId] (excluding a synthetic root).
  Future<List<ProjectFolder>> breadcrumbs(String folderId);

  Future<ProjectFolder> createFolder({
    required String name,
    String? parentId,
  });

  Future<void> renameFolder({required String folderId, required String name});

  /// Move folder under [parentId] (null = library root).
  Future<void> moveFolder({required String folderId, String? parentId});

  /// Delete folder and its descendant folders; members return to root.
  Future<void> deleteFolder(String folderId);

  /// Delete folder only; child folders + works move to this folder's parent.
  Future<void> dissolveFolder(String folderId);

  /// Folder id for [projectId], or null when at library root.
  Future<String?> folderIdForProject(String projectId);

  Future<List<String>> projectIdsInFolder(String? folderId);

  Future<void> moveProjects({
    required Iterable<String> projectIds,
    String? folderId,
  });

  Future<void> removeProjectMembership(String projectId);
}
