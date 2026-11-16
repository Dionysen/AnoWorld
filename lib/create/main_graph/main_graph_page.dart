import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/domain/main/main_graph_ops.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/foundation/graph/graph_models.dart';
import 'package:anoworld/foundation/graph/graph_viewport.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_empty_state.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/foundation/widgets/app_sheet.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/foundation/widgets/app_text_field.dart';
import 'package:flutter/material.dart';

/// Main skeleton editor: canvas (UX A) + optional card mode (UX B).
class MainGraphPage extends StatefulWidget {
  const MainGraphPage({super.key, required this.projectId});

  final String projectId;

  @override
  State<MainGraphPage> createState() => _MainGraphPageState();
}

class _MainGraphPageState extends State<MainGraphPage> {
  static const _ops = MainGraphOps();

  Project? _project;
  Object? _error;
  bool _loading = true;
  bool _cardMode = false;
  String? _selectedId;
  double _cardOffset = 0; // -1 left, 0 center, 1 right

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_project == null && _loading) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final project =
          await AppScope.projectsOf(context).open(widget.projectId);
      if (!mounted) return;
      setState(() {
        _project = project;
        _selectedId = project.main.startNodeId;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _persist(MainStory main) async {
    final project = _project;
    if (project == null) return;
    final next = project.copyWith(
      main: main,
      meta: project.meta.copyWith(updatedAt: DateTime.now().toUtc()),
    );
    await AppScope.projectsOf(context).save(next);
    if (!mounted) return;
    setState(() => _project = next);
  }

  List<GraphNodeData> _graphNodes(MainStory main) {
    return [
      for (final node in main.nodes)
        GraphNodeData(
          id: node.id,
          label: node.title,
          subtitle: node.synopsis,
          x: node.layout?.x ?? 40,
          y: node.layout?.y ?? 40,
        ),
    ];
  }

  List<GraphEdgeData> _graphEdges(MainStory main) {
    return [
      for (final edge in main.edges)
        GraphEdgeData(
          id: edge.id,
          fromId: edge.from,
          toId: edge.to,
          label: edge.label,
          emphasized: edge.kind == EdgeKind.branch,
        ),
    ];
  }

  Future<void> _addNode() async {
    final project = _project;
    if (project == null) return;
    final main = project.main;
    final id = MainGraphOps.newNodeId(main);
    final count = main.nodes.length;
    final node = StoryNode(
      id: id,
      title: '新情节',
      synopsis: '写清这一站要发生什么',
      beatIds: const [],
      layout: NodeLayout(x: 40 + (count % 4) * 180.0, y: 40 + (count ~/ 4) * 120.0),
      tags: const [],
    );
    // Need outbound eventually — tag ending so validator allows until linked.
    final withNode = _ops.upsertNode(
      main,
      StoryNode(
        id: node.id,
        title: node.title,
        synopsis: node.synopsis,
        beatIds: node.beatIds,
        layout: node.layout,
        tags: const ['ending'],
      ),
    );
    await _persist(withNode);
    setState(() => _selectedId = id);
  }

  Future<void> _deleteSelected() async {
    final project = _project;
    final id = _selectedId;
    if (project == null || id == null) return;
    if (project.main.nodes.length <= 1) return;
    await _persist(_ops.removeNode(project.main, id));
    setState(() => _selectedId = _project?.main.startNodeId);
  }

  Future<void> _connect(String fromId, String toId) async {
    final project = _project;
    if (project == null) return;
    var main = project.main;
    // Clear ending tag on source when it gains an exit.
    final from = main.nodeById(fromId);
    if (from != null && from.tags.contains('ending')) {
      main = _ops.upsertNode(
        main,
        StoryNode(
          id: from.id,
          title: from.title,
          synopsis: from.synopsis,
          beatIds: from.beatIds,
          layout: from.layout,
          tags: from.tags.where((t) => t != 'ending').toList(growable: false),
        ),
      );
    }
    main = _ops.addEdge(
      main,
      StoryEdge(
        id: MainGraphOps.newEdgeId(main),
        from: fromId,
        to: toId,
        kind: EdgeKind.defaultEdge,
      ),
    );
    await _persist(main);
  }

  Future<void> _openNodeEditor(String nodeId) async {
    final project = _project;
    if (project == null) return;
    final node = project.main.nodeById(nodeId);
    if (node == null) return;
    final title = TextEditingController(text: node.title);
    final synopsis = TextEditingController(text: node.synopsis ?? '');
    final outs = _ops.outgoing(project.main, nodeId);

    await showAppSheet<void>(
      context: context,
      size: AppSheetSize.half,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(AppTheme.spaceMd),
          child: ListView(
            children: [
              const AppSectionHeader('这一站'),
              AppTextField(label: '标题', controller: title),
              const SizedBox(height: AppTheme.spaceSm),
              AppTextField(
                label: '本站目标',
                controller: synopsis,
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: AppTheme.spaceMd),
              const AppText('连出去', role: AppTextRole.caption),
              const SizedBox(height: AppTheme.spaceXs),
              if (outs.isEmpty)
                const AppText('还没有连线，可在画布上从节点角标拉出', role: AppTextRole.caption)
              else
                ...outs.map((e) {
                  final to = project.main.nodeById(e.to)?.title ?? e.to;
                  return AppListTile(
                    title: to,
                    subtitle: e.kind == EdgeKind.branch ? '岔路' : '接着',
                    onTap: () async {
                      await _persist(_ops.removeEdge(project.main, e.id));
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                  );
                }),
              const SizedBox(height: AppTheme.spaceMd),
              AppButton(
                label: '保存',
                onPressed: () async {
                  final main = _ops.updateNodeMeta(
                    project.main,
                    nodeId: nodeId,
                    title: title.text.trim().isEmpty
                        ? node.title
                        : title.text.trim(),
                    synopsis: synopsis.text.trim(),
                  );
                  await _persist(main);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                expanded: true,
              ),
              const SizedBox(height: AppTheme.spaceSm),
              AppButton(
                label: '删除这一站',
                variant: AppButtonVariant.ghost,
                onPressed: project.main.nodes.length <= 1
                    ? null
                    : () async {
                        await _persist(_ops.removeNode(project.main, nodeId));
                        if (mounted) {
                          setState(
                            () => _selectedId = _project?.main.startNodeId,
                          );
                        }
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
              ),
            ],
          ),
        );
      },
    );
    title.dispose();
    synopsis.dispose();
  }

  Widget _buildCanvas(MainStory main) {
    return GraphViewport(
      nodes: _graphNodes(main),
      edges: _graphEdges(main),
      selectedId: _selectedId,
      onSelect: (id) => setState(() => _selectedId = id),
      onMove: (id, x, y) async {
        await _persist(
          _ops.moveNode(main, id, NodeLayout(x: x, y: y)),
        );
      },
      onConnect: _connect,
      onOpenNode: _openNodeEditor,
    );
  }

  Widget _buildCards(MainStory main) {
    final currentId = _selectedId ?? main.startNodeId;
    final node = main.nodeById(currentId);
    if (node == null) {
      return const AppEmptyState(message: '没有可选的情节站');
    }
    final outs = _ops.outgoing(main, node.id);
    final ins = _ops.incoming(main, node.id);
    final showOut = _cardOffset < -0.35;
    final showIn = _cardOffset > 0.35;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final cardW = w * 0.72;
        return GestureDetector(
          onHorizontalDragUpdate: (d) {
            setState(() {
              _cardOffset =
                  (_cardOffset + d.delta.dx / (w * 0.45)).clamp(-1.0, 1.0);
            });
          },
          onHorizontalDragEnd: (_) {
            setState(() {
              if (_cardOffset < -0.45) {
                _cardOffset = -1;
              } else if (_cardOffset > 0.45) {
                _cardOffset = 1;
              } else {
                _cardOffset = 0;
              }
            });
          },
          child: Stack(
            children: [
              if (showOut)
                Positioned(
                  right: AppTheme.spaceMd,
                  top: AppTheme.spaceLg,
                  bottom: AppTheme.spaceLg,
                  width: w * 0.42,
                  child: _linkList(
                    title: '连出去的站',
                    edges: outs,
                    main: main,
                    resolveTitle: (e) =>
                        main.nodeById(e.to)?.title ?? e.to,
                    onPick: (e) {
                      setState(() {
                        _selectedId = e.to;
                        _cardOffset = 0;
                      });
                    },
                  ),
                ),
              if (showIn)
                Positioned(
                  left: AppTheme.spaceMd,
                  top: AppTheme.spaceLg,
                  bottom: AppTheme.spaceLg,
                  width: w * 0.42,
                  child: _linkList(
                    title: '连进来的站',
                    edges: ins,
                    main: main,
                    resolveTitle: (e) =>
                        main.nodeById(e.from)?.title ?? e.from,
                    onPick: (e) {
                      setState(() {
                        _selectedId = e.from;
                        _cardOffset = 0;
                      });
                    },
                  ),
                ),
              Align(
                alignment: Alignment(_cardOffset * 0.85, 0),
                child: GestureDetector(
                  onTap: () {
                    if (_cardOffset.abs() > 0.2) {
                      setState(() => _cardOffset = 0);
                    } else {
                      _openNodeEditor(node.id);
                    }
                  },
                  child: SizedBox(
                    width: cardW,
                    child: Material(
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(
                        AppTheme.spaceMd,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.spaceMd),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText(node.title, role: AppTextRole.title),
                            if (node.synopsis != null &&
                                node.synopsis!.isNotEmpty) ...[
                              const SizedBox(height: AppTheme.spaceSm),
                              AppText(
                                node.synopsis!,
                                role: AppTextRole.body,
                                maxLines: 4,
                              ),
                            ],
                            const SizedBox(height: AppTheme.spaceSm),
                            AppText(
                              showOut
                                  ? '右半边是连出去的站'
                                  : showIn
                                      ? '左半边是连进来的站'
                                      : '左右滑查看连接',
                              role: AppTextRole.caption,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _linkList({
    required String title,
    required List<StoryEdge> edges,
    required MainStory main,
    required String Function(StoryEdge) resolveTitle,
    required ValueChanged<StoryEdge> onPick,
  }) {
    if (edges.isEmpty) {
      return AppEmptyState(message: '这一侧没有连接', detail: title);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppText(title, role: AppTextRole.caption),
        const SizedBox(height: AppTheme.spaceSm),
        Expanded(
          child: ListView.separated(
            itemCount: edges.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: AppTheme.spaceXs),
            itemBuilder: (_, i) {
              final e = edges[i];
              return AppListTile(
                title: resolveTitle(e),
                subtitle: e.label,
                onTap: () => onPick(e),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final project = _project;
    return AppPage(
      title: '情节走向',
      onBack: () => Navigator.of(context).maybePop(),
      actions: [
        if (!_loading && project != null) ...[
          AppButton(
            label: _cardMode ? '画布' : '小屏卡片',
            variant: AppButtonVariant.ghost,
            onPressed: () => setState(() {
              _cardMode = !_cardMode;
              _cardOffset = 0;
            }),
          ),
        ],
      ],
      body: _loading
          ? const AppPageBody(
              children: [AppText('加载中…', role: AppTextRole.caption)],
            )
          : _error != null
              ? AppPageBody(
                  children: [
                    AppEmptyState(
                      message: '打不开情节图',
                      detail: _error.toString(),
                      action: AppButton(
                        label: '重试',
                        onPressed: _load,
                        variant: AppButtonVariant.secondary,
                      ),
                    ),
                  ],
                )
              : project == null
                  ? const AppPageBody(
                      children: [AppEmptyState(message: '没有作品')],
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppTheme.spaceMd,
                            AppTheme.spaceSm,
                            AppTheme.spaceMd,
                            0,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: AppButton(
                                  label: '加一站',
                                  onPressed: _addNode,
                                  variant: AppButtonVariant.secondary,
                                ),
                              ),
                              const SizedBox(width: AppTheme.spaceSm),
                              Expanded(
                                child: AppButton(
                                  label: '编辑选中',
                                  onPressed: _selectedId == null
                                      ? null
                                      : () => _openNodeEditor(_selectedId!),
                                  variant: AppButtonVariant.secondary,
                                ),
                              ),
                              const SizedBox(width: AppTheme.spaceSm),
                              Expanded(
                                child: AppButton(
                                  label: '删除选中',
                                  onPressed: _selectedId == null
                                      ? null
                                      : _deleteSelected,
                                  variant: AppButtonVariant.ghost,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppTheme.spaceSm),
                        Expanded(
                          child: _cardMode
                              ? _buildCards(project.main)
                              : _buildCanvas(project.main),
                        ),
                      ],
                    ),
    );
  }
}
