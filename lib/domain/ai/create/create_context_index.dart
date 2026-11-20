import 'package:anoworld/domain/ai/create/create_assistant_target.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/settings/plot_element_catalog.dart';

/// Builds the always-injected L1 directory of the story layers.
///
/// Kept small on purpose: ids + one short line per entry, so the model can
/// decide what to read with `world.read_entry` / `cast.read_member` instead of
/// receiving every body up front.
class CreateContextIndex {
  const CreateContextIndex({this.maxLines = 80});

  /// Cap per layer list; longer layers end with `…（还有 N 条）`.
  final int maxLines;

  String build({
    required Project project,
    PlotElementCatalog? plotCatalog,
    required CreateAssistantTarget target,
  }) {
    final blocks = <String>[
      '【故事】${project.meta.title}',
      _worldBlock(project),
      _castBlock(project),
      _graphBlock(project),
      _plotBlock(project, plotCatalog),
      '【当前要改】${_targetLabel(target)}',
    ];
    return blocks.where((b) => b.trim().isNotEmpty).join('\n');
  }

  String _worldBlock(Project project) {
    final entries = project.worldBook.entries;
    if (entries.isEmpty) return '【设定】还没有条目';
    final shown = _cap(entries);
    final lines = <String>['【设定】共 ${entries.length} 条（ref: wb:<id>）'];
    for (final entry in shown.rows) {
      final flag = entry.alwaysOn ? ' · 常驻' : '';
      lines.add('- wb:${entry.id} · ${entry.title}$flag');
    }
    lines.addAll(shown.tail);
    return lines.join('\n');
  }

  String _castBlock(Project project) {
    final cast = project.cast;
    if (cast.isEmpty) return '【角色】还没有角色';
    final shown = _cap(cast);
    final lines = <String>['【角色】共 ${cast.length} 人（ref: cast:<id>）'];
    for (final member in shown.rows) {
      final summary = _clip(member.summary, 40);
      final brief = summary.isEmpty ? '' : ' · $summary';
      final star = member.isProtagonist ? '（主角）' : '';
      lines.add('- cast:${member.id} · ${member.name}$star$brief');
    }
    lines.addAll(shown.tail);
    return lines.join('\n');
  }

  String _graphBlock(Project project) {
    final main = project.main;
    if (!main.hasAuthoredNodes) return '【情节图】还没有情节图';
    final outDegree = <String, int>{};
    for (final edge in main.edges) {
      outDegree[edge.from] = (outDegree[edge.from] ?? 0) + 1;
    }
    final branches = main.edges.where((e) => e.kind == EdgeKind.branch).length;
    final shown = _cap(main.nodes);
    final lines = <String>[
      '【情节图】${main.nodes.length} 站 · ${main.edges.length} 条线'
          '（分支 $branches，ref: node:<id> / edge:<id>）',
    ];
    for (final node in shown.rows) {
      final exits = outDegree[node.id] ?? 0;
      final ending = node.tags.contains('ending') ? ' · 终局' : '';
      lines.add('- node:${node.id} · ${node.title} · 出边 $exits$ending');
    }
    lines.addAll(shown.tail);
    return lines.join('\n');
  }

  String _plotBlock(Project project, PlotElementCatalog? catalog) {
    final ids = project.plotElements.selectedIds;
    if (ids.isEmpty) return '【剧情元素】还没选';
    if (catalog == null) return '【剧情元素】已选 ${ids.length} 项';
    final rows = catalog.resolveSelected(ids);
    if (rows.isEmpty) return '【剧情元素】已选 ${ids.length} 项';
    final shown = _cap(rows);
    final lines = <String>['【剧情元素】已选 ${rows.length} 项'];
    for (final element in shown.rows) {
      final category = catalog.categoryNameOf(element.categoryId);
      final head = category.isEmpty ? '' : '$category · ';
      lines.add('- $head${element.keyword}');
    }
    lines.addAll(shown.tail);
    return lines.join('\n');
  }

  static String _targetLabel(CreateAssistantTarget target) => switch (target) {
        CreateAssistantTarget.graph => '情节图',
        CreateAssistantTarget.world => '世界书',
        CreateAssistantTarget.cast => '角色',
      };

  _Capped<T> _cap<T>(List<T> rows) {
    if (rows.length <= maxLines) return _Capped<T>(rows, const <String>[]);
    final rest = rows.length - maxLines;
    return _Capped<T>(
      rows.take(maxLines).toList(growable: false),
      <String>['…（还有 $rest 条）'],
    );
  }

  static String _clip(String text, int max) {
    final flat = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (flat.length <= max) return flat;
    return '${flat.substring(0, max)}…';
  }
}

class _Capped<T> {
  const _Capped(this.rows, this.tail);

  final List<T> rows;
  final List<String> tail;
}
