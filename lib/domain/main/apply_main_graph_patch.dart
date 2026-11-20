import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/story_node_kind.dart';

/// Applies a list of graph ops onto [base]. Beats on removed nodes are dropped;
/// beats on kept nodes are preserved.
class ApplyMainGraphPatch {
  const ApplyMainGraphPatch();

  MainStory apply(MainStory base, List<Map<String, dynamic>> ops) {
    var summary = base.summary;
    final nodes = Map<String, StoryNode>.from(
      {for (final n in base.nodes) n.id: n},
    );
    final edges = Map<String, StoryEdge>.from(
      {for (final e in base.edges) e.id: e},
    );
    var startId = base.startNodeId;
    var nodeSeq = nodes.length;
    var edgeSeq = edges.length;

    String resolveNodeKey(String key) {
      final trimmed = key.trim();
      if (nodes.containsKey(trimmed)) return trimmed;
      for (final node in nodes.values) {
        if (node.title == trimmed) return node.id;
      }
      throw ApplyMainGraphPatchException('找不到站：$trimmed');
    }

    for (final raw in ops) {
      final op = (raw['op']?.toString() ?? '').trim();
      switch (op) {
        case 'set_summary':
          final next = raw['summary']?.toString().trim() ?? '';
          if (next.isNotEmpty) summary = next;
        case 'upsert_node':
          final title = raw['title']?.toString().trim() ?? '';
          if (title.isEmpty) {
            throw const ApplyMainGraphPatchException('站名不能为空');
          }
          final ending = raw['ending'] == true ||
              title.startsWith('结局') ||
              ((raw['tags'] is List) &&
                  (raw['tags'] as List).contains('ending'));
          final synopsis = raw['synopsis']?.toString().trim();
          final givenId = raw['id']?.toString().trim();
          final id = (givenId != null && givenId.isNotEmpty)
              ? givenId
              : () {
                  nodeSeq++;
                  return 'n_p_$nodeSeq';
                }();
          final existing = nodes[id];
          nodes[id] = StoryNode(
            id: id,
            title: title,
            synopsis: (synopsis == null || synopsis.isEmpty)
                ? existing?.synopsis
                : synopsis,
            beatIds: existing?.beatIds ?? const <String>[],
            layout: existing?.layout ??
                NodeLayout(x: (nodes.length % 5) * 220.0, y: (nodes.length ~/ 5) * 140.0),
            tags: StoryNodeKind.apply(
              existing?.tags ?? const <String>[],
              ending
                  ? StoryNodeKind.ending
                  : (existing != null
                      ? StoryNodeKind.fromTags(existing.tags)
                      : StoryNodeKind.scene),
            ),
          );
        case 'remove_node':
          final id = raw['id']?.toString().trim() ?? '';
          if (id.isEmpty || !nodes.containsKey(id)) {
            throw ApplyMainGraphPatchException('删不了站：$id');
          }
          if (nodes.length <= 1) {
            throw const ApplyMainGraphPatchException('至少留下一站');
          }
          nodes.remove(id);
          edges.removeWhere((_, e) => e.from == id || e.to == id);
          if (startId == id) {
            startId = nodes.keys.first;
          }
        case 'upsert_edge':
          final fromKey = raw['from']?.toString().trim() ?? '';
          final toKey = raw['to']?.toString().trim() ?? '';
          if (fromKey.isEmpty || toKey.isEmpty) {
            throw const ApplyMainGraphPatchException('连线缺少起点或终点');
          }
          final fromId = resolveNodeKey(fromKey);
          String toId;
          if (toKey == 'end' || toKey == '结局') {
            toId = _ensureEnding(nodes, label: raw['label']?.toString());
          } else {
            toId = resolveNodeKey(toKey);
          }
          final kind = (raw['kind']?.toString().trim().toLowerCase() == 'branch')
              ? EdgeKind.branch
              : EdgeKind.defaultEdge;
          final label = raw['label']?.toString().trim();
          final detail = raw['detail']?.toString().trim();
          final givenId = raw['id']?.toString().trim();
          final id = (givenId != null && givenId.isNotEmpty)
              ? givenId
              : () {
                  edgeSeq++;
                  return 'e_p_$edgeSeq';
                }();
          final existing = edges[id];
          edges[id] = StoryEdge(
            id: id,
            from: fromId,
            to: toId,
            kind: kind,
            label: (label == null || label.isEmpty) ? existing?.label : label,
            detail: (detail == null || detail.isEmpty)
                ? existing?.detail
                : detail,
            priority: existing?.priority ?? 0,
          );
        case 'remove_edge':
          final id = raw['id']?.toString().trim() ?? '';
          if (id.isEmpty || !edges.containsKey(id)) {
            throw ApplyMainGraphPatchException('删不了连线：$id');
          }
          edges.remove(id);
        default:
          if (op.isNotEmpty) {
            throw ApplyMainGraphPatchException('不支持的操作：$op');
          }
      }
    }

    if (!nodes.containsKey(startId)) {
      startId = nodes.keys.first;
    }

    final keptBeatIds = <String>{
      for (final node in nodes.values) ...node.beatIds,
    };
    final beats = base.beats
        .where((b) => keptBeatIds.contains(b.id) && nodes.containsKey(b.nodeId))
        .toList(growable: false);

    return MainStory(
      summary: summary,
      startNodeId: startId,
      nodes: List<StoryNode>.unmodifiable(nodes.values),
      edges: List<StoryEdge>.unmodifiable(edges.values),
      beats: beats,
    );
  }

  static String _ensureEnding(Map<String, StoryNode> nodes, {String? label}) {
    final title = (label != null && label.trim().isNotEmpty)
        ? (label.trim().startsWith('结局') ? label.trim() : '结局：${label.trim()}')
        : '结局';
    for (final node in nodes.values) {
      if (node.title == title || node.tags.contains('ending')) {
        return node.id;
      }
    }
    final id = 'n_end_${nodes.length + 1}';
    nodes[id] = StoryNode(
      id: id,
      title: title.startsWith('结局') ? title : '结局：$title',
      synopsis: '故事在此收束',
      beatIds: const <String>[],
      layout: NodeLayout(x: nodes.length * 80.0, y: 280),
      tags: StoryNodeKind.apply(const <String>[], StoryNodeKind.ending),
    );
    return id;
  }
}

class ApplyMainGraphPatchException implements Exception {
  const ApplyMainGraphPatchException(this.message);

  final String message;

  @override
  String toString() => message;
}
