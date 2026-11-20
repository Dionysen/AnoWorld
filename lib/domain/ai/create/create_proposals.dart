import 'dart:convert';

import 'package:anoworld/domain/ai/create/create_assistant_target.dart';
import 'package:anoworld/domain/ai/stage_result_mapper.dart';
import 'package:anoworld/domain/main/apply_cast_patch.dart';
import 'package:anoworld/domain/main/apply_main_graph_patch.dart';
import 'package:anoworld/domain/main/apply_plot_patch.dart';
import 'package:anoworld/domain/main/apply_world_book_patch.dart';
import 'package:anoworld/domain/main/main_graph_document.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/settings/plot_element_catalog.dart';
import 'package:anoworld/domain/validation/project_validator.dart';
import 'package:anoworld/foundation/ai/json_candidate.dart';

/// Turns model-produced content (tool arguments or a JSON reply) into the
/// confirm payload the panel already knows how to review.
///
/// Pure validation + shaping: nothing is written here. Callers catch
/// [CreateProposalException] and hand the message back to the model.
class CreateProposals {
  const CreateProposals({
    this.mapper = const StageResultMapper(),
    this.validator = const ProjectValidator(),
  });

  final StageResultMapper mapper;
  final ProjectValidator validator;

  /// Whole-graph rewrite (`summary` + `stations`), validated by dry-applying.
  Map<String, dynamic> replaceGraph(
      Project project, Map<String, dynamic> args) {
    final MainStory main;
    try {
      main = mapper.mainFromRaw(
        jsonEncode(args),
        cast: project.cast,
        enforceMinStations: true,
      );
    } on StageMapException catch (error) {
      throw CreateProposalException(error.message);
    }
    return replaceGraphFromMain(project, main);
  }

  /// Same preview for a graph that arrived over several tool calls in one turn
  /// (a 60-station story does not fit in one reply).
  Map<String, dynamic> replaceGraphFromMain(Project project, MainStory main) {
    _requireValid(project, main);
    return <String, dynamic>{
      'schemaVersion': 1,
      'kind': 'main.replace',
      'summary': main.summary,
      'nodeCount': main.nodes.length,
      'branchCount': main.edges.where((e) => e.kind == EdgeKind.branch).length,
      'stations': [
        for (final node in main.nodes)
          <String, dynamic>{
            'title': node.title,
            if (node.synopsis != null) 'synopsis': node.synopsis,
            'ending': node.tags.contains('ending'),
          },
      ],
      'graph': MainGraphDocument.encode(main),
    };
  }

  /// Incremental graph ops.
  Map<String, dynamic> patchGraph(Project project, Map<String, dynamic> args) {
    final ops = readOps(args);
    final MainStory next;
    try {
      next = const ApplyMainGraphPatch().apply(project.main, ops);
    } on ApplyMainGraphPatchException catch (error) {
      throw CreateProposalException(error.message);
    }
    _requireValid(project, next);
    return <String, dynamic>{
      'schemaVersion': 1,
      'kind': 'main.patch',
      'opCount': ops.length,
      'ops': ops,
      'summary': next.summary,
      'nodeCount': next.nodes.length,
      'stations': [
        for (final node in next.nodes)
          <String, dynamic>{
            'title': node.title,
            if (node.synopsis != null) 'synopsis': node.synopsis,
            'ending': node.tags.contains('ending'),
          },
      ],
      'graph': MainGraphDocument.encode(next),
    };
  }

  Map<String, dynamic> patchWorldBook(
    Project project,
    Map<String, dynamic> args,
  ) {
    final ops = readOps(args);
    try {
      final next = const ApplyWorldBookPatch().apply(project.worldBook, ops);
      return <String, dynamic>{
        'schemaVersion': 1,
        'kind': 'world.patch',
        'opCount': ops.length,
        'ops': ops,
        'entryCount': next.entries.length,
        'entries': [
          for (final entry in next.entries)
            <String, dynamic>{
              'id': entry.id,
              'title': entry.title,
              'alwaysOn': entry.alwaysOn,
            },
        ],
        'worldBook': next.toJson(),
      };
    } on ApplyWorldBookPatchException catch (error) {
      throw CreateProposalException(error.message);
    }
  }

