import 'package:anoworld/domain/ai/ai_prompt_context.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/foundation/ai/st_ai_preset.dart';
import 'package:anoworld/foundation/ai/st_prompt_manager.dart';
import 'package:anoworld/domain/ai/create/create_agent_runner.dart';
import 'package:anoworld/domain/ai/create/create_assistant_target.dart';
import 'package:anoworld/domain/ai/create/create_tool_context.dart';
import 'package:anoworld/domain/ai/create/create_tool_services.dart';
import 'package:anoworld/domain/card_import/card_sanitize_action.dart';
import 'package:anoworld/domain/card_import/st_card_project_mapper.dart';
import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/full_graph_json.dart';

class _FakeTextClient implements AiTextClient {
  @override
  Future<AiTextCompletion> complete({
    required AiTextEndpoint endpoint,
    required String system,
    required String user,
    GenerationPreset? generation,
  }) async {
    throw UnimplementedError();
  }
}

class _ScriptedTextClient implements AiTextClient {
  _ScriptedTextClient(this.reply);

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
  test('card.sanitize_draft via runner', () async {
    final runner = CreateAgentRunner();
    final draft = StCardImportDraft(
      title: 't',
      castItems: [
        StCardImportItem(
          id: 'c1',
          title: '甲',
          preview: 'x',
          value: const CastMember(
            id: 'c1',
            name: '甲',
            summary: '<b>hi</b>',
          ),
        ),
      ],
      worldBookItems: const [],
    );
    final ctx = CreateToolContext(
      draft: draft,
      services: CreateToolServices(textClient: _FakeTextClient()),
    );
    final result = await runner.runSingle(
      toolName: 'card.sanitize_draft',
      ctx: ctx,
    );
    expect(result.ok, isTrue);
    expect(result.payload?['changedFieldCount'], greaterThan(0));
    const action = CardSanitizeAction();
    final sanitized = action.run(draft);
    expect(sanitized.draft.castItems.first.value.summary, contains('**hi**'));
  });

  test('main.generate_graph asks for confirmation with a skeleton', () async {
    const endpoint = AiTextEndpoint(
      kind: AiTextProviderKind.openAiCompatible,
      baseUrl: 'http://localhost:8080/v1',
      apiKey: 'sk',
      model: 'demo',
    );
    final ctx = CreateToolContext(
      project: const ProjectFactory().createRainNightSample(),
      ai: AiPromptContext(
        endpoint: endpoint,
        generation: const GenerationPreset(),
        promptManager: PromptManagerConfig.defaultConfig(),
      ),
      services: CreateToolServices(
        textClient: _ScriptedTextClient(buildFullGraphJson()),
      ),
    );

    final result = await CreateAgentRunner().runSingle(
      toolName: 'main.generate_graph',
      ctx: ctx,
      args: const {'prompt': '今晚必须出城'},
    );

    expect(result.ok, isTrue);
    final preview = result.userConfirmPayload;
    expect(preview, isNotNull);
    expect(preview?['stations'], isA<List>());
    expect(preview?['nodeCount'], greaterThanOrEqualTo(20));
    expect(preview?['graph'], isA<Map>());
  });

  test('runTurn picks patch when graph exists', () async {
    final project = const ProjectFactory().createRainNightSample();
    final ctx = CreateToolContext(
      project: project,
      ai: AiPromptContext(
        endpoint: const AiTextEndpoint(
          kind: AiTextProviderKind.openAiCompatible,
          baseUrl: 'http://localhost:8080/v1',
          apiKey: 'sk',
          model: 'demo',
        ),
        generation: const GenerationPreset(),
        promptManager: PromptManagerConfig.defaultConfig(),
      ),
      services: CreateToolServices(
        textClient: _ScriptedTextClient('''
{"ops":[{"op":"set_summary","summary":"补丁概括"},{"op":"upsert_node","title":"新岔路","synopsis":"另一条世界线"}]}
'''),
      ),
    );
    final turn = await CreateAgentRunner().runTurn(
      target: CreateAssistantTarget.graph,
      prompt: '加一条岔路',
      ctx: ctx,
    );
    expect(turn.toolName, 'main.patch_graph');
    expect(turn.result.ok, isTrue);
    expect(turn.result.userConfirmPayload?['kind'], 'main.patch_graph');
  });

  test('runTurn world uses world.patch_propose', () async {
    final ctx = CreateToolContext(
      project: const ProjectFactory().createRainNightSample(),
      ai: AiPromptContext(
        endpoint: const AiTextEndpoint(
          kind: AiTextProviderKind.openAiCompatible,
          baseUrl: 'http://localhost:8080/v1',
          apiKey: 'sk',
          model: 'demo',
        ),
        generation: const GenerationPreset(),
        promptManager: PromptManagerConfig.defaultConfig(),
      ),
      services: CreateToolServices(
        textClient: _ScriptedTextClient('''
{"ops":[{"op":"upsert_entry","title":"新设定","body":"内容","alwaysOn":true}]}
'''),
      ),
    );
    final turn = await CreateAgentRunner().runTurn(
      target: CreateAssistantTarget.world,
      prompt: '加一条常驻设定',
      ctx: ctx,
    );
    expect(turn.toolName, 'world.patch_propose');
    expect(turn.result.ok, isTrue);
  });

  test('main.generate_graph needs a configured text service', () async {
    final ctx = CreateToolContext(
      project: const ProjectFactory().createRainNightSample(),
      ai: null,
      services: CreateToolServices(textClient: _FakeTextClient()),
    );

    final result = await CreateAgentRunner().runSingle(
      toolName: 'main.generate_graph',
      ctx: ctx,
    );

    expect(result.ok, isFalse);
    expect(result.errorMessage, '未配置文本服务');
  });
}