import 'dart:convert';

import 'package:anoworld/domain/ai/ai_prompt_context.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/foundation/ai/openai_chat_client.dart';
import 'package:anoworld/foundation/ai/openai_chat_message.dart';
import 'package:anoworld/foundation/ai/st_ai_preset.dart';
import 'package:anoworld/foundation/ai/st_prompt_manager.dart';
import 'package:anoworld/domain/ai/create/create_agent_runner.dart';
import 'package:anoworld/domain/ai/create/create_assistant_target.dart';
import 'package:anoworld/domain/ai/create/create_chat_turn.dart';
import 'package:anoworld/domain/ai/create/create_history_fit.dart';
import 'package:anoworld/domain/ai/create/create_tool_context.dart';
import 'package:anoworld/domain/ai/create/create_tool_registry.dart';
import 'package:anoworld/domain/ai/create/create_tool_services.dart';
import 'package:anoworld/domain/ai/create/tools/project_tools.dart';
import 'package:anoworld/domain/card_import/card_sanitize_action.dart';
import 'package:anoworld/domain/card_import/st_card_project_mapper.dart';
import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/models/plot_element.dart';
import 'package:anoworld/domain/models/world_book.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:anoworld/domain/settings/plot_element_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/full_graph_json.dart';

const AiTextEndpoint _endpoint = AiTextEndpoint(
  kind: AiTextProviderKind.openAiCompatible,
  baseUrl: 'http://localhost:8080/v1',
  apiKey: 'sk',
  model: 'demo',
);

AiPromptContext _promptCtx() => AiPromptContext(
      endpoint: _endpoint,
      generation: const GenerationPreset(),
      promptManager: PromptManagerConfig.defaultConfig(),
    );

/// Scripted tool-loop client: one queued reply per model turn.
class _ScriptedTurnClient implements AiToolTurnClient {
  _ScriptedTurnClient(this.replies);

  final List<OpenAiChatCompletion> replies;
  int calls = 0;

  /// Messages of the last turn, so tests can assert what the model was told.
  List<OpenAiChatMessage> lastMessages = const <OpenAiChatMessage>[];

  @override
  Future<OpenAiChatCompletion> completeTurn({
    required AiTextEndpoint endpoint,
    required List<OpenAiChatMessage> messages,
    List<OpenAiTool> tools = const <OpenAiTool>[],
    GenerationPreset? generation,
  }) async {
    lastMessages = messages;
    if (calls >= replies.length) {
      throw AiTextException('no more replies');
    }
    return replies[calls++];
  }
}

OpenAiChatCompletion _call(
  String name,
  Map<String, dynamic> args, {
  int index = 0,
}) {
  return OpenAiChatCompletion(
    content: '',
    toolCalls: [
      OpenAiToolCall(
        id: 'call_$index',
        name: name,
        arguments: _encode(args),
      ),
    ],
  );
}

String _encode(Map<String, dynamic> args) {
  final buffer = StringBuffer('{');
  var first = true;
  for (final entry in args.entries) {
    if (!first) buffer.write(',');
    first = false;
    buffer.write('"${entry.key}":${_value(entry.value)}');
  }
  buffer.write('}');
  return buffer.toString();
}

/// Fails the first [truncations] model turns the way the real client does when
/// `finish_reason` is `length`, then replays [replies].
class _TruncatingTurnClient implements AiToolTurnClient {
  _TruncatingTurnClient({required this.truncations, required this.replies});

  final int truncations;
  final List<OpenAiChatCompletion> replies;
  int calls = 0;
  List<OpenAiChatMessage> lastMessages = const <OpenAiChatMessage>[];

  @override
  Future<OpenAiChatCompletion> completeTurn({
    required AiTextEndpoint endpoint,
    required List<OpenAiChatMessage> messages,
    List<OpenAiTool> tools = const <OpenAiTool>[],
    GenerationPreset? generation,
  }) async {
    lastMessages = messages;
    calls++;
    if (calls <= truncations) {
      throw AiTextException(
        '这次的输出触到长度上限被截断了，少生成一点再试',
        code: AiTextException.truncated,
      );
    }
    final index = calls - truncations - 1;
    if (index >= replies.length) {
      throw AiTextException('no more replies');
    }
    return replies[index];
  }
}

