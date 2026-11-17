import 'package:anoworld/domain/models/background.dart';
import 'package:anoworld/domain/models/cast.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/story_node_kind.dart';
import 'package:anoworld/foundation/ai/json_candidate.dart';

/// Maps model JSON blobs into domain layers for staged create.
class StageResultMapper {
  const StageResultMapper();

  Background backgroundFromRaw(String raw) {
    final decoded = decodeJsonCandidate(raw);
    if (decoded is! Map) {
      throw const StageMapException('设定结果不是有效 JSON');
    }
    final map = Map<String, dynamic>.from(decoded);
    final sectionsRaw = map['sections'];
    if (sectionsRaw is! List || sectionsRaw.isEmpty) {
      throw const StageMapException('设定里没有可用的段落');
    }
    final entries = <BackgroundEntry>[];
    for (var i = 0; i < sectionsRaw.length; i++) {
      final item = sectionsRaw[i];
      if (item is! Map) continue;
      final row = Map<String, dynamic>.from(item);
      final title = _stringOf(row['title']) ?? '设定';
      final body = _stringOf(row['body']) ?? '';
      if (body.trim().isEmpty) continue;
      entries.add(
        BackgroundEntry(
          id: _stringOf(row['id']) ?? 'bg_$i',
          title: title.trim(),
          body: body.trim(),
          alwaysOn: true,
        ),
      );
    }
    if (entries.isEmpty) {
      throw const StageMapException('设定里没有可用的段落');
    }
    return Background(entries: entries);
  }

  List<CastMember> castFromRaw(String raw) {
    final decoded = decodeJsonCandidate(raw);
    if (decoded is! Map) {
      throw const StageMapException('角色结果不是有效 JSON');
    }
    final map = Map<String, dynamic>.from(decoded);
    final list = map['cast'];
    if (list is! List || list.isEmpty) {
      throw const StageMapException('没有可用的角色');
    }
    final cast = <CastMember>[];
    for (var i = 0; i < list.length; i++) {
      final item = list[i];
      if (item is! Map) continue;
      final row = Map<String, dynamic>.from(item);
      final name = _stringOf(row['name'])?.trim() ?? '';
      if (name.isEmpty) continue;
      cast.add(
        CastMember(
          id: _stringOf(row['id']) ?? 'c_$i',
          name: name,
          summary: _stringOf(row['summary'])?.trim() ?? '',
          personality: _stringOf(row['personality'])?.trim() ?? '',
          speechStyle: _stringOf(row['speechStyle'])?.trim() ?? '',
          exampleLines: _stringList(row['exampleLines']),
        ),
      );
    }
    if (cast.isEmpty) {
      throw const StageMapException('没有可用的角色');
    }
    return cast;
  }

