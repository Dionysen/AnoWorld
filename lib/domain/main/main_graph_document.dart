import 'dart:convert';

import 'package:anoworld/domain/models/json_map.dart';
import 'package:anoworld/domain/models/main_story.dart';

/// Encode / decode the main graph for persistence and AI prompts.
///
/// - [encode] / [decode]: full [MainStory] wire format (project package).
/// - [encodeSkeleton] / [decodeSkeleton]: nodes + edges (+ summary), no beats;
///   intended for AI generation and as compact prompt context.
abstract final class MainGraphDocument {
  static const skeletonFormat = 'anoworld.main_graph.skeleton';
  static const skeletonVersion = 1;

  static Map<String, dynamic> encode(MainStory main) => main.toJson();

  static MainStory decode(Map<String, dynamic> json) =>
      MainStory.fromJson(json);

  static String encodeJson(MainStory main, {bool pretty = false}) {
    final map = encode(main);
    return pretty
        ? const JsonEncoder.withIndent('  ').convert(map)
        : jsonEncode(map);
  }

  static MainStory decodeJson(String raw) {
    final decoded = jsonDecode(raw);
    return decode(asJsonMap(decoded, path: 'main'));
  }

  /// Compact graph for prompts / model output (layout optional).
  static Map<String, dynamic> encodeSkeleton(
    MainStory main, {
    bool includeLayout = true,
  }) {
    return <String, dynamic>{
      'format': skeletonFormat,
      'version': skeletonVersion,
      'summary': main.summary,
      'startNodeId': main.startNodeId,
      'nodes': [
        for (final n in main.nodes)
          <String, dynamic>{
            'id': n.id,
            'title': n.title,
            if (n.synopsis != null) 'synopsis': n.synopsis,
            if (n.tags.isNotEmpty) 'tags': n.tags,
            if (includeLayout && n.layout != null) 'layout': n.layout!.toJson(),
          },
      ],
      'edges': [
        for (final e in main.edges) e.toJson(),
      ],
    };
  }

  static String encodeSkeletonJson(
    MainStory main, {
    bool includeLayout = true,
    bool pretty = true,
  }) {
    final map = encodeSkeleton(main, includeLayout: includeLayout);
    return pretty
        ? const JsonEncoder.withIndent('  ').convert(map)
        : jsonEncode(map);
  }

  /// Accepts skeleton JSON or a full [MainStory] map (beats default to empty
  /// when omitted).
  static MainStory decodeSkeleton(Map<String, dynamic> json) {
    final hasBeats = json.containsKey('beats');
    if (hasBeats) {
      return MainStory.fromJson(json);
    }
    return MainStory(
      summary: json.requireString('summary'),
      startNodeId: json.requireString('startNodeId'),
      nodes: json.requireList('nodes').map((item) {
        final node = asJsonMap(item, path: 'nodes[]');
        return StoryNode(
          id: node.requireString('id'),
          title: node.requireString('title'),
          synopsis: node.optionalString('synopsis'),
          beatIds: node.stringList('beatIds', required: false),
          layout: node.optionalMap('layout') == null
              ? null
              : NodeLayout.fromJson(node.requireMap('layout')),
          tags: node.stringList('tags', required: false),
        );
      }).toList(growable: false),
      edges: json
          .requireList('edges')
          .map((item) => StoryEdge.fromJson(asJsonMap(item, path: 'edges[]')))
          .toList(growable: false),
      beats: const [],
    );
  }

  static MainStory decodeSkeletonJson(String raw) {
    final decoded = jsonDecode(raw);
    return decodeSkeleton(asJsonMap(decoded, path: 'main_graph'));
  }
}