String _value(Object? value) {
  if (value == null) return 'null';
  if (value is num || value is bool) return '$value';
  if (value is List) return '[${value.map(_value).join(',')}]';
  if (value is Map) return _encode(Map<String, dynamic>.from(value));
  return '"${value.toString().replaceAll('"', r'\"')}"';
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
      services: const CreateToolServices(),
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

  test('main.replace takes stations from the model and asks for confirm',
      () async {
    final ctx = CreateToolContext(
      project: const ProjectFactory().createRainNightSample(),
      services: const CreateToolServices(),
    );

    final result = await CreateAgentRunner().runSingle(
      toolName: 'main.replace',
      ctx: ctx,
      args: {'graph': buildFullGraphJson()},
    );
    // Raw JSON in one string is not the argument shape; a map is.
    expect(result.ok, isFalse);

    final graph = _decodeGraph(buildFullGraphJson());
    final ok = await CreateAgentRunner().runSingle(
      toolName: 'main.replace',
      ctx: ctx,
      args: graph,
    );
    expect(ok.ok, isTrue);
    final preview = ok.userConfirmPayload;
    expect(preview, isNotNull);
    expect(preview!['kind'], 'main.replace');
    expect(preview['nodeCount'], greaterThanOrEqualTo(20));
    expect(preview['graph'], isA<Map>());
  });

  test('main.patch applies ops onto the existing graph', () async {
    final project = const ProjectFactory().createRainNightSample();
    final ctx = CreateToolContext(
      project: project,
      services: const CreateToolServices(),
    );
    final result = await CreateAgentRunner().runSingle(
      toolName: 'main.patch',
      ctx: ctx,
      args: {
        'ops': [
          {'op': 'set_summary', 'summary': '补丁概括'},
          {'op': 'upsert_node', 'title': '新岔路', 'synopsis': '另一条世界线'},
        ],
      },
    );
    expect(result.ok, isTrue);
    final preview = result.userConfirmPayload;
    expect(preview!['kind'], 'main.patch');
    expect(preview['opCount'], 2);
    expect(preview['summary'], '补丁概括');
  });

  test('main.patch reports broken ops instead of throwing', () async {
    final ctx = CreateToolContext(
      project: const ProjectFactory().createRainNightSample(),
      services: const CreateToolServices(),
    );
    final result = await CreateAgentRunner().runSingle(
      toolName: 'main.patch',
      ctx: ctx,
      args: {
        'ops': [
          {'op': 'remove_node', 'id': 'nope'},
        ],
      },
    );
    expect(result.ok, isFalse);
    expect(result.errorMessage, contains('删不了站'));
  });

  test('runTurn reads the graph, then patches it', () async {
    final client = _ScriptedTurnClient([
      _call('main.read_graph', const {}),
      _call(
          'main.patch',
          {
            'ops': [
              {'op': 'set_summary', 'summary': '补丁概括'},
            ],
          },
          index: 1),
      const OpenAiChatCompletion(content: ''),
    ]);
    final ctx = CreateToolContext(
      project: const ProjectFactory().createRainNightSample(),
      ai: _promptCtx(),
      services: CreateToolServices(toolClient: client),
    );

    final turn = await CreateAgentRunner().runTurn(
      target: CreateAssistantTarget.graph,
      prompt: '把主线概括改短',
      ctx: ctx,
    );

    expect(turn.calledTools, ['main.read_graph', 'main.patch']);
    expect(turn.proposal?['kind'], 'main.patch');
    // The tool result travelled back to the model before the patch turn.
    final toolMessages = client.lastMessages.where((m) => m.role == 'tool');
    expect(toolMessages, isNotEmpty);
    expect(toolMessages.first.content, contains('"ok":true'));
  });

  test('runTurn answers in text when the model calls no tool', () async {
    final client = _ScriptedTurnClient([
      const OpenAiChatCompletion(content: '这条线目前没有需要改的地方'),
    ]);
    final ctx = CreateToolContext(
      project: const ProjectFactory().createRainNightSample(),
      ai: _promptCtx(),
      services: CreateToolServices(toolClient: client),
    );

    final turn = await CreateAgentRunner().runTurn(
      target: CreateAssistantTarget.graph,
      prompt: '看看情节合理吗',
      ctx: ctx,
    );

    expect(turn.hasAnswer, isTrue);
    expect(turn.answer, '这条线目前没有需要改的地方');
    expect(turn.proposal, isNull);
  });

  test('runTurn reads a JSON reply as a proposal for weak models', () async {
    final client = _ScriptedTurnClient([
      const OpenAiChatCompletion(
        content: '{"ops":[{"op":"upsert_entry","title":"新设定","body":"内容"}]}',
      ),
    ]);
    final ctx = CreateToolContext(
      project: const ProjectFactory().createRainNightSample(),
      ai: _promptCtx(),
      services: CreateToolServices(toolClient: client),
    );

    final turn = await CreateAgentRunner().runTurn(
      target: CreateAssistantTarget.world,
      prompt: '加一条设定',
      ctx: ctx,
    );

    expect(turn.proposal?['kind'], 'world.patch');
    expect(turn.proposal?['opCount'], 1);
  });

  test('runTurn needs a tool-capable client', () async {
    final ctx = CreateToolContext(
      project: const ProjectFactory().createRainNightSample(),
      ai: _promptCtx(),
      services: const CreateToolServices(),
    );

    final turn = await CreateAgentRunner().runTurn(
      target: CreateAssistantTarget.world,
      prompt: '加一条设定',
      ctx: ctx,
    );

    expect(turn.proposal, isNull);
    expect(turn.errorMessage, '先用一个支持工具调用的服务');
  });

  test('runTurn only offers tools for the target layer writes', () async {
    final client = _ScriptedTurnClient([
      const OpenAiChatCompletion(content: '好'),
    ]);
    final ctx = CreateToolContext(
      project: const ProjectFactory().createRainNightSample(),
      ai: _promptCtx(),
      services: CreateToolServices(toolClient: client),
    );

    await CreateAgentRunner().runTurn(
      target: CreateAssistantTarget.world,
      prompt: '加一条设定',
      ctx: ctx,
    );

    final system = client.lastMessages.first.content;
    expect(system, contains('wb:'));
    expect(system, contains('world.patch'));
    // The L1 directory replaces the full world book bodies.
    expect(system, isNot(contains('边陲小城外常有过路旅人')));
  });

  test('world.read_entry accepts a ref and returns one field', () async {
    final project = const ProjectFactory().createRainNightSample();
    final entry = project.worldBook.entries.first;
    final ctx = CreateToolContext(
      project: project,
      services: const CreateToolServices(),
    );

    final whole = await CreateAgentRunner().runSingle(
      toolName: 'world.read_entry',
      ctx: ctx,
      args: {'ref': 'wb:${entry.id}'},
    );
    expect(whole.ok, isTrue);
    expect(whole.payload?['ref'], 'wb:${entry.id}');
    expect(whole.payload?['truncated'], isFalse);
    expect(whole.payload?['tokenEstimate'], greaterThan(0));

    final single = await CreateAgentRunner().runSingle(
      toolName: 'world.read_entry',
      ctx: ctx,
      args: {'ref': 'wb:${entry.id}.title'},
    );
    expect(single.ok, isTrue);
    expect(single.payload?['field'], 'title');
    expect(single.payload?['value'], entry.title);

    final wrongLayer = await CreateAgentRunner().runSingle(
      toolName: 'world.read_entry',
      ctx: ctx,
      args: {'ref': 'cast:${entry.id}'},
    );
    expect(wrongLayer.ok, isFalse);

    final badField = await CreateAgentRunner().runSingle(
      toolName: 'world.read_entry',
      ctx: ctx,
      args: {'ref': 'wb:${entry.id}.nope'},
    );
    expect(badField.ok, isFalse);
  });

  test('world.read_entry flags truncation', () async {
    final project = const ProjectFactory().createRainNightSample();
    final entry = project.worldBook.entries.first;
    final ctx = CreateToolContext(
      project: project,
      services: const CreateToolServices(),
    );

    final result = await CreateAgentRunner().runSingle(
      toolName: 'world.read_entry',
      ctx: ctx,
      args: {'ref': 'wb:${entry.id}', 'maxChars': 4},
    );
    expect(result.ok, isTrue);
    expect(result.payload?['truncated'], isTrue);
    expect('${result.payload?['body']}', endsWith('…'));
  });

  test('cast.read_member accepts a ref and returns one field', () async {
    final project = const ProjectFactory().createRainNightSample();
    final member = project.cast.first;
    final ctx = CreateToolContext(
      project: project,
      services: const CreateToolServices(),
    );

    final single = await CreateAgentRunner().runSingle(
      toolName: 'cast.read_member',
      ctx: ctx,
      args: {'ref': 'cast:${member.id}.speechStyle'},
    );
    expect(single.ok, isTrue);
    expect(single.payload?['value'], member.speechStyle);

    final whole = await CreateAgentRunner().runSingle(
      toolName: 'cast.read_member',
      ctx: ctx,
      args: {'id': member.id},
    );
    expect(whole.ok, isTrue);
    expect(whole.payload?['ref'], 'cast:${member.id}');
  });
  test('world.list_entries pages long books and can be filtered', () async {
    final base = const ProjectFactory().createRainNightSample();
    final entries = <WorldBookEntry>[
      for (var i = 0; i < 60; i++)
        WorldBookEntry(
          id: 'wb_$i',
          title: '条目$i',
          body: '内容$i',
          keys: i == 0 ? const <String>['雨'] : const <String>[],
        ),
    ];
    final ctx = CreateToolContext(
      project: base.copyWith(worldBook: WorldBook(entries: entries)),
      services: const CreateToolServices(),
    );

    final all = await CreateAgentRunner().runSingle(
      toolName: 'world.list_entries',
      ctx: ctx,
    );
    expect(all.payload?['total'], 60);
    expect(all.payload?['count'], kListDefaultLimit);
    expect(all.payload?['truncated'], isTrue);
    expect(all.payload?['hint'], contains('还有 10 条'));

    final small = await CreateAgentRunner().runSingle(
      toolName: 'world.list_entries',
      ctx: ctx,
      args: {'limit': 5},
    );
    expect(small.payload?['count'], 5);
    expect((small.payload?['entries'] as List), hasLength(5));

    final filtered = await CreateAgentRunner().runSingle(
      toolName: 'world.list_entries',
      ctx: ctx,
      args: {'keyword': '雨'},
    );
    expect(filtered.payload?['total'], 1);
    expect(filtered.payload?['truncated'], isFalse);
    expect(filtered.payload?['hint'], isNull);
    expect(((filtered.payload?['entries'] as List).single as Map)['id'], 'wb_0');
  });

  test('cast.list_members pages and filters by name', () async {
    final base = const ProjectFactory().createRainNightSample();
    final cast = <CastMember>[
      for (var i = 0; i < 55; i++)
        CastMember(id: 'c_$i', name: '角色$i', summary: '简介$i'),
    ];
    final ctx = CreateToolContext(
      project: base.copyWith(cast: cast),
      services: const CreateToolServices(),
    );

    final all = await CreateAgentRunner().runSingle(
      toolName: 'cast.list_members',
      ctx: ctx,
    );
    expect(all.payload?['total'], 55);
    expect(all.payload?['count'], kListDefaultLimit);
    expect(all.payload?['truncated'], isTrue);

    final filtered = await CreateAgentRunner().runSingle(
      toolName: 'cast.list_members',
      ctx: ctx,
      args: {'keyword': '角色1'},
    );
    // 角色1, 角色10..19 → 11 rows.
    expect(filtered.payload?['total'], 11);
    expect(filtered.payload?['truncated'], isFalse);
  });

  test('elides an old tool reply when the turn exceeds the window', () async {
    final base = const ProjectFactory().createRainNightSample();
    final entries = <WorldBookEntry>[
      WorldBookEntry(id: 'wb_a', title: '长设定甲', body: '甲' * 4000),
      WorldBookEntry(id: 'wb_b', title: '长设定乙', body: '乙' * 4000),
    ];
    final client = _ScriptedTurnClient(<OpenAiChatCompletion>[
      const OpenAiChatCompletion(
        content: '',
        toolCalls: <OpenAiToolCall>[
          OpenAiToolCall(
            id: 'call_0',
            name: 'world.read_entry',
            arguments: '{"id":"wb_a"}',
          ),
          OpenAiToolCall(
            id: 'call_1',
            name: 'world.read_entry',
            arguments: '{"id":"wb_b"}',
          ),
        ],
      ),
      const OpenAiChatCompletion(content: '看完了，这两条互不冲突'),
    ]);
    final ctx = CreateToolContext(
      project: base.copyWith(worldBook: WorldBook(entries: entries)),
      ai: AiPromptContext(
        endpoint: _endpoint,
        generation: const GenerationPreset(contextLength: 3000, maxTokens: 900),
        promptManager: PromptManagerConfig.defaultConfig(),
      ),
      services: CreateToolServices(toolClient: client),
    );

    final result = await CreateAgentRunner().runTurn(
      target: CreateAssistantTarget.world,
      prompt: '看看这两条设定',
      ctx: ctx,
    );

    expect(result.answer, contains('互不冲突'));
    final toolReplies = client.lastMessages
        .where((m) => m.role == 'tool')
        .toList(growable: false);
    expect(toolReplies, hasLength(2));
    // The oldest reply is replaced by a stub; the newest stays readable.
    expect(toolReplies.first.content, CreateHistoryFit.elidedBody);
    expect(toolReplies.last.content, contains('乙'));
  });

  test('replays recent conversation and trims it to the window', () async {
    final base = const ProjectFactory().createRainNightSample();
    final client = _ScriptedTurnClient(<OpenAiChatCompletion>[
      const OpenAiChatCompletion(content: '好，改成更冷'),
      const OpenAiChatCompletion(content: '这次只改语气'),
    ]);
    final ctx = (GenerationPreset generation) => CreateToolContext(
          project: base,
          ai: AiPromptContext(
            endpoint: _endpoint,
            generation: generation,
            promptManager: PromptManagerConfig.defaultConfig(),
          ),
          services: CreateToolServices(toolClient: client),
        );

    await CreateAgentRunner().runTurn(
      target: CreateAssistantTarget.cast,
      prompt: '把林晚写得更冷一点',
      ctx: ctx(const GenerationPreset()),
      history: const <CreateChatTurn>[
        CreateChatTurn.user('先看看现在什么样'),
        CreateChatTurn.assistant('她的语气偏温和'),
      ],
    );

    final roles = [for (final m in client.lastMessages) m.role];
    expect(roles, <String>['system', 'user', 'assistant', 'user']);
    expect(client.lastMessages[1].content, '先看看现在什么样');
    expect(client.lastMessages[2].content, '她的语气偏温和');
    expect(client.lastMessages[3].content, '把林晚写得更冷一点');

    // When the rules plus this prompt leave too little room, older lines go
    // first and the newest line stays.
    await CreateAgentRunner().runTurn(
      target: CreateAssistantTarget.cast,
      prompt: '这次只改语气',
      ctx: ctx(const GenerationPreset(contextLength: 2048, maxTokens: 1900)),
      history: <CreateChatTurn>[
        CreateChatTurn.user('甲' * 900),
        CreateChatTurn.assistant('乙' * 900),
        CreateChatTurn.assistant('刚才那条已经改过了'),
      ],
    );

    final second = client.lastMessages;
    expect(second.first.role, 'system');
    expect(second.last.content, '这次只改语气');
    expect(second.map((m) => m.content), contains('刚才那条已经改过了'));
    expect(
      second.where((m) => m.content.contains('甲' * 900)),
      isEmpty,
      reason: '超预算的旧对话应被丢掉',
    );
  });

  test('plot.list_elements shows a one-line description', () async {
    final catalog = PlotElementCatalog(
      custom: <PlotElement>[
        PlotElement(
          id: 'pe_rain',
          keyword: '暴雨封路',
          description: '出城的桥被冲断，主角只能困在城里等雨停再找别的路',
        ),
      ],
    );
    final ctx = CreateToolContext(
      project: const ProjectFactory().createRainNightSample(),
      services: CreateToolServices(plotCatalog: catalog),
    );

    final listed = await CreateAgentRunner().runSingle(
      toolName: 'plot.list_elements',
      ctx: ctx,
      args: {'keyword': '暴雨'},
    );

    final row = (listed.payload?['elements'] as List).single as Map;
    expect(row['keyword'], '暴雨封路');
    expect(row['description'], contains('桥被冲断'));
  });

  test('plot.select proposes selection ops against the library', () async {
    final project = const ProjectFactory().createRainNightSample();
    final catalog = PlotElementCatalog(
      custom: <PlotElement>[
        PlotElement(id: 'pe_rain', keyword: '暴雨封路', description: '出城的桥被冲断'),
      ],
    );
    final ctx = CreateToolContext(
      project: project,
      services: CreateToolServices(plotCatalog: catalog),
    );

    final result = await CreateAgentRunner().runSingle(
      toolName: 'plot.select',
      ctx: ctx,
      args: {
        'ops': [
          {'op': 'select', 'ids': ['pe_rain']},
        ],
      },
    );

    expect(result.ok, isTrue);
    final preview = result.userConfirmPayload;
    expect(preview!['kind'], 'plot.select');
    expect(preview['selectedIds'], contains('pe_rain'));
  });

  test('plot.select rejects ids that are not in the library', () async {
    final catalog = PlotElementCatalog(
      custom: <PlotElement>[
        PlotElement(id: 'pe_rain', keyword: '暴雨封路', description: '出城的桥被冲断'),
      ],
    );
    final ctx = CreateToolContext(
      project: const ProjectFactory().createRainNightSample(),
      services: CreateToolServices(plotCatalog: catalog),
    );

    final result = await CreateAgentRunner().runSingle(
      toolName: 'plot.select',
      ctx: ctx,
      args: {
        'ops': [
          {'op': 'select', 'ids': ['pe_nope']},
        ],
      },
    );

    expect(result.ok, isFalse);
    expect(result.errorMessage, contains('pe_nope'));
  });

  test('plot.select needs a library', () async {
    final ctx = CreateToolContext(
      project: const ProjectFactory().createRainNightSample(),
      services: const CreateToolServices(),
    );

    final result = await CreateAgentRunner().runSingle(
      toolName: 'plot.select',
      ctx: ctx,
      args: {
        'ops': [
          {'op': 'select', 'ids': ['pe_rain']},
        ],
      },
    );

    expect(result.ok, isFalse);
    expect(result.errorMessage, contains('剧情元素库'));
  });

  test('plot.list_elements marks what the story already selected', () async {
    final project = const ProjectFactory().createRainNightSample();
    final catalog = PlotElementCatalog(
      custom: <PlotElement>[
        PlotElement(id: 'pe_rain', keyword: '暴雨封路', description: '出城的桥被冲断'),
        PlotElement(id: 'pe_letter', keyword: '旧信', description: '一封迟到十年的信'),
      ],
    );
    final withSelection = project.copyWith(
      plotElements: const PlotElementSelection(selectedIds: ['pe_rain']),
    );
    final ctx = CreateToolContext(
      project: withSelection,
      services: CreateToolServices(plotCatalog: catalog),
    );

    final all = await CreateAgentRunner().runSingle(
      toolName: 'plot.list_elements',
      ctx: ctx,
    );
    expect(all.ok, isTrue);
    expect(all.payload?['count'], catalog.effectiveList.length);

    final filtered = await CreateAgentRunner().runSingle(
      toolName: 'plot.list_elements',
      ctx: ctx,
      args: {'keyword': '旧信'},
    );
    expect(filtered.payload?['count'], 1);
    final rows = filtered.payload?['elements'] as List;
    expect((rows.single as Map)['id'], 'pe_letter');
    expect((rows.single as Map)['selected'], isFalse);

    final rain = await CreateAgentRunner().runSingle(
      toolName: 'plot.list_elements',
      ctx: ctx,
      args: {'keyword': '暴雨封路'},
    );
    expect(((rain.payload?['elements'] as List).single as Map)['selected'],
        isTrue);
  });

  test('the plot write tool is offered only for the graph target', () {
    const graph = CreateAssistantTarget.graph;
    const world = CreateAssistantTarget.world;

    expect(graph.toolAllowlist, contains('plot.select'));
    expect(graph.toolAllowlist, contains('plot.list_elements'));
    expect(world.toolAllowlist, isNot(contains('plot.select')));
    expect(world.toolAllowlist, contains('plot.list_elements'));
  });

  test('declarations use provider-safe tool names', () async {
    final client = _ScriptedTurnClient([
      const OpenAiChatCompletion(content: '好'),
    ]);
    final ctx = CreateToolContext(
      project: const ProjectFactory().createRainNightSample(),
      ai: _promptCtx(),
      services: CreateToolServices(toolClient: client),
    );

    await CreateAgentRunner().runTurn(
      target: CreateAssistantTarget.all,
      prompt: '看看',
      ctx: ctx,
    );

    final declarations = CreateToolRegistry()
        .declarations(CreateAssistantTarget.all.toolAllowlist);
    expect(declarations, isNotEmpty);
    final safe = RegExp(r'^[a-zA-Z0-9_-]+$');
    for (final tool in declarations) {
      // Gateways reject `tools[].function.name` with a dot
      // (`Invalid 'tools[0].function.name': string does not match pattern`).
      expect(safe.hasMatch(tool.name), isTrue, reason: tool.name);
    }
    expect(declarations.map((t) => t.name), contains('world_patch'));
    expect(declarations.map((t) => t.name), contains('main_read_graph'));
  });

  test('a wire name resolves back to the canonical tool', () async {
    final ctx = CreateToolContext(
      project: const ProjectFactory().createRainNightSample(),
      services: const CreateToolServices(),
    );

    final byWire = await CreateAgentRunner().runSingle(
      toolName: 'world_list_entries',
      ctx: ctx,
    );
    final byDot = await CreateAgentRunner().runSingle(
      toolName: 'world.list_entries',
      ctx: ctx,
    );

    expect(byWire.ok, isTrue);
    expect(byWire.payload?['total'], byDot.payload?['total']);
  });

  test('runTurn accepts a wire name in the model tool call', () async {
    final client = _ScriptedTurnClient([
      _call('world_patch', {
        'ops': [
          {'op': 'upsert_entry', 'title': '渡口', 'body': '夜里停摆。'},
        ],
      }),
      const OpenAiChatCompletion(content: ''),
    ]);
    final ctx = CreateToolContext(
      project: const ProjectFactory().createRainNightSample(),
      ai: _promptCtx(),
      services: CreateToolServices(toolClient: client),
    );

    final turn = await CreateAgentRunner().runTurn(
      target: CreateAssistantTarget.world,
      prompt: '加个渡口',
      ctx: ctx,
    );

    expect(turn.calledTools, ['world.patch']);
    expect(turn.proposals.single.kind, 'world.patch');
    // The replayed assistant turn carries the provider-safe name.
    final assistant = client.lastMessages.firstWhere(
      (m) => m.toolCalls.isNotEmpty,
    );
    expect(assistant.toolCalls.single.name, 'world_patch');
  });

  test('the all target may write every layer', () {
    const all = CreateAssistantTarget.all;

    expect(
      all.toolAllowlist,
      containsAll(<String>[
        'world.patch',
        'cast.patch',
        'main.patch',
        'main.replace',
        'plot.select',
      ]),
    );
    expect(all.toolAllowlist, contains('world.read_entry'));
    expect(all.toolAllowlist, contains('cast.read_member'));
  });

  test('runTurn stages changes from several layers in one turn', () async {
    final client = _ScriptedTurnClient(<OpenAiChatCompletion>[
      _call('world.patch', {
        'ops': [
          {'op': 'upsert_entry', 'title': '渡口', 'body': '夜里停摆。'},
        ],
      }),
      _call(
        'cast.patch',
        {
          'ops': [
            {'op': 'upsert_member', 'name': '船夫', 'summary': '摆渡人'},
          ],
        },
        index: 1,
      ),
      const OpenAiChatCompletion(content: ''),
    ]);
    final ctx = CreateToolContext(
      project: const ProjectFactory().createRainNightSample(),
      ai: _promptCtx(),
      services: CreateToolServices(toolClient: client),
    );

    final turn = await CreateAgentRunner().runTurn(
      target: CreateAssistantTarget.all,
      prompt: '补一个渡口，再加个船夫',
      ctx: ctx,
    );

    expect(turn.proposals.map((p) => p.kind), ['world.patch', 'cast.patch']);
    expect(turn.calledTools, ['world.patch', 'cast.patch']);
    // The staged tool reply did not end the turn: the second layer ran.
    final toolMessages = client.lastMessages.where((m) => m.role == 'tool');
    expect(toolMessages, hasLength(2));
    expect(toolMessages.first.content, contains('"staged":"world.patch"'));
  });

  test('runTurn merges two patches on the same layer', () async {
    final client = _ScriptedTurnClient(<OpenAiChatCompletion>[
      _call('world.patch', {
        'ops': [
          {'op': 'upsert_entry', 'title': '渡口', 'body': '夜里停摆。'},
        ],
      }),
      _call(
        'world.patch',
        {
          'ops': [
            {'op': 'upsert_entry', 'title': '船灯', 'body': '只在雨夜点亮。'},
          ],
        },
        index: 1,
      ),
      const OpenAiChatCompletion(content: ''),
    ]);
    final ctx = CreateToolContext(
      project: const ProjectFactory().createRainNightSample(),
      ai: _promptCtx(),
      services: CreateToolServices(toolClient: client),
    );

    final turn = await CreateAgentRunner().runTurn(
      target: CreateAssistantTarget.world,
      prompt: '加渡口和船灯',
      ctx: ctx,
    );

    expect(turn.proposals, hasLength(1));
    expect(turn.proposals.single.preview['kind'], 'world.patch');
    expect(turn.proposals.single.preview['opCount'], 2);
  });

  test('main.list_nodes lists stations without their exits detail', () async {
    final ctx = CreateToolContext(
      project: const ProjectFactory().createRainNightSample(),
      services: const CreateToolServices(),
    );

    final listed = await CreateAgentRunner().runSingle(
      toolName: 'main.list_nodes',
      ctx: ctx,
    );

    expect(listed.payload?['start'], 'n1');
    expect(listed.payload?['total'], 2);
    expect(listed.payload?['truncated'], isFalse);
    final nodes = (listed.payload?['nodes'] as List).cast<Map>();
    expect(nodes.map((n) => n['id']), containsAll(<String>['n1', 'n2']));
    expect(nodes.firstWhere((n) => n['id'] == 'n1')['exits'], 1);
    // A station row stays a row: no synopsis or edge detail.
    expect(nodes.first.keys, isNot(contains('synopsis')));

    final narrowed = await CreateAgentRunner().runSingle(
      toolName: 'main.list_nodes',
      ctx: ctx,
      args: {'keyword': '客栈'},
    );
    expect(narrowed.payload?['total'], 1);
  });

  test('main.get_node reads one station and its edges', () async {
    final ctx = CreateToolContext(
      project: const ProjectFactory().createRainNightSample(),
      services: const CreateToolServices(),
    );

    final read = await CreateAgentRunner().runSingle(
      toolName: 'main.get_node',
      ctx: ctx,
      args: {'ref': 'node:n2'},
    );

    expect(read.payload?['title'], '客栈');
    expect(read.payload?['isStart'], isFalse);
    expect(read.payload?['ending'], isFalse);
    final incoming = (read.payload?['incoming'] as List).cast<Map>();
    expect(incoming, hasLength(1));
    expect(incoming.single['from'], 'n1');
    expect(incoming.single['kind'], 'default');

    final field = await CreateAgentRunner().runSingle(
      toolName: 'main.get_node',
      ctx: ctx,
      args: {'ref': 'node:n2.title'},
    );
    expect(field.payload?['field'], 'title');
    expect(field.payload?['value'], '客栈');

    final missing = await CreateAgentRunner().runSingle(
      toolName: 'main.get_node',
      ctx: ctx,
      args: {'id': 'nope'},
    );
    expect(missing.ok, isFalse);
    expect(missing.errorMessage, '找不到这一站');
  });

  test('runTurn hands broken tool JSON back to the model instead of calling',
      () async {
    // Real shape from DeepSeek: quotes inside a Chinese value are unescaped.
    const broken = '{"ops":[{"op":"upsert_node","title":"入宗受辱",'
        '"synopsis":"同门唤他"扫地的""}]}';
    final client = _ScriptedTurnClient([
      OpenAiChatCompletion(
        content: '',
        toolCalls: const [
          OpenAiToolCall(id: 'call_broken', name: 'main.patch', arguments: broken),
        ],
      ),
      _call('main.patch', {
        'ops': [
          {'op': 'set_summary', 'summary': '修好后的概括'},
        ],
      }, index: 1),
      const OpenAiChatCompletion(content: ''),
    ]);
    final ctx = CreateToolContext(
      project: const ProjectFactory().createRainNightSample(),
      ai: _promptCtx(),
      services: CreateToolServices(toolClient: client),
    );

    final turn = await CreateAgentRunner().runTurn(
      target: CreateAssistantTarget.graph,
      prompt: '加一站',
      ctx: ctx,
    );

    // Unescaped quotes are repaired, so the op really lands.
    final ops = (turn.proposal!['ops'] as List).cast<Map>();
    final upsert = ops.firstWhere((op) => op['op'] == 'upsert_node');
    expect(upsert['synopsis'], '同门唤他"扫地的"');
    expect(turn.proposal?['summary'], '修好后的概括');
  });

  test('runTurn reports unparsable arguments and keeps going', () async {
    final client = _ScriptedTurnClient([
      const OpenAiChatCompletion(
        content: '',
        toolCalls: [
          OpenAiToolCall(
            id: 'call_cut',
            name: 'main.patch',
            arguments: '{"ops":[{"op":"upsert_node","title":"写到一半',
          ),
        ],
      ),
      _call('main.patch', {
        'ops': [
          {'op': 'set_summary', 'summary': '缩短后重新提交'},
        ],
      }, index: 1),
      const OpenAiChatCompletion(content: ''),
    ]);
    final ctx = CreateToolContext(
      project: const ProjectFactory().createRainNightSample(),
      ai: _promptCtx(),
      services: CreateToolServices(toolClient: client),
    );

    final turn = await CreateAgentRunner().runTurn(
      target: CreateAssistantTarget.graph,
      prompt: '加一站',
      ctx: ctx,
    );

    final toolMessages = client.lastMessages
        .where((m) => m.role == 'tool')
        .map((m) => m.content)
        .toList();
    expect(toolMessages.first, contains('不是合法 JSON'));
    expect(turn.proposal?['summary'], '缩短后重新提交');
  });

  test('runTurn grows a staged whole graph with a later main.patch', () async {
    final client = _ScriptedTurnClient([
      _call('main.replace', _decodeGraph(buildFullGraphJson()), index: 0),
      _call('main.patch', {
        'ops': [
          {'op': 'upsert_node', 'title': '追加站', 'synopsis': '下一批补上'},
          {'op': 'upsert_edge', 'from': '站5', 'to': '追加站', 'kind': 'branch'},
        ],
      }, index: 1),
      const OpenAiChatCompletion(content: ''),
    ]);
    final ctx = CreateToolContext(
      project: const ProjectFactory().createRainNightSample(),
      ai: _promptCtx(),
      services: CreateToolServices(toolClient: client),
    );

    final turn = await CreateAgentRunner().runTurn(
      target: CreateAssistantTarget.graph,
      prompt: '生成不少于 40 站的情节图',
      ctx: ctx,
    );

    // One merged proposal, not a replace plus a patch that would be dropped.
    expect(turn.proposals, hasLength(1));
    final preview = turn.proposals.single.preview;
    expect(preview['kind'], 'main.replace');
    expect(preview['nodeCount'], 22);
    final titles = (preview['stations'] as List)
        .cast<Map>()
        .map((s) => s['title'])
        .toList();
    expect(titles, contains('追加站'));
  });

  test('runTurn retries smaller when the reply is cut off by the length limit',
      () async {
    final client = _TruncatingTurnClient(
      truncations: 1,
      replies: [
        _call('main.replace', _decodeGraph(buildFullGraphJson()), index: 1),
        const OpenAiChatCompletion(content: ''),
      ],
    );
    final ctx = CreateToolContext(
      project: const ProjectFactory().createRainNightSample(),
      ai: _promptCtx(),
      services: CreateToolServices(toolClient: client),
    );

    final turn = await CreateAgentRunner().runTurn(
      target: CreateAssistantTarget.graph,
      prompt: '生成不少于 60 站的情节图',
      ctx: ctx,
    );

    // The turn survives: a smaller batch was asked for instead of failing.
    expect(turn.errorMessage, isNull);
    expect(turn.proposal?['kind'], 'main.replace');
    expect(
      client.lastMessages.where((m) => m.content.contains('触到输出上限')),
      hasLength(1),
    );
  });

  test('runTurn gives up after repeated truncation', () async {
    final client = _TruncatingTurnClient(truncations: 3, replies: const []);
    final ctx = CreateToolContext(
      project: const ProjectFactory().createRainNightSample(),
      ai: _promptCtx(),
      services: CreateToolServices(toolClient: client),
    );

    await expectLater(
      CreateAgentRunner().runTurn(
        target: CreateAssistantTarget.graph,
        prompt: '生成不少于 60 站的情节图',
        ctx: ctx,
      ),
      throwsA(
        isA<AiTextException>().having((e) => e.code, 'code', 'truncated'),
      ),
    );
    expect(client.calls, 3);
  });
}

Map<String, dynamic> _decodeGraph(String raw) {
  final decoded = json.decode(raw);
  return Map<String, dynamic>.from(decoded as Map);
}
