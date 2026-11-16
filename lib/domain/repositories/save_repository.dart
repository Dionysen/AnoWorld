import 'package:anoworld/domain/models/main_story.dart';

class SaveSlot {
  const SaveSlot({
    required this.projectId,
    required this.pointer,
    required this.savedAt,
  });

  final String projectId;
  final MainSavePointer pointer;
  final DateTime savedAt;
}

/// Per-project play progress (MVP: one auto slot).
abstract interface class SaveRepository {
  Future<SaveSlot?> load(String projectId);

  Future<void> save({
    required String projectId,
    required MainSavePointer pointer,
  });

  Future<void> clear(String projectId);
}
