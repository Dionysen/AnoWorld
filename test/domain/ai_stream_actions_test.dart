import 'package:anoworld/domain/ai/ai_prompt_context.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/ai/bridge_generate_action.dart';
import 'package:anoworld/domain/chat/tavern_chat_generate_action.dart';
import 'package:anoworld/domain/chat/tavern_chat_message.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:anoworld/domain/runtime/bridge_session.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/foundation/ai/st_ai_preset.dart';
import 'package:anoworld/foundation/ai/st_prompt_manager.dart';
import 'package:flutter_test/flutter_test.dart';

/// Streams scripted chunks and refuses the buffered path.
class _StreamingClient implements AiTextClient, AiTextStreamClient {
  _StreamingClient(this.chunks);

  final List<String> chunks;
  bool bufferedCalled = false;

  @override
  Future<AiTextCompletion> complete({
    required AiTextEndpoint endpoint,
    required String system,
    required String user,
    GenerationPreset? generation,
  }) async {
    bufferedCalled = true;
    throw AiTextException('should stream');
  }

  @override
  Stream<AiTextChunk> streamText({
    required AiTextEndpoint endpoint,
    required String system,
    required String user,
    GenerationPreset? generation,
  }) async* {
    for (final chunk in chunks) {
      yield AiTextChunk(content: chunk);
    }
  }
}

class _BufferedClient implements AiTextClient {
  _BufferedClient(this.reply);

  final String reply;

  @override
  Future<AiTextCompletion> complete({
    required AiTextEndpoint endpoint,
    required String system,
    required String user,
    GenerationPreset? generation,
  }) async {
    return AiTextCompletion(content: reply);
  }
}

void main() {
  const endpoint = AiTextEndpoint(
    kind: AiTextProviderKind.openAiCompatible,
    baseUrl: 'http://localhost:8080/v1',
    apiKey: 'sk',
    model: 'demo',
  );

  AiPromptContext ctx() => AiPromptContext(
    endpoint: endpoint,
    generation: const GenerationPreset(),
    promptManager: PromptManagerConfig.defaultConfig(),
  );

  test('chat streams each chunk in order', () async {
    final project = const ProjectFactory().createBlank(id: 'p', title: 't');
    final client = _StreamingClient(<String>['你', '好', '呀']);
    final chunks = await TavernChatGenerateAction(textClient: client)
        .streamGenerate(
          ctx: ctx(),
          project: project,
          history: const <TavernChatMessage>[
            TavernChatMessage(
              id: 'm1',
              role: TavernChatRole.user,
              content: '在吗',
            ),
          ],
        )
        .toList();

    expect(chunks.map((chunk) => chunk.content).join(), '你好呀');
    expect(client.bufferedCalled, isFalse);
  });

  test('chat falls back to one chunk for non-streaming clients', () async {
    final project = const ProjectFactory().createBlank(id: 'p', title: 't');
    final chunks = await TavernChatGenerateAction(
      textClient: _BufferedClient('整段回复'),
    ).streamGenerate(
      ctx: ctx(),
      project: project,
      history: const <TavernChatMessage>[],
    ).toList();

    expect(chunks.single.content, '整段回复');
  });

  test('chat rejects a stream that wrote nothing', () async {
    final project = const ProjectFactory().createBlank(id: 'p', title: 't');
    await expectLater(
      TavernChatGenerateAction(
        textClient: _StreamingClient(const <String>[]),
      ).streamGenerate(
        ctx: ctx(),
        project: project,
        history: const <TavernChatMessage>[],
      ).toList(),
      throwsA(isA<AiTextException>()),
    );
  });

  test('beat streaming emits lines as their objects close', () async {
    final project = const ProjectFactory().createBlank(id: 'p', title: 't');
    final nodeId = project.main.startNodeId;
    final client = _StreamingClient(<String>[
      '{"location":"走廊","lines":[{"speaker":"旁白","text":"雨声',
      '很近。"},{"speaker":"旁白","text":"灯灭了。"}],"choices":[]}',
    ]);
    final events = await BridgeGenerateAction(textClient: client)
        .streamGenerate(
          ctx: ctx(),
          project: project,
          nodeId: nodeId,
          session: BridgeSession(nodeId: nodeId),
        )
        .toList();

    final lines = events.whereType<BridgeBeatLineEvent>().toList();
    expect(lines.map((event) => event.line.text), ['雨声很近。', '灯灭了。']);
    expect(lines.first.location, '走廊');
    final done = events.whereType<BridgeBeatDoneEvent>().single;
    expect(done.beat.lines, hasLength(2));
    expect(client.bufferedCalled, isFalse);
  });

  test('beat streaming falls back to a whole beat', () async {
    final project = const ProjectFactory().createBlank(id: 'p', title: 't');
    final nodeId = project.main.startNodeId;
    final events = await BridgeGenerateAction(
      textClient: _BufferedClient(
        '{"lines":[{"speaker":"旁白","text":"只有一句。"}],"choices":[]}',
      ),
    ).streamGenerate(
      ctx: ctx(),
      project: project,
      nodeId: nodeId,
      session: BridgeSession(nodeId: nodeId),
    ).toList();

    expect(events.whereType<BridgeBeatLineEvent>(), isEmpty);
    expect(
      events.whereType<BridgeBeatDoneEvent>().single.beat.lines.single.text,
      '只有一句。',
    );
  });

  test('beat streaming keeps already shown lines when the tail is broken', () async {
    final project = const ProjectFactory().createBlank(id: 'p', title: 't');
    final nodeId = project.main.startNodeId;
    final client = _StreamingClient(<String>[
      '{"lines":[{"speaker":"旁白","text":"先出来的一句。"}]',
    ]);
    final events = await BridgeGenerateAction(textClient: client)
        .streamGenerate(
          ctx: ctx(),
          project: project,
          nodeId: nodeId,
          session: BridgeSession(nodeId: nodeId),
        )
        .toList();

    expect(events.whereType<BridgeBeatLineEvent>(), hasLength(1));
    final done = events.whereType<BridgeBeatDoneEvent>().single;
    expect(done.beat.lines.single.text, '先出来的一句。');
  });
}
