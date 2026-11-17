import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/validation/project_issue.dart';

/// Structural checks before export / play (docs/MainBeat.md §4).
class ProjectValidator {
  const ProjectValidator();

  ProjectValidationResult validate(Project project) {
    final issues = <ProjectIssue>[];
    _validateMeta(project, issues);
    _validateMain(project, issues);
    return ProjectValidationResult(List<ProjectIssue>.unmodifiable(issues));
  }

  void _validateMeta(Project project, List<ProjectIssue> issues) {
    if (project.meta.id.trim().isEmpty) {
      issues.add(
        const ProjectIssue(
          severity: ProjectIssueSeverity.error,
          code: 'meta_id_empty',
          message: 'Project id is empty',
          path: r'$.meta.id',
        ),
      );
    }
    if (project.meta.title.trim().isEmpty) {
      issues.add(
        const ProjectIssue(
          severity: ProjectIssueSeverity.error,
          code: 'meta_title_empty',
          message: 'Project title is empty',
          path: r'$.meta.title',
        ),
      );
    }
  }

  void _validateMain(Project project, List<ProjectIssue> issues) {
    final main = project.main;
    if (main.nodes.isEmpty) {
      // Play can inject a temporary opening node; not a hard block.
      issues.add(
        const ProjectIssue(
          severity: ProjectIssueSeverity.warning,
          code: 'nodes_empty',
          message: 'Main has no nodes; play will use an open opening station',
          path: r'$.main.nodes',
        ),
      );
      return;
    }

    final nodeIds = <String>{};
    for (final node in main.nodes) {
      if (!nodeIds.add(node.id)) {
        issues.add(
          ProjectIssue(
            severity: ProjectIssueSeverity.error,
            code: 'node_id_duplicate',
            message: 'Duplicate node id "${node.id}"',
            path: r'$.main.nodes',
          ),
        );
      }
    }

    if (!nodeIds.contains(main.startNodeId)) {
      issues.add(
        ProjectIssue(
          severity: ProjectIssueSeverity.error,
          code: 'start_node_missing',
          message: 'startNodeId "${main.startNodeId}" does not exist',
          path: r'$.main.startNodeId',
        ),
      );
    } else {
      final start = main.nodeById(main.startNodeId);
      if (start != null && start.beatIds.isEmpty) {
        // Bridge AI may fill start; warn when skeleton-only.
        issues.add(
          ProjectIssue(
            severity: ProjectIssueSeverity.warning,
            code: 'start_node_empty',
            message: 'startNodeId "${main.startNodeId}" has empty beatIds',
            path: r'$.main.startNodeId',
          ),
        );
      }
    }

    final beatIds = <String>{};
    final beatsById = <String, Beat>{};
    for (final beat in main.beats) {
      if (!beatIds.add(beat.id)) {
        issues.add(
          ProjectIssue(
            severity: ProjectIssueSeverity.error,
            code: 'beat_id_duplicate',
            message: 'Duplicate beat id "${beat.id}"',
            path: r'$.main.beats',
          ),
        );
      }
      beatsById[beat.id] = beat;
      if (!nodeIds.contains(beat.nodeId)) {
        issues.add(
          ProjectIssue(
            severity: ProjectIssueSeverity.error,
            code: 'beat_node_missing',
            message:
                'Beat "${beat.id}" references missing node "${beat.nodeId}"',
            path: '\$.main.beats.${beat.id}.nodeId',
          ),
        );
      }
      for (final appearance in beat.appearances) {
        if (project.castById(appearance.characterId) == null) {
          issues.add(
            ProjectIssue(
              severity: ProjectIssueSeverity.error,
              code: 'appearance_cast_missing',
              message:
                  'Beat "${beat.id}" references missing cast "${appearance.characterId}"',
              path: '\$.main.beats.${beat.id}.appearances',
            ),
          );
        }
      }
      for (final line in beat.lines) {
        final speakerId = line.speakerId;
        if (speakerId != null && project.castById(speakerId) == null) {
          issues.add(
            ProjectIssue(
              severity: ProjectIssueSeverity.error,
              code: 'speaker_cast_missing',
              message: 'Line "${line.id}" references missing cast "$speakerId"',
              path: '\$.main.beats.${beat.id}.lines',
            ),
          );
        }
      }
    }

    for (final node in main.nodes) {
      if (node.beatIds.isEmpty) {
        issues.add(
          ProjectIssue(
            severity: ProjectIssueSeverity.warning,
            code: 'node_without_beats',
            message: 'Node "${node.id}" has no beats (bridge AI expected)',
            path: '\$.main.nodes.${node.id}',
          ),
        );
        final hasOut = main.edges.any((e) => e.from == node.id);
        final isEnding = node.tags.contains('ending');
        if (!hasOut && !isEnding) {
          // Open-interval play: bridge AI continues with stay choices.
          issues.add(
            ProjectIssue(
              severity: ProjectIssueSeverity.warning,
              code: 'node_open_interval',
              message:
                  'Node "${node.id}" has no outbound edges; open-interval AI play',
              path: '\$.main.nodes.${node.id}',
            ),
          );
        }
        if ((node.synopsis == null || node.synopsis!.trim().isEmpty) &&
            !isEnding) {
          issues.add(
            ProjectIssue(
              severity: ProjectIssueSeverity.warning,
              code: 'node_synopsis_empty',
              message: 'Node "${node.id}" has empty synopsis',
              path: '\$.main.nodes.${node.id}.synopsis',
            ),
          );
        }
      }
      for (final beatId in node.beatIds) {
        final beat = beatsById[beatId];
        if (beat == null) {
          issues.add(
            ProjectIssue(
              severity: ProjectIssueSeverity.error,
              code: 'node_beat_missing',
              message: 'Node "${node.id}" lists missing beat "$beatId"',
              path: '\$.main.nodes.${node.id}.beatIds',
            ),
          );
          continue;
        }
        if (beat.nodeId != node.id) {
          issues.add(
            ProjectIssue(
              severity: ProjectIssueSeverity.error,
              code: 'beat_node_mismatch',
              message:
                  'Beat "$beatId" belongs to "${beat.nodeId}" but is listed on "${node.id}"',
              path: '\$.main.nodes.${node.id}.beatIds',
            ),
          );
        }
      }
    }

    final edgeIds = <String>{};
    for (final edge in main.edges) {
      if (!edgeIds.add(edge.id)) {
        issues.add(
          ProjectIssue(
            severity: ProjectIssueSeverity.error,
            code: 'edge_id_duplicate',
            message: 'Duplicate edge id "${edge.id}"',
            path: r'$.main.edges',
          ),
        );
      }
      if (!nodeIds.contains(edge.from) || !nodeIds.contains(edge.to)) {
        issues.add(
          ProjectIssue(
            severity: ProjectIssueSeverity.error,
            code: 'edge_endpoint_missing',
            message:
                'Edge "${edge.id}" references missing node (${edge.from} → ${edge.to})',
            path: '\$.main.edges.${edge.id}',
          ),
        );
      }
    }

    for (final beat in main.beats) {
      for (final choice in beat.choices) {
        _validateTransition(
          main: main,
          nodeIds: nodeIds,
          beatsById: beatsById,
          transition: choice.target,
          path: '\$.main.beats.${beat.id}.choices.${choice.id}.target',
          issues: issues,
        );
      }
    }

    _validateDeadEnds(main, issues);
    _validateReachability(main, nodeIds, issues);
  }

