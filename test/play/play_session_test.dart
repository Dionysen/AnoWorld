import 'dart:async';
import 'dart:io';

import 'package:anoworld/data/project/memory_project_repository.dart';
import 'package:anoworld/data/project/project_asset_files.dart';
import 'package:anoworld/data/save/memory_save_repository.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/models/project_asset.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:anoworld/domain/repositories/save_repository.dart';
import 'package:anoworld/domain/runtime/bridge_session.dart';
import 'package:anoworld/domain/runtime/play_view_mode.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/domain/settings/vn_ui_settings.dart';
import 'package:anoworld/foundation/ai/st_ai_preset.dart';
import 'package:anoworld/foundation/widgets/app_busy_indicator.dart';
import 'package:anoworld/foundation/widgets/app_dialogue_panel.dart';
import 'package:anoworld/foundation/widgets/app_switch.dart';
import 'package:anoworld/play/play_session_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

class _QueuedTextClient implements AiTextClient {
  _QueuedTextClient(this._replies);

  final List<String> _replies;
  int calls = 0;
  final List<Completer<void>> _gates = <Completer<void>>[];

  /// Release the next pending model reply (FIFO).
  void releaseNext() {
    if (_gates.isEmpty) return;
    _gates.removeAt(0).complete();
  }

  @override
  Future<AiTextCompletion> complete({
    required AiTextEndpoint endpoint,
    required String system,
    required String user,
    GenerationPreset? generation,
  }) async {
    final gate = Completer<void>();
    _gates.add(gate);
    await gate.future;
    if (calls >= _replies.length) {
      throw AiTextException('no more replies');
    }
    return AiTextCompletion(content: _replies[calls++]);
  }
}

/// Serves linear beat JSON or a branch-batch payload (echoing choiceIds).
class _VnPrefetchClient implements AiTextClient {
  _VnPrefetchClient(this._beatTexts);

  final List<String> _beatTexts;
  int _textIndex = 0;
  int calls = 0;
  final List<Completer<void>> _gates = <Completer<void>>[];

  void releaseNext() {
    if (_gates.isEmpty) return;
    _gates.removeAt(0).complete();
  }

  String _nextText() {
    if (_textIndex >= _beatTexts.length) {
      throw AiTextException('no more beat texts');
    }
    return _beatTexts[_textIndex++];
  }

  @override
  Future<AiTextCompletion> complete({
    required AiTextEndpoint endpoint,
    required String system,
    required String user,
    GenerationPreset? generation,
  }) async {
    final gate = Completer<void>();
    _gates.add(gate);
    await gate.future;
    calls++;
    if (user.contains('请为下列选项各写')) {
      final ids = RegExp(r'choiceId:(\S+)')
          .allMatches(user)
          .map((m) => m.group(1)!)
          .toList(growable: false);
      final branches = [
        for (final id in ids)
          '{"choiceId":"$id","beat":${_beatJson(_nextText())}}',
      ];
      return AiTextCompletion(content: '{"branches":[${branches.join(",")}]}');
    }
    return AiTextCompletion(content: _beatJson(_nextText()));
  }
}

String _beatJson(String text, {bool stay = true}) {  final choice = stay
      ? '{"text":"继续","target":{"type":"beat","beatId":"__stay__"}}'
      : '{"text":"结束","target":{"type":"end"}}';
  return '{"location":"室内","lines":[{"speaker":"旁白","text":"$text"}],'
      '"choices":[$choice]}';
}

