import 'package:anoworld/domain/ai/ai_prompt_context.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/ai/generate_main_graph_action.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/plot_element.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/domain/settings/built_in_plot_elements.dart';
import 'package:anoworld/domain/settings/plot_element_catalog.dart';
import 'package:anoworld/foundation/ai/st_ai_preset.dart';
import 'package:anoworld/foundation/ai/st_prompt_manager.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/full_graph_json.dart';

class _ScriptedTextClient implements AiTextClient {
  _ScriptedTextClient(this.replies);

  final List<String> replies;
  int calls = 0;
  final List<String> systems = <String>[];
  final List<String> users = <String>[];

  @override
  Future<AiTextCompletion> complete({
    required AiTextEndpoint endpoint,
    required String system,
    required String user,
    GenerationPreset? generation,
  }) async {
    systems.add(system);
    users.add(user);
    if (calls >= replies.length) {
      throw AiTextException('no more replies');
    }
    return AiTextCompletion(content: replies[calls++]);
  }
}

final _graphJson = buildFullGraphJson();

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

  test('uses world book as corpus and returns a skeleton', () async {
    final client = _ScriptedTextClient([_graphJson]);
    final project = const ProjectFactory().createRainNightSample();

    final main = await GenerateMainGraphAction(textClient: client).generate(
      ctx: ctx(),
      project: project,
      prompt: '今晚必须出城',
    );

    expect(main.beats, isEmpty);
    expect(main.nodes.length, greaterThanOrEqualTo(20));
    expect(main.edges, isNotEmpty);
    expect(main.startNodeId, main.nodes.first.id);
    expect(
      main.edges.any((edge) => edge.kind == EdgeKind.branch),
      isTrue,
    );

    final system = client.systems.single;
    expect(system, contains('边陲小城外常有过路旅人'));
    final user = client.users.single;
    expect(user, contains('今晚必须出城'));
    expect(user, contains('掌柜'));
    expect(user, contains('现有情节'));
  });

  test('blank story does not send the placeholder opening as existing plot',
      () async {
    final client = _ScriptedTextClient([_graphJson]);
    final project = const ProjectFactory().createBlank(id: 'p1', title: '空白');

    await GenerateMainGraphAction(textClient: client).generate(
      ctx: ctx(),
      project: project,
      prompt: '从雨夜开始',
    );

    expect(client.users.single, isNot(contains('现有情节')));
  });

  test('woven plot elements reach the system prompt', () async {
    final element = BuiltInPlotElements.all.first;
    final client = _ScriptedTextClient([_graphJson]);
    final project = const ProjectFactory().createRainNightSample().copyWith(
      plotElements: PlotElementSelection(selectedIds: [element.id]),
    );

    await GenerateMainGraphAction(textClient: client).generate(
      ctx: ctx(),
      project: project,
      prompt: '加点支线',
      plotCatalog: PlotElementCatalog(),
    );

    final system = client.systems.single;
    expect(system, contains(element.keyword));
    expect(system, contains('骨架分叉尽量覆盖不同分类'));
  });

  test('retries once when the first payload is not usable', () async {
    final client = _ScriptedTextClient(['not json', _graphJson]);
    final project = const ProjectFactory().createRainNightSample();

    final main = await GenerateMainGraphAction(textClient: client).generate(
      ctx: ctx(),
      project: project,
      prompt: '随便走走',
    );

    expect(main.nodes, isNotEmpty);
    expect(client.calls, 2);
    expect(client.users.last, contains('只输出合法 JSON'));
  });

  test('throws a user-facing error when the endpoint is not set up', () async {
    final action = GenerateMainGraphAction(
      textClient: _ScriptedTextClient(const []),
    );
    final unconfigured = AiPromptContext(
      endpoint: const AiTextEndpoint(),
      generation: const GenerationPreset(),
      promptManager: PromptManagerConfig.defaultConfig(),
    );

    await expectLater(
      action.generate(
        ctx: unconfigured,
        project: const ProjectFactory().createRainNightSample(),
        prompt: '出城',
      ),
      throwsA(isA<AiTextException>()),
    );
  });

  test('throws a user-facing error for an empty prompt', () async {
    final action = GenerateMainGraphAction(
      textClient: _ScriptedTextClient(const []),
    );

    await expectLater(
      action.generate(
        ctx: ctx(),
        project: const ProjectFactory().createRainNightSample(),
        prompt: '   ',
      ),
      throwsA(isA<AiTextException>()),
    );
  });
}
