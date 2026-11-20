import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/repositories/project_repository.dart';

/// Read-modify-write against the newest stored story.
///
/// Editor pages work on an in-memory [Project]. Another writer (the create
/// assistant, a second editor, an import) may have saved the story since this
/// page opened it, so writing that stale copy back as-is would wipe the other
/// layer. Every writer re-reads first and replaces only the layers it owns.
Future<Project> saveProjectMerged(
  ProjectRepository repo,
  String projectId,
  Project Function(Project latest) update,
) async {
  final latest = await repo.open(projectId);
  final next = update(latest);
  final stamped = next.copyWith(
    meta: next.meta.copyWith(updatedAt: DateTime.now().toUtc()),
  );
  await repo.save(stamped);
  return stamped;
}
