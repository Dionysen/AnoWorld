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
      projectId: 'proj_rain_night',
      pointer: const MainSavePointer(nodeId: 'n2', beatId: 'b2'),
    );
    final loaded = await repo.load('proj_rain_night');
    expect(loaded, isNotNull);
    expect(loaded!.pointer.nodeId, 'n2');
    expect(loaded.pointer.beatId, 'b2');

    await repo.clear('proj_rain_night');
    expect(await repo.load('proj_rain_night'), isNull);
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
      projectId: 'proj_skeleton',
      pointer: const MainSavePointer(nodeId: 'n1', beatId: 'bridge_n1_1'),
      bridge: bridge,
    );
    final loaded = await repo.load('proj_skeleton');
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
    );
    final loaded = await repo.load('proj_chat');
    expect(loaded?.mode, PlayViewMode.chat);
    expect(loaded?.chat, hasLength(2));
    expect(loaded?.chat.first.content, '你好');
    expect(loaded?.chat.last.role, TavernChatRole.user);
  });
}
