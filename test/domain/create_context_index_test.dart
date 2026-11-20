import 'package:anoworld/domain/ai/create/create_assistant_target.dart';
import 'package:anoworld/domain/ai/create/create_context_index.dart';
import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/plot_element.dart';
import 'package:anoworld/domain/project/project_factory.dart';
import 'package:anoworld/domain/settings/plot_element_catalog.dart';
import 'package:anoworld/foundation/ai/st_prompt_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const index = CreateContextIndex();
  final project = const ProjectFactory().createRainNightSample();

  test('lists ids, titles and layer sizes but no bodies', () {
    final text = index.build(
      project: project,
      target: CreateAssistantTarget.graph,
    );

    expect(text, contains('【故事】雨夜投宿'));
    expect(text, contains('wb:bg_world · 世界观 · 常驻'));
    expect(text, contains('cast:c_hero · 少年（主角） · 离家远行的旅人'));
    expect(text, contains('node:n1 · 城门 · 出边 1'));
    expect(text, contains('node:n2 · 客栈 · 出边 0'));
    expect(text, contains('【当前要改】情节图'));
    // The L1 directory must stay an index: no entry bodies.
    expect(text, isNot(contains('边陲小城外常有过路旅人')));
  });

  test('marks endings and branch counts', () {
    final withEnding = project.copyWith(
      main: const MainStory(
        summary: '少年离家，雨夜投宿。',
        startNodeId: 'n1',
        nodes: <StoryNode>[
          StoryNode(id: 'n1', title: '城门', beatIds: <String>[]),
          StoryNode(
            id: 'n2',
            title: '客栈',
            beatIds: <String>[],
            tags: <String>['ending'],
          ),
        ],
        edges: <StoryEdge>[
          StoryEdge(
            id: 'e1',
            from: 'n1',
            to: 'n2',
            kind: EdgeKind.defaultEdge,
          ),
          StoryEdge(
            id: 'e2',
            from: 'n1',
            to: 'n2',
            kind: EdgeKind.branch,
            label: '翻墙',
          ),
        ],
        beats: <Beat>[],
      ),
    );

    final text = index.build(
      project: withEnding,
      target: CreateAssistantTarget.graph,
    );

    expect(text, contains('2 站 · 2 条线（分支 1'));
    expect(text, contains('node:n2 · 客栈 · 出边 0 · 终局'));
  });

  test('caps long layers with a remainder note', () {
    final many = project.copyWith(
      cast: [
        for (var i = 0; i < 5; i++) CastMember(id: 'c$i', name: '角色$i'),
      ],
    );

    final text = const CreateContextIndex(maxLines: 2).build(
      project: many,
      target: CreateAssistantTarget.cast,
    );

    expect(text, contains('【角色】共 5 人'));
    expect(text, contains('…（还有 3 条）'));
    expect(text, isNot(contains('cast:c4')));
  });

  test('names selected plot elements by category', () {
    final catalog = PlotElementCatalog();
    final ids = catalog.effectiveList.take(2).map((e) => e.id).toList();
    final withPlot = project.copyWith(
      plotElements: PlotElementSelection(selectedIds: ids),
    );

    final text = index.build(
      project: withPlot,
      plotCatalog: catalog,
      target: CreateAssistantTarget.world,
    );

    expect(text, contains('【剧情元素】已选 2 项'));
    expect(text, contains('【当前要改】世界书'));
  });

  test('says so when a layer is empty', () {
    final empty = project.copyWith(cast: const <CastMember>[]);

    final text = index.build(
      project: empty,
      target: CreateAssistantTarget.cast,
    );

    expect(text, contains('【角色】还没有角色'));
  });

  test('the all target names every editable layer', () {
    final text = index.build(
      project: project,
      target: CreateAssistantTarget.all,
    );

    expect(text, contains('【当前要改】全部'));
    expect(text, contains('世界书'));
    expect(text, contains('情节图'));
  });

  test('names the preset sections as read-only rules', () {
    const config = PromptManagerConfig(
      sections: <PromptSection>[
        PromptSection(
          type: PromptSectionType.systemPrompt,
          name: 'System Prompt',
          content: '只存在于系统提示里的正文',
          order: 0,
        ),
      ],
    );

    final text = index.build(
      project: project,
      presetManager: config,
      target: CreateAssistantTarget.world,
    );

    expect(text, contains('【预设】1 段'));
    expect(text, contains('只读'));
    expect(text, contains('- System Prompt'));
    // Section bodies stay in the system prompt itself, not in the index.
    expect(text, isNot(contains('只存在于系统提示里的正文')));
  });

  test('flags disabled preset sections', () {
    const config = PromptManagerConfig(
      sections: <PromptSection>[
        PromptSection(
          type: PromptSectionType.systemPrompt,
          name: 'System Prompt',
          order: 0,
        ),
        PromptSection(
          type: PromptSectionType.nsfw,
          name: 'NSFW Prompt',
          enabled: false,
          order: 1,
        ),
      ],
    );

    final text = index.build(
      project: project,
      presetManager: config,
      target: CreateAssistantTarget.world,
    );

    expect(text, contains('【预设】2 段'));
    expect(text, contains('- System Prompt'));
    expect(text, contains('- NSFW Prompt · 关'));
  });

  test('omits the preset block when no manager is given', () {
    final text = index.build(
      project: project,
      target: CreateAssistantTarget.world,
    );

    expect(text, isNot(contains('【预设】')));
  });
}
