import 'package:anoworld/domain/chat/tavern_chat_message.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/repositories/save_repository.dart';
import 'package:anoworld/domain/runtime/bridge_session.dart';
import 'package:anoworld/domain/runtime/play_view_mode.dart';

class MemorySaveRepository implements SaveRepository {
  MemorySaveRepository({Map<String, SaveSlot>? seed})
      : _slots = Map<String, SaveSlot>.from(seed ?? const {});

  final Map<String, SaveSlot> _slots;

  @override
  Future<SaveSlot?> load(String projectId) async => _slots[projectId];

  @override
  Future<List<SaveSlot>> listAll() async {
    final list = _slots.values.toList(growable: false);
    return list..sort((a, b) => b.savedAt.compareTo(a.savedAt));
  }

  @override
  Future<void> save({
    required String projectId,
    required MainSavePointer pointer,
    BridgeSession? bridge,
    PlayViewMode mode = PlayViewMode.visualNovel,
    List<TavernChatMessage> chat = const <TavernChatMessage>[],
    List<String> replyChoices = const <String>[],
  }) async {
    _slots[projectId] = SaveSlot(
      projectId: projectId,
      pointer: pointer,
      savedAt: DateTime.now().toUtc(),
      bridge: bridge,
      mode: mode,
      chat: List<TavernChatMessage>.unmodifiable(chat),
      replyChoices: List<String>.unmodifiable(replyChoices),
    );
  }

  @override
  Future<void> clear(String projectId) async {
    _slots.remove(projectId);
  }
}