  void _validateTransition({
    required MainStory main,
    required Set<String> nodeIds,
    required Map<String, Beat> beatsById,
    required Transition transition,
    required String path,
    required List<ProjectIssue> issues,
  }) {
    switch (transition.type) {
      case TransitionType.beat:
        final beatId = transition.beatId;
        if (beatId == null || beatId.isEmpty) {
          issues.add(
            ProjectIssue(
              severity: ProjectIssueSeverity.error,
              code: 'transition_beat_required',
              message: 'Transition type beat requires beatId',
              path: path,
            ),
          );
          return;
        }
        if (!beatsById.containsKey(beatId)) {
          issues.add(
            ProjectIssue(
              severity: ProjectIssueSeverity.error,
              code: 'transition_beat_missing',
              message: 'Transition targets missing beat "$beatId"',
              path: path,
            ),
          );
        }
      case TransitionType.node:
        final nodeId = transition.nodeId;
        if (nodeId == null || nodeId.isEmpty) {
          issues.add(
            ProjectIssue(
              severity: ProjectIssueSeverity.error,
              code: 'transition_node_required',
              message: 'Transition type node requires nodeId',
              path: path,
            ),
          );
          return;
        }
        if (!nodeIds.contains(nodeId)) {
          issues.add(
            ProjectIssue(
              severity: ProjectIssueSeverity.error,
              code: 'transition_node_missing',
              message: 'Transition targets missing node "$nodeId"',
              path: path,
            ),
          );
          return;
        }
        final node = main.nodeById(nodeId);
        if (node != null && node.beatIds.isEmpty) {
          issues.add(
            ProjectIssue(
              severity: ProjectIssueSeverity.warning,
              code: 'transition_node_empty',
              message:
                  'Transition targets node "$nodeId" with empty beatIds (bridge)',
              path: path,
            ),
          );
        }
      case TransitionType.end:
        break;
    }
  }

