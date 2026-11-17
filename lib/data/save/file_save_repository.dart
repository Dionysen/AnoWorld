import 'dart:convert';
import 'dart:io';

import 'package:anoworld/data/project/project_paths.dart';
import 'package:anoworld/domain/chat/tavern_chat_message.dart';
import 'package:anoworld/domain/models/json_map.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/repositories/save_repository.dart';
import 'package:anoworld/domain/runtime/bridge_session.dart';
import 'package:anoworld/domain/runtime/play_view_mode.dart';
import 'package:path/path.dart' as p;

class FileSaveRepository implements SaveRepository {
  FileSaveRepository({ProjectPaths? paths}) : _paths = paths ?? ProjectPaths();

  static const String savesFolder = 'saves';

  final ProjectPaths _paths;

  Future<String> _savesRoot() async {
    final root = p.join(await _paths.libraryRoot(), savesFolder);
    await Directory(root).create(recursive: true);
    return root;
  }

  String _safeName(String id) => id.replaceAll(RegExp(r'[^\w\-.]'), '_');

  Future<File> _slotFile(String slotId) async {
    return File(p.join(await _savesRoot(), '${_safeName(slotId)}.json'));
  }

  @override
  Future<SaveSlot?> load(String slotId) async {
    final file = await _slotFile(slotId);
    if (!await file.exists()) return null;
    return _readSlot(file);
  }

  @override
  Future<List<SaveSlot>> listAll() async {
    final root = Directory(await _savesRoot());
    if (!await root.exists()) return const <SaveSlot>[];
    final slots = <SaveSlot>[];
    await for (final entity in root.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        slots.add(await _readSlot(entity));
      } on Object {
        // Skip corrupt slots.
      }
    }
    slots.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return slots;
  }

  @override
  Future<List<SaveSlot>> listForProject(String projectId) async {
    final all = await listAll();
    return all
        .where((s) => s.projectId == projectId)
        .toList(growable: false);
  }

  Future<SaveSlot> _readSlot(File file) async {
    final map = asJsonMap(
      jsonDecode(await file.readAsString()),
      path: file.path,
    );
    final bridgeMap = map.optionalMap('bridge');
    final chatRaw = map.optionalList('chat');
    final choicesRaw = map.optionalList('replyChoices');
    final projectId = map.requireString('projectId');
    // Legacy one-file-per-project used the project id as the filename.
    final id = map.optionalString('id') ??
        p.basenameWithoutExtension(file.path);
    return SaveSlot(
      id: id,
      projectId: projectId,
      pointer: MainSavePointer.fromJson(map.requireMap('pointer')),
      savedAt: DateTime.parse(map.requireString('savedAt')),
      bridge: bridgeMap == null ? null : BridgeSession.fromJson(bridgeMap),
      mode: PlayViewModeCodec.parse(map.optionalString('mode')),
      chat: chatRaw
          .map(
            (item) => TavernChatMessage.fromJson(
              asJsonMap(item, path: 'chat[]'),
            ),
          )
          .toList(growable: false),
      replyChoices: choicesRaw
          .map((item) => '$item'.trim())
          .where((s) => s.isNotEmpty)
          .toList(growable: false),
    );
  }

  @override
  Future<void> save({
    required String slotId,
    required String projectId,
    required MainSavePointer pointer,
    BridgeSession? bridge,
    PlayViewMode mode = PlayViewMode.visualNovel,
    List<TavernChatMessage> chat = const <TavernChatMessage>[],
    List<String> replyChoices = const <String>[],
  }) async {
    final file = await _slotFile(slotId);
    final payload = <String, dynamic>{
      'id': slotId,
      'projectId': projectId,
      'pointer': pointer.toJson(),
      'savedAt': DateTime.now().toUtc().toIso8601String(),
      'mode': mode.wireName,
      if (bridge != null) 'bridge': bridge.toJson(),
      if (chat.isNotEmpty)
        'chat': chat.map((m) => m.toJson()).toList(growable: false),
      if (replyChoices.isNotEmpty) 'replyChoices': replyChoices,
    };
    await file.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(payload)}\n',
    );
  }

  @override
  Future<void> clear(String slotId) async {
    final file = await _slotFile(slotId);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<void> clearForProject(String projectId) async {
    final slots = await listForProject(projectId);
    for (final slot in slots) {
      await clear(slot.id);
    }
  }
}
