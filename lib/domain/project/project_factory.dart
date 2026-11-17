import 'package:anoworld/domain/models/background.dart';
import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/preset.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/models/side.dart';

/// Builds blank or sample projects for create / fixtures.
class ProjectFactory {
  const ProjectFactory();

  /// Empty but structurally valid shell: one node, one beat ending in `end`.
  Project createBlank({
    required String id,
    required String title,
    DateTime? now,
  }) {
    final stamp = now ?? DateTime.now().toUtc();
    const nodeId = 'n_start';
    const beatId = 'b_start';
    final preset = Preset.builtinDefault();
    return Project(
      meta: ProjectMeta(
        id: id,
        title: title,
        createdAt: stamp,
        updatedAt: stamp,
      ),
      presets: <Preset>[preset],
      activePresetId: preset.id,
      background: const Background(),
      cast: const <CastMember>[],
      main: MainStory(
        summary: '',
        startNodeId: nodeId,
        nodes: const <StoryNode>[
          StoryNode(
            id: nodeId,
            title: '开场',
            beatIds: <String>[beatId],
            tags: <String>['opening'],
          ),
        ],
        edges: const <StoryEdge>[],
        beats: const <Beat>[
          Beat(
            id: beatId,
            nodeId: nodeId,
            scene: Scene(),
            appearances: <Appearance>[],
            lines: <DialogueLine>[
              DialogueLine(
                id: 'l_placeholder',
                text: '（在这里开始故事）',
                kind: DialogueKind.narration,
              ),
            ],
            choices: <Choice>[
              Choice(
                id: 'ch_end',
                text: '结束',
                target: Transition(type: TransitionType.end),
              ),
            ],
          ),
        ],
      ),
      side: const SideBundle(),
      assets: const [],
    );
  }

  /// Linear two-node sample from docs/MainBeat.md §7.
  Project createRainNightSample({
    String id = 'proj_rain_night',
    String title = '雨夜投宿',
    DateTime? now,
  }) {
    final stamp = now ?? DateTime.now().toUtc();
    final preset = Preset.builtinDefault();
    return Project(
      meta: ProjectMeta(
        id: id,
        title: title,
        createdAt: stamp,
        updatedAt: stamp,
      ),
      presets: <Preset>[preset],
      activePresetId: preset.id,
      background: const Background(
        entries: <BackgroundEntry>[
          BackgroundEntry(
            id: 'bg_world',
            title: '世界观',
            body: '边陲小城外常有过路旅人；雨夜客栈是唯一歇脚处。',
            alwaysOn: true,
          ),
        ],
      ),
      cast: const <CastMember>[
        CastMember(
          id: 'c_hero',
          name: '少年',
          summary: '离家远行的旅人',
          personality: '沉着，话少',
          speechStyle: '短句',
        ),
        CastMember(
          id: 'c_keeper',
          name: '掌柜',
          summary: '客栈老板',
          personality: '精明但不坏',
          speechStyle: '口头禅多',
        ),
      ],
      main: MainStory(
        summary: '少年离家，雨夜投宿。',
        startNodeId: 'n1',
        nodes: const <StoryNode>[
          StoryNode(
            id: 'n1',
            title: '城门',
            synopsis: '离开',
            beatIds: <String>['b1'],
            layout: NodeLayout(x: 0, y: 0),
            tags: <String>['opening'],
          ),
          StoryNode(
            id: 'n2',
            title: '客栈',
            synopsis: '投宿',
            beatIds: <String>['b2'],
            layout: NodeLayout(x: 220, y: 0),
            tags: <String>['turning'],
          ),
        ],
        edges: const <StoryEdge>[
          StoryEdge(
            id: 'e1',
            from: 'n1',
            to: 'n2',
            kind: EdgeKind.defaultEdge,
          ),
        ],
        beats: const <Beat>[
          Beat(
            id: 'b1',
            nodeId: 'n1',
            scene: Scene(
              locationText: '城门',
              backgroundAssetId: 'bg_gate',
            ),
            appearances: <Appearance>[
              Appearance(characterId: 'c_hero', slot: AppearanceSlot.center),
            ],
            lines: <DialogueLine>[
              DialogueLine(
                id: 'l1',
                speakerId: 'c_hero',
                text: '该走了。',
              ),
            ],
            choices: <Choice>[],
          ),
          Beat(
            id: 'b2',
            nodeId: 'n2',
            scene: Scene(
              locationText: '客栈',
              backgroundAssetId: 'bg_inn',
            ),
            appearances: <Appearance>[
              Appearance(characterId: 'c_hero', slot: AppearanceSlot.left),
              Appearance(characterId: 'c_keeper', slot: AppearanceSlot.right),
            ],
            lines: <DialogueLine>[
              DialogueLine(
                id: 'l2',
                speakerId: 'c_keeper',
                text: '留宿？',
              ),
            ],
            choices: <Choice>[
              Choice(
                id: 'ch1',
                text: '住下',
                target: Transition(type: TransitionType.end),
              ),
              Choice(
                id: 'ch2',
                text: '再看看',
                target: Transition(type: TransitionType.beat, beatId: 'b2'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