  void _validateDeadEnds(MainStory main, List<ProjectIssue> issues) {
    for (final node in main.nodes) {
      if (node.beatIds.isEmpty) continue;
      final lastBeat = main.beatById(node.beatIds.last);
      if (lastBeat == null) continue;
      if (lastBeat.choices.isNotEmpty) continue;
      final hasDefaultEdge = main.edges.any(
        (e) => e.from == node.id && e.kind == EdgeKind.defaultEdge,
      );
      if (!hasDefaultEdge) {
        issues.add(
          ProjectIssue(
            severity: ProjectIssueSeverity.error,
            code: 'node_dead_end',
            message:
                'Node "${node.id}" ends with no choices and no default edge',
            path: '\$.main.nodes.${node.id}',
          ),
        );
      }
    }
  }

  void _validateReachability(
    MainStory main,
    Set<String> nodeIds,
    List<ProjectIssue> issues,
  ) {
    if (!nodeIds.contains(main.startNodeId)) return;
    final reachable = <String>{};
    final queue = <String>[main.startNodeId];
    while (queue.isNotEmpty) {
      final id = queue.removeLast();
      if (!reachable.add(id)) continue;
      final node = main.nodeById(id);
      if (node == null) continue;
      for (final edge in main.edges) {
        if (edge.from == id) queue.add(edge.to);
      }
      for (final beatId in node.beatIds) {
        final beat = main.beatById(beatId);
        if (beat == null) continue;
        for (final choice in beat.choices) {
          final target = choice.target;
          switch (target.type) {
            case TransitionType.node:
              final nodeId = target.nodeId;
              if (nodeId != null) queue.add(nodeId);
            case TransitionType.beat:
              final beatTarget = target.beatId == null
                  ? null
                  : main.beatById(target.beatId!);
              if (beatTarget != null) queue.add(beatTarget.nodeId);
            case TransitionType.end:
              break;
          }
        }
      }
    }
    for (final id in nodeIds) {
      if (!reachable.contains(id)) {
        issues.add(
          ProjectIssue(
            severity: ProjectIssueSeverity.warning,
            code: 'node_unreachable',
            message: 'Node "$id" is unreachable from start',
            path: '\$.main.nodes.$id',
          ),
        );
      }
    }
  }
}