  /// Builds a skeleton [MainStory]: stations + edges, empty beats.
  MainStory mainFromRaw(String raw, {required List<CastMember> cast}) {
    final decoded = decodeJsonCandidate(raw);
    if (decoded is! Map) {
      throw const StageMapException('情节结果不是有效 JSON');
    }
    final map = Map<String, dynamic>.from(decoded);
    final summary = _stringOf(map['summary'])?.trim() ?? '';

    // Prefer stations[]; fall back to legacy scenes[] titles only.
    final stationsRaw = map['stations'] ?? map['scenes'];
    if (stationsRaw is! List || stationsRaw.isEmpty) {
      throw const StageMapException('情节里没有可用的大站');
    }

    final stationMaps = <Map<String, dynamic>>[];
    for (final item in stationsRaw) {
      if (item is! Map) continue;
      final row = Map<String, dynamic>.from(item);
      final title = _stringOf(row['title'])?.trim();
      if (title == null || title.isEmpty) continue;
      stationMaps.add(row);
    }
    if (stationMaps.length < 2) {
      throw const StageMapException('至少需要两站情节');
    }

    final titleToId = <String, String>{};
    final nodes = <StoryNode>[];
    for (var i = 0; i < stationMaps.length; i++) {
      final row = stationMaps[i];
      final title = _stringOf(row['title'])!.trim();
      final nodeId = _stringOf(row['id'])?.trim().isNotEmpty == true
          ? _stringOf(row['id'])!.trim()
          : 'n_${i + 1}';
      final ending = row['ending'] == true ||
          title.startsWith('结局') ||
          (_stringList(row['tags']).contains('ending'));
      titleToId[title] = nodeId;
      nodes.add(
        StoryNode(
          id: nodeId,
          title: title,
          synopsis: _stringOf(row['synopsis'])?.trim(),
          beatIds: const <String>[],
          layout: NodeLayout(
            x: (i % 4) * 220.0,
            y: (i ~/ 4) * 140.0,
          ),
          tags: StoryNodeKind.apply(
            const <String>[],
            ending
                ? StoryNodeKind.ending
                : (i == 0 ? StoryNodeKind.opening : StoryNodeKind.scene),
          ),
        ),
      );
    }

    final edges = <StoryEdge>[];
    var edgeSeq = 0;

    void addEdge({
      required String fromId,
      required String toId,
      required EdgeKind kind,
      String? label,
    }) {
      if (fromId == toId) return;
      if (!nodes.any((n) => n.id == fromId) ||
          !nodes.any((n) => n.id == toId)) {
        return;
      }
      edgeSeq++;
      edges.add(
        StoryEdge(
          id: 'e_$edgeSeq',
          from: fromId,
          to: toId,
          kind: kind,
          label: label,
        ),
      );
    }

    // Top-level edges array (from/to by title or id).
    final edgesRaw = map['edges'];
    if (edgesRaw is List) {
      for (final item in edgesRaw) {
        if (item is! Map) continue;
        final row = Map<String, dynamic>.from(item);
        final fromKey = _stringOf(row['from'])?.trim();
        final toKey = _stringOf(row['to'])?.trim();
        if (fromKey == null || toKey == null) continue;
        final fromId = titleToId[fromKey] ??
            (nodes.any((n) => n.id == fromKey) ? fromKey : null);
        if (fromId == null) continue;
        if (toKey == 'end' || toKey == '结局') {
          final endId = _ensureEndingNode(
            nodes: nodes,
            titleToId: titleToId,
            label: _stringOf(row['label'])?.trim() ?? '结局',
          );
          addEdge(
            fromId: fromId,
            toId: endId,
            kind: _edgeKind(row['kind']),
            label: _stringOf(row['label'])?.trim(),
          );
          continue;
        }
        final toId = titleToId[toKey] ??
            (nodes.any((n) => n.id == toKey) ? toKey : null);
        if (toId == null) continue;
        addEdge(
          fromId: fromId,
          toId: toId,
          kind: _edgeKind(row['kind']),
          label: _stringOf(row['label'])?.trim(),
        );
      }
    }

    // Per-station exits.
    for (final row in stationMaps) {
      final title = _stringOf(row['title'])!.trim();
      final fromId = titleToId[title]!;
      final exits = row['exits'];
      if (exits is! List) continue;
      for (final exitItem in exits) {
        if (exitItem is! Map) continue;
        final exit = Map<String, dynamic>.from(exitItem);
        final toKey = _stringOf(exit['to'])?.trim();
        if (toKey == null || toKey.isEmpty) continue;
        if (toKey == 'end' || toKey == '结局') {
          final endId = _ensureEndingNode(
            nodes: nodes,
            titleToId: titleToId,
            label: _stringOf(exit['label'])?.trim() ?? '结局',
          );
          addEdge(
            fromId: fromId,
            toId: endId,
            kind: _edgeKind(exit['kind']),
            label: _stringOf(exit['label'])?.trim(),
          );
          continue;
        }
        final toId = titleToId[toKey];
        if (toId == null) continue;
        addEdge(
          fromId: fromId,
          toId: toId,
          kind: _edgeKind(exit['kind']),
          label: _stringOf(exit['label'])?.trim(),
        );
      }
    }

    // Linear defaults if model omitted edges.
    if (edges.isEmpty) {
      for (var i = 0; i < nodes.length - 1; i++) {
        if (nodes[i].tags.contains('ending')) continue;
        addEdge(
          fromId: nodes[i].id,
          toId: nodes[i + 1].id,
          kind: EdgeKind.defaultEdge,
        );
      }
      final lastPlayable = nodes.lastWhere(
        (n) => !n.tags.contains('ending'),
        orElse: () => nodes.first,
      );
      if (!edges.any((e) => e.from == lastPlayable.id)) {
        final endId = _ensureEndingNode(
          nodes: nodes,
          titleToId: titleToId,
          label: '结局',
        );
        addEdge(
          fromId: lastPlayable.id,
          toId: endId,
          kind: EdgeKind.defaultEdge,
        );
      }
    }

    // Prefer at least one branch when there are 3+ stations.
    final hasBranch = edges.any((e) => e.kind == EdgeKind.branch);
    if (!hasBranch && nodes.length >= 3) {
      final from = nodes.first;
      final alt = nodes[2];
      if (from.id != alt.id && !alt.tags.contains('ending')) {
        addEdge(
          fromId: from.id,
          toId: alt.id,
          kind: EdgeKind.branch,
          label: '另一条路',
        );
      }
    }

    // Every non-ending node needs an outbound edge.
    for (final node in List<StoryNode>.from(nodes)) {
      if (node.tags.contains('ending')) continue;
      if (edges.any((e) => e.from == node.id)) continue;
      final endId = _ensureEndingNode(
        nodes: nodes,
        titleToId: titleToId,
        label: '结局',
      );
      addEdge(
        fromId: node.id,
        toId: endId,
        kind: EdgeKind.defaultEdge,
      );
    }

    return MainStory(
      summary: summary.isEmpty ? nodes.first.title : summary,
      startNodeId: nodes.first.id,
      nodes: List<StoryNode>.unmodifiable(nodes),
      edges: List<StoryEdge>.unmodifiable(edges),
      beats: const <Beat>[],
    );
  }

  static String _ensureEndingNode({
    required List<StoryNode> nodes,
    required Map<String, String> titleToId,
    required String label,
  }) {
    final title = label.startsWith('结局') ? label : '结局：$label';
    final existing = titleToId[title];
    if (existing != null) return existing;
    final id = 'n_end_${nodes.length + 1}';
    titleToId[title] = id;
    nodes.add(
      StoryNode(
        id: id,
        title: title,
        synopsis: '故事在此收束',
        beatIds: const <String>[],
        layout: NodeLayout(x: nodes.length * 80.0, y: 280),
        tags: StoryNodeKind.apply(const <String>[], StoryNodeKind.ending),
      ),
    );
    return id;
  }

  static EdgeKind _edgeKind(Object? raw) {
    final s = _stringOf(raw)?.trim().toLowerCase();
    if (s == 'branch') return EdgeKind.branch;
    return EdgeKind.defaultEdge;
  }

  static String? _stringOf(Object? value) {
    if (value is String) return value;
    if (value == null) return null;
    return value.toString();
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
  }
}

class StageMapException implements Exception {
  const StageMapException(this.message);

  final String message;

  @override
  String toString() => message;
}
