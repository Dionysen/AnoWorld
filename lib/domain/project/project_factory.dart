import 'package:anoworld/domain/models/world_book.dart';
import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/models/side.dart';

/// Builds blank or sample projects for create / fixtures.
class ProjectFactory {
  const ProjectFactory();

  static const String openPlayNodeId = 'n_start';

  /// Working Main for play (not written back).
  ///
  /// - Empty nodes → inject a temporary opening station.
  /// - Non-ending nodes with **no outbound edges** drop end-only authored
  ///   beats (legacy blank「结束」placeholder) so play enters open-interval bridge.
  static MainStory ensurePlayableMain(MainStory main) {
    if (main.nodes.isEmpty) {
      return MainStory(
        summary: main.summary,
        startNodeId: openPlayNodeId,
        nodes: const <StoryNode>[
          StoryNode(
            id: openPlayNodeId,
            title: '开场',
            beatIds: <String>[],
            tags: <String>['opening'],
          ),
        ],
        edges: const <StoryEdge>[],
        beats: const <Beat>[],
      );
    }
    return _stripOpenIntervalDeadEnds(main);
  }

  /// True when every choice ends the run (legacy blank / soft dead-end).
  static bool isEndOnlyBeat(Beat beat) {
    if (beat.choices.isEmpty) return false;
    return beat.choices.every((c) => c.target.type == TransitionType.end);
  }

  static MainStory _stripOpenIntervalDeadEnds(MainStory main) {
    final openNodeIds = <String>{};
    for (final node in main.nodes) {
      if (node.tags.contains('ending')) continue;
      if (main.edges.any((e) => e.from == node.id)) continue;
      openNodeIds.add(node.id);
    }
    if (openNodeIds.isEmpty) return main;

    final dropBeatIds = <String>{};
    for (final beat in main.beats) {
      if (!openNodeIds.contains(beat.nodeId)) continue;
      if (isEndOnlyBeat(beat)) dropBeatIds.add(beat.id);
    }
    if (dropBeatIds.isEmpty) return main;

    final nodes = main.nodes
        .map((n) {
          if (!openNodeIds.contains(n.id)) return n;
          final ids =
              n.beatIds.where((id) => !dropBeatIds.contains(id)).toList();
          if (ids.length == n.beatIds.length) return n;
          return StoryNode(
            id: n.id,
            title: n.title,
            synopsis: n.synopsis,
            beatIds: ids,
            layout: n.layout,
            tags: n.tags,
          );
        })
        .toList(growable: false);
    final beats = main.beats
        .where((b) => !dropBeatIds.contains(b.id))
        .toList(growable: false);
    return MainStory(
      summary: main.summary,
      startNodeId: main.startNodeId,
      nodes: nodes,
      edges: main.edges,
      beats: beats,
    );
  }

  /// Empty but playable shell: one opening node with no authored beats.
  /// Play enters needsBridge for open-interval AI.
  Project createBlank({
    required String id,
    required String title,
    DateTime? now,
  }) {
    final stamp = now ?? DateTime.now().toUtc();
    return Project(
      meta: ProjectMeta(
        id: id,
        title: title,
        createdAt: stamp,
        updatedAt: stamp,
      ),
      worldBook: const WorldBook(),
      cast: const <CastMember>[],
      main: ensurePlayableMain(
        const MainStory(
          summary: '',
          startNodeId: openPlayNodeId,
          nodes: <StoryNode>[],
          edges: <StoryEdge>[],
          beats: <Beat>[],
        ),
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
    return Project(
      meta: ProjectMeta(
        id: id,
        title: title,
        createdAt: stamp,
        updatedAt: stamp,
      ),
      worldBook: const WorldBook(
        entries: <WorldBookEntry>[
          WorldBookEntry(
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
          isProtagonist: true,
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