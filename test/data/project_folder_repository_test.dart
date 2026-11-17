import 'package:anoworld/data/folder/memory_project_folder_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('create nest move dissolve and delete folders', () async {
    var n = 0;
    final repo = MemoryProjectFolderRepository(
      idGenerator: () {
        n += 1;
        return 'f$n';
      },
    );
    final root = await repo.createFolder(name: '旅途');
    expect(root.parentId, isNull);

    final nested = await repo.createFolder(name: '支线', parentId: root.id);
    expect(nested.parentId, root.id);

    await repo.moveProjects(projectIds: const ['p1', 'p2'], folderId: root.id);
    expect(await repo.folderIdForProject('p1'), root.id);
    expect(await repo.projectIdsInFolder(root.id), ['p1', 'p2']);

    await repo.dissolveFolder(root.id);
    expect(await repo.getFolder(root.id), isNull);
    expect(await repo.folderIdForProject('p1'), isNull);
    final children = await repo.listFolders();
    expect(children.single.name, '支线');
    expect(children.single.parentId, isNull);

    await repo.deleteFolder(children.single.id);
    expect(await repo.listFolders(), isEmpty);
  });

  test('breadcrumbs walk ancestors', () async {
    var n = 0;
    final repo = MemoryProjectFolderRepository(
      idGenerator: () {
        n += 1;
        return 'f$n';
      },
    );
    final a = await repo.createFolder(name: 'A');
    final b = await repo.createFolder(name: 'B', parentId: a.id);
    final c = await repo.createFolder(name: 'C', parentId: b.id);
    final crumbs = await repo.breadcrumbs(c.id);
    expect(crumbs.map((f) => f.name).toList(), ['A', 'B', 'C']);
  });
}
