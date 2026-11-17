import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/runtime/bridge_session.dart';

class SaveSlot {
  const SaveSlot({
    required this.projectId,
    required this.pointer,
    required this.savedAt,
    this.bridge,
  });

  final String projectId;
  final MainSavePointer pointer;
  final DateTime savedAt;
  final BridgeSession? bridge;
}

/// Per-project play progress (MVP: one auto slot).
abstract interface class SaveRepository {
  Future<SaveSlot?> load(String projectId);

  /// All slots, newest [SaveSlot.savedAt] first.
  Future<List<SaveSlot>> listAll();

  Future<void> save({
    required String projectId,
    required MainSavePointer pointer,
    BridgeSession? bridge,
  });

  Future<void> clear(String projectId);
}
