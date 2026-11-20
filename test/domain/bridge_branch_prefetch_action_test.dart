import 'package:anoworld/domain/ai/ai_prompt_context.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/ai/bridge_branch_prefetch_action.dart';
import 'package:anoworld/domain/ai/bridge_generate_action.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:anoworld/domain/runtime/bridge_session.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/foundation/ai/st_ai_preset.dart';
import 'package:anoworld/foundation/ai/st_prompt_manager.dart';
import 'package:flutter_test/flutter_test.dart';

class _ScriptedTextClient implements AiTextClient {
  _ScriptedTextClient(this.replies);

  final List<String> replies;
  int calls = 0;
  String? lastUser;

  @override
  Future<AiTextCompletion> complete({
    required AiTextEndpoint endpoint,
    required String system,
    required String user,
    GenerationPreset? generation,
  }) async {
    lastUser = user;
    if (calls >= replies.length) {
      throw AiTextException('no more replies');
    }
    return AiTextCompletion(content: replies[calls++]);
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

  test('batch parses multiple branches; missing one stays null', () async {
    final blank = const ProjectFactory().createBlank(id: 'p', title: 't');
    final nodeId = blank.main.startNodeId;
    final stay = Choice(
      id: 'c_stay',
      text: '继续',
      target: Transition.toBeat(kBridgeStayBeatId),
    );
    final other = Choice(
      id: 'c_other',
      text: '再看看',
      target: Transition.toBeat(kBridgeStayBeatId),
    );
    final client = _ScriptedTextClient([
      '''{"branches":[
        {"choiceId":"c_stay","beat":{"lines":[{"speaker":"旁白","text":"留下。"}],"choices":[]}},
        {"choiceId":"c_unknown","beat":{"lines":[{"speaker":"旁白","text":"丢弃。"}],"choices":[]}}
      ]}''',
    ]);
    final action = BridgeBranchPrefetchAction(textClient: client);
    final results = await action.generate(
      ctx: ctx(),
      project: blank,
      sourceNodeId: nodeId,
      session: BridgeSession(nodeId: nodeId),
      branches: [
        BridgeBranchPrefetchRequest(choice: stay, targetNodeId: nodeId),
        BridgeBranchPrefetchRequest(choice: other, targetNodeId: nodeId),
      ],
    );
    expect(results, hasLength(2));
    expect(results[0].choiceId, 'c_stay');
    expect(results[0].beat?.lines.first.text, '留下。');
    expect(results[0].beat?.choices, isNotEmpty); // open mode fills continue
    expect(results[1].choiceId, 'c_other');
    expect(results[1].beat, isNull);
    expect(client.calls, 1);
  });

  test('batch entrance takes at most maxChoicesPerBeat requests', () async {
    final blank = const ProjectFactory().createBlank(id: 'p', title: 't');
    final nodeId = blank.main.startNodeId;
    final client = _ScriptedTextClient([
      '{"branches":[]}',
    ]);
    final action = BridgeBranchPrefetchAction(textClient: client);
    final branches = [
      for (var i = 0; i < 5; i++)
        BridgeBranchPrefetchRequest(
          choice: Choice(
            id: 'c$i',
            text: '选项$i',
            target: Transition.toBeat(kBridgeStayBeatId),
          ),
          targetNodeId: nodeId,
        ),
    ];
    final results = await action.generate(
      ctx: ctx(),
      project: blank,
      sourceNodeId: nodeId,
      session: BridgeSession(nodeId: nodeId),
      branches: branches,
    );
    expect(results, hasLength(BridgeSession.maxChoicesPerBeat));
    expect(client.lastUser, isNot(contains('选项3')));
    expect(client.lastUser, isNot(contains('选项4')));
  });
}
