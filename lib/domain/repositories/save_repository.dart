import 'package:anoworld/domain/chat/tavern_chat_message.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/runtime/bridge_session.dart';
import 'package:anoworld/domain/runtime/play_view_mode.dart';

class SaveSlot {
  const SaveSlot({
    required this.id,
    required this.projectId,
    required this.pointer,
    required this.savedAt,
    this.bridge,
    this.mode = PlayViewMode.visualNovel,
    this.chat = const <TavernChatMessage>[],
    this.replyChoices = const <String>[],
  });

  /// Unique slot id (one project may have many slots).
  final String id;
  final String projectId;
  final MainSavePointer pointer;
  final DateTime savedAt;
  final BridgeSession? bridge;

  /// Presentation locked when this slot was written.
  final PlayViewMode mode;

  /// Tavern chat transcript when [mode] is chat.
  final List<TavernChatMessage> chat;

  /// Pending reply chips for chat (restored with transcript).
  final List<String> replyChoices;
}

/// Per-story play progress: many slots per [SaveSlot.projectId].
abstract interface class SaveRepository {
  Future<SaveSlot?> load(String slotId);

  /// All slots, newest [SaveSlot.savedAt] first.
  Future<List<SaveSlot>> listAll();

  Future<List<SaveSlot>> listForProject(String projectId);

  Future<void> save({
    required String slotId,
    required String projectId,
    required MainSavePointer pointer,
    BridgeSession? bridge,
    PlayViewMode mode = PlayViewMode.visualNovel,
    List<TavernChatMessage> chat = const <TavernChatMessage>[],
    List<String> replyChoices = const <String>[],
  });

  Future<void> clear(String slotId);

  /// Removes every slot belonging to [projectId].
  Future<void> clearForProject(String projectId);
}
