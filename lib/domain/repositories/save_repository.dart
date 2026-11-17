import 'package:anoworld/domain/chat/tavern_chat_message.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/runtime/bridge_session.dart';
import 'package:anoworld/domain/runtime/play_view_mode.dart';

class SaveSlot {
  const SaveSlot({
    required this.projectId,
    required this.pointer,
    required this.savedAt,
    this.bridge,
    this.mode = PlayViewMode.visualNovel,
    this.chat = const <TavernChatMessage>[],
  });

  final String projectId;
  final MainSavePointer pointer;
  final DateTime savedAt;
  final BridgeSession? bridge;

  /// Presentation locked when this slot was written.
  final PlayViewMode mode;

  /// Tavern chat transcript when [mode] is chat.
  final List<TavernChatMessage> chat;
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
    PlayViewMode mode = PlayViewMode.visualNovel,
    List<TavernChatMessage> chat = const <TavernChatMessage>[],
  });

  Future<void> clear(String projectId);
}
