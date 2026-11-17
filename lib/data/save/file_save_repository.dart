import 'dart:convert';
import 'dart:io';

import 'package:anoworld/data/project/project_paths.dart';
import 'package:anoworld/domain/models/json_map.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/repositories/save_repository.dart';
import 'package:anoworld/domain/runtime/bridge_session.dart';
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

  Future<File> _slotFile(String projectId) async {
    final safe = projectId.replaceAll(RegExp(r'[^\w\-.]'), '_');
    return File(p.join(await _savesRoot(), '$safe.json'));
  }

  @override
  Future<SaveSlot?> load(String projectId) async {
    final file = await _slotFile(projectId);
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

  Future<SaveSlot> _readSlot(File file) async {
    final map = asJsonMap(
      jsonDecode(await file.readAsString()),
      path: file.path,
    );
    final bridgeMap = map.optionalMap('bridge');
    return SaveSlot(
      projectId: map.requireString('projectId'),
      pointer: MainSavePointer.fromJson(map.requireMap('pointer')),
      savedAt: DateTime.parse(map.requireString('savedAt')),
      bridge: bridgeMap == null ? null : BridgeSession.fromJson(bridgeMap),
    );
  }

  @override
  Future<void> save({
    required String projectId,
    required MainSavePointer pointer,
    BridgeSession? bridge,
  }) async {
    final file = await _slotFile(projectId);
    final payload = <String, dynamic>{
      'projectId': projectId,
      'pointer': pointer.toJson(),
      'savedAt': DateTime.now().toUtc().toIso8601String(),
      if (bridge != null) 'bridge': bridge.toJson(),
    };
    await file.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(payload)}\n',
    );
  }

  @override
  Future<void> clear(String projectId) async {
    final file = await _slotFile(projectId);
    if (await file.exists()) await file.delete();
  }
}