void main() {
  final sample = const ProjectFactory().createRainNightSample(
    now: DateTime.utc(2026, 1, 1),
  );

  final skeleton = const ProjectFactory()
      .createBlank(id: 'p_skel', title: '骨架', now: DateTime.utc(2026, 1, 1))
      .copyWith(
        main: const MainStory(
          summary: '短主线',
          startNodeId: 'n1',
          nodes: [
            StoryNode(
              id: 'n1',
              title: '城门',
              synopsis: '离开',
              beatIds: [],
            ),
            StoryNode(
              id: 'n2',
              title: '客栈',
              synopsis: '投宿',
              beatIds: [],
              tags: ['ending'],
            ),
          ],
          edges: [
            StoryEdge(
              id: 'e1',
              from: 'n1',
              to: 'n2',
              kind: EdgeKind.defaultEdge,
            ),
          ],
          beats: [],
        ),
      );

  final long = sample.copyWith(
    main: sample.main.copyWith(
      beats: [
        Beat(
          id: 'b1',
          nodeId: 'n1',
          scene: sample.main.beats.first.scene,
          appearances: sample.main.beats.first.appearances,
          lines: const [
            DialogueLine(id: 'l1', text: '一', kind: DialogueKind.narration),
            DialogueLine(id: 'l2', text: '二', kind: DialogueKind.narration),
            DialogueLine(id: 'l3', text: '三', kind: DialogueKind.narration),
            DialogueLine(id: 'l4', text: '四', kind: DialogueKind.narration),
          ],
          choices: const [],
        ),
        sample.main.beats[1],
      ],
    ),
  );

  Future<void> pumpLongPlay(WidgetTester tester) async {
    await tester.pumpWidget(
      testScoped(
        home: PlaySessionPage(
          project: long,
          mode: PlayViewMode.visualNovel,
          resumeSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpPlay(
    WidgetTester tester, {
    PlayViewMode mode = PlayViewMode.visualNovel,
  }) async {
    await tester.pumpWidget(
      testScoped(
        home: PlaySessionPage(
          project: sample,
          mode: mode,
          resumeSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('VN play reaches choices then can end', (tester) async {
    await pumpPlay(tester);

    expect(find.text('该走了。'), findsOneWidget);
    expect(find.text('继续'), findsNothing);
    await tester.tap(find.text('该走了。'));
    await tester.pumpAndSettle();

    expect(find.text('留宿？'), findsOneWidget);
    await tester.tap(find.text('留宿？'));
    await tester.pumpAndSettle();

    expect(find.text('住下'), findsOneWidget);
    expect(find.text('再看看'), findsOneWidget);

    await tester.tap(find.text('住下'));
    await tester.pumpAndSettle();
    expect(find.text('本段结束'), findsOneWidget);
  });

  testWidgets('VN history bar steps back and forward', (tester) async {
    await pumpPlay(tester);

    expect(find.text('该走了。'), findsOneWidget);
    await tester.tap(find.text('该走了。'));
    await tester.pumpAndSettle();
    expect(find.text('留宿？'), findsOneWidget);

    await tester.tap(find.byTooltip('后退'));
    await tester.pumpAndSettle();
    expect(find.text('该走了。'), findsOneWidget);
    expect(find.text('留宿？'), findsNothing);

    await tester.tap(find.byTooltip('前进'));
    await tester.pumpAndSettle();
    expect(find.text('留宿？'), findsOneWidget);
  });

  testWidgets('VN forward keeps going at the newest line', (tester) async {
    await pumpLongPlay(tester);

    // Walk the four lines of the opening beat.
    await tester.tap(find.text('一'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('二'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('三'));
    await tester.pumpAndSettle();
    expect(find.text('四'), findsOneWidget);

    // Newest progress, but the story can still continue: forward works.
    await tester.tap(find.byTooltip('前进'));
    await tester.pumpAndSettle();
    expect(find.text('留宿？'), findsOneWidget);

    await tester.tap(find.byTooltip('前进'));
    await tester.pumpAndSettle();
    expect(find.text('住下'), findsOneWidget);
  });

  testWidgets('VN back from a choices prompt shows the previous line',
      (tester) async {
    await pumpLongPlay(tester);

    await tester.tap(find.text('一'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('二'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('三'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('四'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('留宿？'));
    await tester.pumpAndSettle();
    expect(find.text('住下'), findsOneWidget);

    await tester.tap(find.byTooltip('后退'));
    await tester.pumpAndSettle();
    expect(find.text('住下'), findsNothing);
    expect(find.text('四'), findsOneWidget);

    await tester.tap(find.byTooltip('后退'));
    await tester.pumpAndSettle();
    expect(find.text('三'), findsOneWidget);

    // Forward replays into the choices prompt again.
    await tester.tap(find.byTooltip('前进'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('前进'));
    await tester.pumpAndSettle();
    expect(find.text('住下'), findsOneWidget);
  });

  testWidgets('VN fast-forward stops at the newest progress', (tester) async {
    await pumpLongPlay(tester);

    await tester.tap(find.text('一'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('二'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('三'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('四'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('留宿？'));
    await tester.pumpAndSettle();
    expect(find.text('住下'), findsOneWidget);

    await tester.tap(find.byTooltip('后退'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('后退'));
    await tester.pumpAndSettle();
    expect(find.text('三'), findsOneWidget);

    await tester.tap(find.byTooltip('快进'));
    await tester.pumpAndSettle();

    expect(find.text('住下'), findsOneWidget);
    expect(find.text('再看看'), findsOneWidget);
    expect(find.byIcon(Icons.pause_rounded), findsNothing);
  });

  testWidgets('rewind keeps the newest progress in the save slot',
      (tester) async {
    final saves = MemorySaveRepository();
    await tester.pumpWidget(
      testScoped(
        saves: saves,
        home: PlaySessionPage(
          key: UniqueKey(),
          project: sample,
          mode: PlayViewMode.visualNovel,
          resumeSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('该走了。'));
    await tester.pumpAndSettle();
    expect(find.text('留宿？'), findsOneWidget);
    await tester.tap(find.byTooltip('后退'));
    await tester.pumpAndSettle();
    expect(find.text('该走了。'), findsOneWidget);

    final slot = (await saves.listForProject(sample.meta.id)).single;
    expect(slot.history.length, greaterThanOrEqualTo(2));
    expect(slot.historyCursor, 0);
    expect(slot.history.last.beatId, 'b2');

    // Reopen the same slot: still on the rewound line, newest progress kept.
    await tester.pumpWidget(
      testScoped(
        saves: saves,
        home: PlaySessionPage(
          key: UniqueKey(),
          project: sample,
          mode: PlayViewMode.visualNovel,
          slotId: slot.id,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('该走了。'), findsOneWidget);

    await tester.tap(find.byTooltip('前进'));
    await tester.pumpAndSettle();
    expect(find.text('留宿？'), findsOneWidget);
  });

  testWidgets('chat mode shows tavern composer shell', (tester) async {
    await pumpPlay(tester, mode: PlayViewMode.chat);    expect(find.text('输入消息'), findsOneWidget);
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    expect(find.byTooltip('选择模型'), findsOneWidget);
    expect(find.byTooltip('聊天设置'), findsOneWidget);
    expect(find.byTooltip('重新开始'), findsNothing);
    expect(find.text(sample.meta.title), findsWidgets);
    expect(find.text('该走了。'), findsNothing);
  });

  testWidgets('chat opening autosaves a slot with mode', (tester) async {
    final saves = MemorySaveRepository();
    await tester.pumpWidget(
      testScoped(
        saves: saves,
        home: PlaySessionPage(
          project: sample,
          mode: PlayViewMode.chat,
          resumeSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('保存进度'), findsNothing);
    final slots = await saves.listForProject(sample.meta.id);
    expect(slots, isNotEmpty);
    expect(slots.first.mode, PlayViewMode.chat);
    expect(slots.first.pointer.beatId, 'b1');
  });

  testWidgets('empty skeleton still offers guaranteed next station',
      (tester) async {
    await tester.pumpWidget(
      testScoped(
        home: PlaySessionPage(
          project: skeleton,
          mode: PlayViewMode.visualNovel,
          resumeSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Bridge fallback appears as narration; tap to reach choices.
    expect(find.text('继续'), findsNothing);
    expect(find.text('正在写这一段…'), findsNothing);
    await tester.tap(find.textContaining('请先').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('前往：客栈'), findsWidgets);
    await tester.tap(find.text('前往：客栈').first);
    await tester.pumpAndSettle();
    expect(find.text('本段结束'), findsOneWidget);
  });

  testWidgets('VN branch-prefetches when tip has choices; spinner only in title',
      (tester) async {
    final blank = const ProjectFactory().createBlank(
      id: 'p_prefetch',
      title: '预写',
      now: DateTime.utc(2026, 1, 1),
    );
    final client = _VnPrefetchClient([
      '第一拍。',
      '第二拍。',
      '第三拍。',
    ]);
    final settings = testSettingsController();
    await settings.updateAi(
      settings.ai.copyWith(
        text: const AiTextEndpoint(
          kind: AiTextProviderKind.openAiCompatible,
          baseUrl: 'http://localhost:8080/v1',
          apiKey: 'sk-test',
          model: 'demo',
        ),
        minBridgeLines: 1,
        inStationChoiceFrequency: InStationChoiceFrequency.often,
      ),
    );
    final saves = MemorySaveRepository();

    await tester.pumpWidget(
      testScoped(
        settings: settings,
        textClient: client,
        saves: saves,
        home: PlaySessionPage(
          project: blank,
          mode: PlayViewMode.visualNovel,
          resumeSave: false,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AppBusyIndicator), findsOneWidget);
    expect(find.text('正在写这一段…'), findsNothing);

    // Adopt first beat.
    client.releaseNext();
    await tester.pump();
    await tester.pump();

    expect(find.text('第一拍。'), findsOneWidget);
    expect(find.byType(AppBusyIndicator), findsOneWidget);

    // Tip has choices → one branch-batch call (not two linear beats).
    client.releaseNext();
    await tester.pump();
    await tester.pump();

    expect(client.calls, 2);
    expect(find.byType(AppBusyIndicator), findsNothing);

    final slotsAfterPrefetch = await saves.listForProject(blank.meta.id);
    expect(slotsAfterPrefetch, isNotEmpty);
    expect(slotsAfterPrefetch.first.bridge?.branchEdges, isNotEmpty);

    await tester.tap(find.text('第一拍。'));
    await tester.pump();
    await tester.pump();
    expect(find.text('继续'), findsOneWidget);

    await tester.tap(find.text('继续'));
    await tester.pump();
    await tester.pump();
    expect(find.text('第二拍。'), findsOneWidget);
    // After adopt, tip again has choices → another branch batch starts.
    expect(find.byType(AppBusyIndicator), findsOneWidget);

    client.releaseNext();
    await tester.pump();
    await tester.pump();
    expect(client.calls, 3);
  });

  testWidgets('VN regenerate prunes subtree and writes a new beat',
      (tester) async {
    final blank = const ProjectFactory().createBlank(
      id: 'p_regen',
      title: '重写',
      now: DateTime.utc(2026, 1, 1),
    );
    final client = _VnPrefetchClient([
      '旧拍。',
      '分支拍。',
      '新拍。',
      '新分支。',
    ]);
    final settings = testSettingsController();
    await settings.updateAi(
      settings.ai.copyWith(
        text: const AiTextEndpoint(
          kind: AiTextProviderKind.openAiCompatible,
          baseUrl: 'http://localhost:8080/v1',
          apiKey: 'sk-test',
          model: 'demo',
        ),
        minBridgeLines: 1,
        inStationChoiceFrequency: InStationChoiceFrequency.often,
      ),
    );
    final saves = MemorySaveRepository();

    await tester.pumpWidget(
      testScoped(
        settings: settings,
        textClient: client,
        saves: saves,
        home: PlaySessionPage(
          project: blank,
          mode: PlayViewMode.visualNovel,
          resumeSave: false,
        ),
      ),
    );
    await tester.pump();

    client.releaseNext();
    await tester.pump();
    await tester.pump();
    // Branch batch for the tip with choices.
    client.releaseNext();
    await tester.pump();
    await tester.pump();

    expect(find.text('旧拍。'), findsOneWidget);
    expect(client.calls, 2);

    final regen = find.byTooltip('重新生成');
    expect(regen, findsOneWidget);
    await tester.tap(regen);
    await tester.pump();

    expect(find.text('旧拍。'), findsNothing);
    expect(find.byType(AppBusyIndicator), findsOneWidget);

    client.releaseNext();
    await tester.pump();
    await tester.pump();
    expect(find.text('新拍。'), findsOneWidget);

    // Branch refill after regenerate.
    client.releaseNext();
    await tester.pump();
    await tester.pump();

    expect(client.calls, greaterThanOrEqualTo(3));
    final slots = await saves.listForProject(blank.meta.id);
    expect(slots, isNotEmpty);
    expect(slots.first.bridge?.generatedBeats, isNotEmpty);
    expect(
      slots.first.bridge!.generatedBeats
          .any((b) => b.lines.first.text == '新拍。'),
      isTrue,
    );
  });

  testWidgets('VN narration omits speaker label and uses italic body',
      (tester) async {
    final withNarration = sample.copyWith(
      main: sample.main.copyWith(
        beats: [
          Beat(
            id: 'b1',
            nodeId: 'n1',
            scene: sample.main.beats.first.scene,
            appearances: sample.main.beats.first.appearances,
            lines: const [
              DialogueLine(
                id: 'l_n',
                text: '雨还在下。',
                kind: DialogueKind.narration,
              ),
            ],
            choices: const [],
          ),
          sample.main.beats[1],
        ],
      ),
    );
    await tester.pumpWidget(
      testScoped(
        home: PlaySessionPage(
          project: withNarration,
          mode: PlayViewMode.visualNovel,
          resumeSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('旁白'), findsNothing);
    expect(find.text('雨还在下。'), findsOneWidget);
    final body = tester.widget<Text>(find.text('雨还在下。'));
    expect(body.style?.fontStyle, FontStyle.italic);
  });

  testWidgets('VN stage fits a very small viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpPlay(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('该走了。'), findsOneWidget);
  });

  testWidgets('VN hides the title bar and keeps controls under the box', (
    tester,
  ) async {
    await pumpPlay(tester);

    expect(find.text(sample.meta.title), findsNothing);
    expect(find.byTooltip('返回'), findsOneWidget);
    expect(find.byTooltip('游玩设置'), findsOneWidget);
    expect(find.byTooltip('重新生成'), findsOneWidget);
  });

  testWidgets('VN pages a long line before advancing', (tester) async {
    final paged = sample.copyWith(
      main: sample.main.copyWith(
        beats: [
          Beat(
            id: 'b1',
            nodeId: 'n1',
            scene: sample.main.beats.first.scene,
            appearances: sample.main.beats.first.appearances,
            lines: [
              DialogueLine(
                id: 'l_long',
                text: '雨还在下，' * 40,
                kind: DialogueKind.narration,
              ),
              const DialogueLine(
                id: 'l_next',
                text: '第二句。',
                kind: DialogueKind.narration,
              ),
            ],
            choices: const [],
          ),
          sample.main.beats[1],
        ],
      ),
    );
    await tester.pumpWidget(
      testScoped(
        home: PlaySessionPage(
          project: paged,
          mode: PlayViewMode.visualNovel,
          resumeSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('第二句。'), findsNothing);
    final boxHeight = tester.getSize(find.byType(AppDialoguePanel)).height;

    await tester.tap(find.textContaining('雨还在下').first);
    await tester.pumpAndSettle();

    expect(find.text('2/2'), findsOneWidget);
    expect(find.text('第二句。'), findsNothing);
    expect(tester.getSize(find.byType(AppDialoguePanel)).height, boxHeight);

    await tester.tap(find.textContaining('雨还在下').first);
    await tester.pumpAndSettle();

    expect(find.text('第二句。'), findsOneWidget);
    expect(tester.getSize(find.byType(AppDialoguePanel)).height, boxHeight);
  });

  testWidgets('VN settings opens from the control bar', (tester) async {
    final settings = testSettingsController();
    await tester.pumpWidget(
      testScoped(
        settings: settings,
        home: PlaySessionPage(
          project: sample,
          mode: PlayViewMode.visualNovel,
          resumeSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('游玩设置'));
    await tester.pumpAndSettle();

    expect(find.text('对话框'), findsWidgets);
    expect(find.text('行数'), findsOneWidget);
    expect(find.text('字号'), findsOneWidget);
    expect(find.text('不透明度'), findsOneWidget);
    expect(find.text('背景颜色'), findsOneWidget);
    expect(find.text('文字颜色'), findsOneWidget);

    // First switch is the background follow-theme row.
    await tester.tap(find.byType(AppSwitch).first);
    await tester.pumpAndSettle();
    expect(settings.vnUi.followsTheme, isFalse);
    expect(settings.vnUi.textFollowsTheme, isTrue);
  });

  testWidgets('VN backdrop covers the whole page, chrome included', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(top: 44);
    addTearDown(tester.view.resetPadding);

    await pumpPlay(tester);

    final backdrop = tester.getRect(find.byKey(vnBackdropKey));
    expect(backdrop.top, 0);
    expect(
      backdrop.bottom,
      tester.view.physicalSize.height / tester.view.devicePixelRatio,
    );
    // The reading box still starts below the status band.
    expect(
      tester.getTopLeft(find.byType(AppDialoguePanel)).dy,
      greaterThanOrEqualTo(44),
    );
  });

  testWidgets('VN text colour overrides the theme body colour', (tester) async {
    final settings = testSettingsController();
    await settings.updateVnUi(const VnUiSettings(textHex: '#FF3366'));
    await tester.pumpWidget(
      testScoped(
        settings: settings,
        home: PlaySessionPage(
          project: sample,
          mode: PlayViewMode.visualNovel,
          resumeSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final body = tester.widget<Text>(find.text('该走了。'));
    expect(body.style?.color, const Color(0xFFFF3366));
  });

  testWidgets('VN keeps the station background after resuming a slot', (
    tester,
  ) async {
    final dir = Directory.systemTemp.createTempSync('aw_vn_stage_bg');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File(ProjectAssetFiles.absolutePath(dir.path, 'bg.png'));
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(_tinyPng);

    // Station-owned art: strip beat-level backgrounds so only the node's
    // station image can satisfy the stage.
    final staged = sample.copyWith(
      assets: const [
        ProjectAsset(
          id: 'a_bg',
          kind: ProjectAssetKind.background,
          relativePath: 'bg.png',
        ),
      ],
      main: sample.main.copyWith(
        nodes: [
          for (final node in sample.main.nodes)
            node.id == 'n1'
                ? node.copyWith(backgroundAssetId: 'a_bg')
                : node,
        ],
        beats: [
          for (final beat in sample.main.beats)
            beat.copyWith(
              scene: Scene(locationText: beat.scene.locationText),
            ),
        ],
      ),
    );

    final saves = MemorySaveRepository(
      seed: {
        'slot_bg': SaveSlot(
          id: 'slot_bg',
          projectId: staged.meta.id,
          pointer: const MainSavePointer(nodeId: 'n1', beatId: 'b_ai'),
          savedAt: DateTime.utc(2026, 1, 2),
          bridge: const BridgeSession(
            nodeId: 'n1',
            generatedBeats: [
              Beat(
                id: 'b_ai',
                nodeId: 'n1',
                scene: Scene(locationText: '城门'),
                appearances: [],
                lines: [
                  DialogueLine(
                    id: 'l_ai',
                    text: '雨停了。',
                    kind: DialogueKind.narration,
                  ),
                ],
                choices: [],
              ),
            ],
          ),
        ),
      },
    );

    await tester.pumpWidget(
      testScoped(
        projects: _TempDirProjects(project: staged, dir: dir.path),
        saves: saves,
        home: PlaySessionPage(
          project: staged,
          mode: PlayViewMode.visualNovel,
          slotId: 'slot_bg',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('雨停了。'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(vnBackdropKey),
        matching: find.byType(Image),
      ),
      findsOneWidget,
    );
  });
}

/// Serves one project from a real temp directory so asset files resolve.
class _TempDirProjects extends MemoryProjectRepository {
  _TempDirProjects({required Project project, required this.dir})
    : super(seed: {project.meta.id: project});

  final String dir;

  @override
  Future<String?> directoryFor(String projectId) async => dir;
}

/// 1×1 transparent PNG — enough for `Image.file` to build a provider.
const List<int> _tinyPng = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];
