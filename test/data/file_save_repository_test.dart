import 'dart:io';

import 'package:anoworld/data/project/project_paths.dart';
import 'package:anoworld/data/save/file_save_repository.dart';
import 'package:anoworld/domain/chat/tavern_chat_message.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/runtime/bridge_session.dart';
import 'package:anoworld/domain/runtime/play_view_mode.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('file save repository round-trips a slot', () async {
    final temp = await Directory.systemTemp.createTemp('anoworld_saves_');
    addTearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    final paths = ProjectPaths(documentsDirectory: () async => temp);
    paths.seedLibraryRoot(p.join(temp.path, 'AnoWorld'));
    final repo = FileSaveRepository(paths: paths);

    await repo.save(
      slotId: 'slot_a',
      projectId: 'proj_rain_night',
      pointer: const MainSavePointer(nodeId: 'n2', beatId: 'b2'),
    );
    final loaded = await repo.load('slot_a');
    expect(loaded, isNotNull);
    expect(loaded!.id, 'slot_a');
    expect(loaded.projectId, 'proj_rain_night');
    expect(loaded.pointer.nodeId, 'n2');
    expect(loaded.pointer.beatId, 'b2');

    await repo.clear('slot_a');
    expect(await repo.load('slot_a'), isNull);
  });

  test('file save repository round-trips bridge session', () async {
    final temp = await Directory.systemTemp.createTemp('anoworld_saves_bridge_');
    addTearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    final paths = ProjectPaths(documentsDirectory: () async => temp);
    paths.seedLibraryRoot(p.join(temp.path, 'AnoWorld'));
    final repo = FileSaveRepository(paths: paths);

    const bridge = BridgeSession(
      nodeId: 'n1',
      turnCount: 1,
      summary: '雨还在下',
      generatedBeats: [
        Beat(
          id: 'bridge_n1_1',
          nodeId: 'n1',
          scene: Scene(),
          appearances: [],
          lines: [
            DialogueLine(
              id: 'l0',
              text: '雨还在下。',
              kind: DialogueKind.narration,
            ),
          ],
          choices: [
            Choice(
              id: 'c0',
              text: '前往：客栈',
              target: Transition(type: TransitionType.node, nodeId: 'n2'),
            ),
          ],
        ),
      ],
    );

    await repo.save(
      slotId: 'slot_bridge',
      projectId: 'proj_skeleton',
      pointer: const MainSavePointer(nodeId: 'n1', beatId: 'bridge_n1_1'),
      bridge: bridge,
    );
    final loaded = await repo.load('slot_bridge');
    expect(loaded?.bridge?.nodeId, 'n1');
    expect(loaded?.bridge?.turnCount, 1);
    expect(loaded?.bridge?.generatedBeats.single.id, 'bridge_n1_1');
  });

  test('file save repository round-trips chat transcript', () async {
    final temp = await Directory.systemTemp.createTemp('anoworld_saves_chat_');
    addTearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    final paths = ProjectPaths(documentsDirectory: () async => temp);
    paths.seedLibraryRoot(p.join(temp.path, 'AnoWorld'));
    final repo = FileSaveRepository(paths: paths);

    await repo.save(
      slotId: 'slot_chat',
      projectId: 'proj_chat',
      pointer: const MainSavePointer(nodeId: 'n1', beatId: ''),
      mode: PlayViewMode.chat,
      chat: const [
        TavernChatMessage(
          id: 'a1',
          role: TavernChatRole.assistant,
          content: '你好',
        ),
        TavernChatMessage(
          id: 'u1',
          role: TavernChatRole.user,
          content: '在吗',
        ),
      ],
      replyChoices: const ['走近', '先问问'],
    );
    final loaded = await repo.load('slot_chat');
    expect(loaded?.mode, PlayViewMode.chat);
    expect(loaded?.chat, hasLength(2));
    expect(loaded?.chat.first.content, '你好');
    expect(loaded?.chat.last.role, TavernChatRole.user);
    expect(loaded?.replyChoices, ['走近', '先问问']);
  });

  test('one project can keep multiple slots', () async {
    final temp = await Directory.systemTemp.createTemp('anoworld_saves_multi_');
    addTearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    final paths = ProjectPaths(documentsDirectory: () async => temp);
    paths.seedLibraryRoot(p.join(temp.path, 'AnoWorld'));
    final repo = FileSaveRepository(paths: paths);

    await repo.save(
      slotId: 'slot_1',
      projectId: 'proj_x',
      pointer: const MainSavePointer(nodeId: 'n1', beatId: 'b1'),
      mode: PlayViewMode.chat,
    );
    await repo.save(
      slotId: 'slot_2',
      projectId: 'proj_x',
      pointer: const MainSavePointer(nodeId: 'n2', beatId: 'b2'),
      mode: PlayViewMode.visualNovel,
    );
    await repo.save(
      slotId: 'slot_other',
      projectId: 'proj_y',
      pointer: const MainSavePointer(nodeId: 'n1', beatId: 'b1'),
    );

    final forX = await repo.listForProject('proj_x');
    expect(forX.map((s) => s.id), containsAll(['slot_1', 'slot_2']));
    expect(forX, hasLength(2));

    await repo.clearForProject('proj_x');
    expect(await repo.listForProject('proj_x'), isEmpty);
    expect(await repo.load('slot_other'), isNotNull);
  });

  test('legacy file without id field uses filename as id', () async {
    final temp = await Directory.systemTemp.createTemp('anoworld_saves_legacy_');
    addTearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    final paths = ProjectPaths(documentsDirectory: () async => temp);
    final root = p.join(temp.path, 'AnoWorld', 'saves');
    await Directory(root).create(recursive: true);
    paths.seedLibraryRoot(p.join(temp.path, 'AnoWorld'));

    final legacy = File(p.join(root, 'proj_legacy.json'));
    await legacy.writeAsString('''
{
  "projectId": "proj_legacy",
  "pointer": {"nodeId": "n1", "beatId": "b1"},
  "savedAt": "2026-01-02T00:00:00.000Z",
  "mode": "chat"
}
''');

    final repo = FileSaveRepository(paths: paths);
    final loaded = await repo.load('proj_legacy');
    expect(loaded?.id, 'proj_legacy');
    expect(loaded?.projectId, 'proj_legacy');
    expect(loaded?.mode, PlayViewMode.chat);
  });
}
