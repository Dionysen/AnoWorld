import 'package:anoworld/domain/ai/ai_prompt_context.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/foundation/ai/st_ai_preset.dart';
import 'package:anoworld/foundation/ai/st_prompt_manager.dart';
import 'package:anoworld/domain/ai/create/create_agent_runner.dart';
import 'package:anoworld/domain/ai/create/create_tool_context.dart';
import 'package:anoworld/domain/ai/create/create_tool_services.dart';
import 'package:anoworld/domain/card_import/card_sanitize_action.dart';
import 'package:anoworld/domain/card_import/st_card_project_mapper.dart';
import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:flutter_test/flutter_test.dart';

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
        textClient: _ScriptedTextClient('''
{"summary":"雨夜出走","stations":[
{"title":"城门","synopsis":"被拦下","exits":[{"to":"客栈","kind":"default"}]},
{"title":"客栈","synopsis":"找到出路","exits":[{"to":"end","kind":"default"}]}
]}
'''),
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
    expect(preview?['nodeCount'], greaterThanOrEqualTo(2));
    expect(preview?['graph'], isA<Map>());
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