  Map<String, dynamic> patchCast(Project project, Map<String, dynamic> args) {
    final ops = readOps(args);
    try {
      final next = const ApplyCastPatch().apply(project.cast, ops);
      return <String, dynamic>{
        'schemaVersion': 1,
        'kind': 'cast.patch',
        'opCount': ops.length,
        'ops': ops,
        'castCount': next.length,
        'cast': [
          for (final member in next)
            <String, dynamic>{
              'id': member.id,
              'name': member.name,
              'isProtagonist': member.isProtagonist,
            },
        ],
        'members': [for (final member in next) member.toJson()],
      };
    } on ApplyCastPatchException catch (error) {
      throw CreateProposalException(error.message);
    }
  }

  /// Story plot-element selection ops (`plot.select`).
  Map<String, dynamic> patchPlot(
    Project project,
    PlotElementCatalog catalog,
    Map<String, dynamic> args,
  ) {
    final ops = readOps(args);
    try {
      final next = const ApplyPlotPatch().apply(
        PlotPatchState(
          catalog: catalog,
          selection: project.plotElements,
        ),
        ops,
      );
      return <String, dynamic>{
        'schemaVersion': 1,
        'kind': 'plot.select',
        'opCount': ops.length,
        'ops': ops,
        'selectedIds': next.selection.selectedIds,
        'selectedCount': next.selection.selectedIds.length,
      };
    } on ApplyPlotPatchException catch (error) {
      throw CreateProposalException(error.message);
    }
  }

  /// Proposal from a plain-text reply, or null when the text is not one.
  ///
  /// Keeps models without tool support usable: they answer with the JSON that
  /// used to be the only contract, and it becomes the same confirm payload.
  /// Throws [CreateProposalException] when it does parse as a proposal but the
  /// content is unusable, so the caller can pass the reason to the user.
  Map<String, dynamic>? fromText({
    required CreateAssistantTarget target,
    required Project project,
    required String raw,
    PlotElementCatalog? catalog,
  }) {
    final decoded = decodeJsonCandidate(raw);
    if (decoded is! Map) return null;
    final map = Map<String, dynamic>.from(decoded);
    switch (target) {
      case CreateAssistantTarget.world:
        return map.containsKey('ops') ? patchWorldBook(project, map) : null;
      case CreateAssistantTarget.cast:
        return map.containsKey('ops') ? patchCast(project, map) : null;
      case CreateAssistantTarget.graph:
        if (map.containsKey('stations')) return replaceGraph(project, map);
        if (map.containsKey('ops')) return patchGraph(project, map);
        return null;
      case CreateAssistantTarget.all:
        if (map.containsKey('stations')) return replaceGraph(project, map);
        if (!map.containsKey('ops')) return null;
        return _allKindFromOps(project, catalog, map);
    }
  }

  /// Cross-layer text replies have no target to tell the layer apart, so the
  /// op names decide which builder validates them.
  Map<String, dynamic> _allKindFromOps(
    Project project,
    PlotElementCatalog? catalog,
    Map<String, dynamic> map,
  ) {
    final names = <String>{};
    final ops = map['ops'];
    if (ops is List) {
      for (final op in ops) {
        if (op is Map) names.add(op['op']?.toString() ?? '');
      }
    }
    if (names.any((n) => n == 'upsert_entry' || n == 'remove_entry')) {
      return patchWorldBook(project, map);
    }
    if (names.any((n) => n == 'upsert_member' || n == 'remove_member')) {
      return patchCast(project, map);
    }
    if (names.any(
      (n) => n == 'select' || n == 'deselect' || n == 'add_element',
    )) {
      if (catalog == null) {
        throw const CreateProposalException('剧情元素库还没准备好');
      }
      return patchPlot(project, catalog, map);
    }
    return patchGraph(project, map);
  }

  /// Ops carried by `args`; throws when the list is empty or malformed.
  static List<Map<String, dynamic>> readOps(Map<String, dynamic> args) {
    final raw = args['ops'];
    if (raw is! List || raw.isEmpty) {
      throw const CreateProposalException('缺少 ops');
    }
    final ops = <Map<String, dynamic>>[];
    for (final item in raw) {
      if (item is Map) ops.add(Map<String, dynamic>.from(item));
    }
    if (ops.isEmpty) throw const CreateProposalException('ops 全都不认识');
    return ops;
  }

  void _requireValid(Project project, MainStory main) {
    final result = validator.validate(project.copyWith(main: main));
    if (!result.hasErrors) return;
    final messages = result.errors.map((e) => e.message).toSet().join('；');
    throw CreateProposalException('改完后情节不完整：$messages');
  }
}

class CreateProposalException implements Exception {
  const CreateProposalException(this.message);

  final String message;

  @override
  String toString() => message;
}
