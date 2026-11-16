import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/create/main_graph/story_node_kind_style.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/ai/expand_edge_detail_action.dart';
import 'package:anoworld/domain/main/main_graph_layout.dart';
import 'package:anoworld/domain/main/main_graph_ops.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/models/story_node_kind.dart';
import 'package:anoworld/foundation/graph/graph_models.dart';
import 'package:anoworld/foundation/graph/graph_node_card.dart';
import 'package:anoworld/foundation/graph/graph_viewport.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_empty_state.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/foundation/widgets/app_select_field.dart';
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
  String? _selectedEdgeId;
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
          badgeLabel: StoryNodeKind.fromTags(node.tags).label,
          badgeColor: StoryNodeKindStyle.color(
            StoryNodeKind.fromTags(node.tags),
          ),
          inputLabel: '进入',
          x: node.layout?.x ?? 40,
          y: node.layout?.y ?? 40,
          outputs: [
            for (final edge in _ops.outgoing(main, node.id))
              GraphOutputPort(
                id: edge.id,
                label: edge.label?.trim().isNotEmpty == true
                    ? edge.label
                    : (edge.kind == EdgeKind.branch ? '岔路' : '继续'),
              ),
            const GraphOutputPort(
              id: GraphOutputPort.pendingId,
              pending: true,
              label: '添加',
            ),
          ],
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
          fromPortId: edge.id,
        ),
    ];
  }

  Future<void> _autoLayout() async {
    final project = _project;
    if (project == null) return;
    final graph = _graphNodes(project.main);
    final widths = <String, double>{
      for (final n in graph) n.id: n.resolvedWidth,
    };
    final heights = <String, double>{
      for (final n in graph) n.id: n.resolvedHeight,
    };
    await _persist(
      MainGraphLayout.arrange(
        project.main,
        widths: widths,
        heights: heights,
      ),
    );
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
      layout: NodeLayout(
        x: 40 + (count % 4) * 200.0,
        y: 40 + (count ~/ 4) * 140.0,
      ),
      // Ending until linked so empty stations stay playable/valid.
      tags: StoryNodeKind.apply(const [], StoryNodeKind.ending),
    );
    final withNode = _ops.upsertNode(main, node);
    await _persist(withNode);
    setState(() {
      _selectedId = id;
      _selectedEdgeId = null;
    });
  }

  Future<void> _deleteSelected() async {
    final project = _project;
    if (project == null) return;
    final edgeId = _selectedEdgeId;
    if (edgeId != null) {
      await _persist(_ops.removeEdge(project.main, edgeId));
      if (!mounted) return;
      setState(() => _selectedEdgeId = null);
      return;
    }
    final id = _selectedId;
    if (id == null) return;
    if (project.main.nodes.length <= 1) return;
    await _persist(_ops.removeNode(project.main, id));
    if (!mounted) return;
    setState(() {
      _selectedId = _project?.main.startNodeId;
      _selectedEdgeId = null;
    });
  }

  Future<void> _connect(
    String fromId,
    String toId,
    String fromPortId,
  ) async {
    final project = _project;
    if (project == null || fromId == toId) return;
    var main = project.main;
    final from = main.nodeById(fromId);
    if (from != null &&
        StoryNodeKind.fromTags(from.tags) == StoryNodeKind.ending) {
      main = _ops.setNodeKind(main, fromId, StoryNodeKind.scene);
    }

    StoryEdge? existing;
    for (final edge in main.edges) {
      if (edge.id == fromPortId) {
        existing = edge;
        break;
      }
    }
    if (existing != null) {
      await _persist(
        _ops.upsertEdge(main, existing.copyWith(to: toId)),
      );
      return;
    }

    final already = main.edges.any((e) => e.from == fromId);
    await _persist(
      _ops.addEdge(
        main,
        StoryEdge(
          id: MainGraphOps.newEdgeId(main),
          from: fromId,
          to: toId,
          kind: already ? EdgeKind.branch : EdgeKind.defaultEdge,
        ),
      ),
    );
  }

  Future<void> _openNodeEditor(String nodeId) async {
    final project = _project;
    if (project == null) return;
    final node = project.main.nodeById(nodeId);
    if (node == null) return;
    final title = TextEditingController(text: node.title);
    final synopsis = TextEditingController(text: node.synopsis ?? '');
    var kind = StoryNodeKind.fromTags(node.tags);
    final outs = _ops.outgoing(project.main, nodeId);

    await showAppSheet<void>(
      context: context,
      size: AppSheetSize.compact,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  AppSelectField(
                    label: '种类',
                    value: kind.label,
                    onTap: () async {
                      final picked = await showAppSheet<StoryNodeKind>(
                        context: ctx,
                        size: AppSheetSize.compact,
                        builder: (pickCtx) {
                          return Padding(
                            padding: const EdgeInsets.all(AppTheme.spaceMd),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (final k in StoryNodeKind.values)
                                  AppListTile(
                                    title: k.label,
                                    onTap: () =>
                                        Navigator.of(pickCtx).pop(k),
                                  ),
                              ],
                            ),
                          );
                        },
                      );
                      if (picked != null) {
                        setSheetState(() => kind = picked);
                      }
                    },
                  ),
                  const SizedBox(height: AppTheme.spaceMd),
                  const AppText('连出去', role: AppTextRole.caption),
                  const SizedBox(height: AppTheme.spaceXs),
                  if (outs.isEmpty)
                    const AppText(
                      '还没有连线：从右侧插头拖到下一站左侧',
                      role: AppTextRole.caption,
                    )
                  else
                    ...outs.map((e) {
                      final to = project.main.nodeById(e.to)?.title ?? e.to;
                      final title = e.label?.trim().isNotEmpty == true
                          ? e.label!
                          : (e.kind == EdgeKind.branch ? '岔路' : '继续');
                      return AppListTile(
                        title: title,
                        subtitle: '通向$to',
                        onTap: () async {
                          Navigator.of(ctx).pop();
                          await _openEdgeEditor(e.id);
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
                        kind: kind,
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
                            await _persist(
                              _ops.removeNode(project.main, nodeId),
                            );
                            if (mounted) {
                              setState(
                                () => _selectedId =
                                    _project?.main.startNodeId,
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
      },
    );
    title.dispose();
    synopsis.dispose();
  }

  Future<void> _openEdgeEditor(String edgeId) async {
    final project = _project;
    if (project == null) return;
    StoryEdge? edge;
    for (final e in project.main.edges) {
      if (e.id == edgeId) {
        edge = e;
        break;
      }
    }
    if (edge == null) return;

    final from = project.main.nodeById(edge.from);
    final to = project.main.nodeById(edge.to);
    await showAppSheet<void>(
      context: context,
      size: AppSheetSize.half,
      builder: (ctx) {
        return _EdgeEditorBody(
          edge: edge!,
          from: from,
          to: to,
          onSave: (next) async {
            await _persist(_ops.upsertEdge(project.main, next));
          },
          onDelete: () async {
            await _persist(_ops.removeEdge(project.main, edge!.id));
          },
        );
      },
    );
  }

  void _tipAddOutput() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('拖到下一站左侧插头，就能连上')),
    );
  }

  Widget _buildCanvas(MainStory main) {
    return GraphViewport(
      nodes: _graphNodes(main),
      edges: _graphEdges(main),
      selectedId: _selectedId,
      selectedEdgeId: _selectedEdgeId,
      onSelect: (id) => setState(() {
        _selectedId = id;
        if (id != null) _selectedEdgeId = null;
      }),
      onSelectEdge: (id) => setState(() {
        _selectedEdgeId = id;
        if (id != null) _selectedId = null;
      }),
      onMove: (id, x, y) async {
        await _persist(
          _ops.moveNode(main, id, NodeLayout(x: x, y: y)),
        );
      },
      onConnect: _connect,
      onOpenOutput: (_, portId) => _openEdgeEditor(portId),
      onAddOutput: (_) => _tipAddOutput(),
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GraphNodeCard(
                        title: node.title,
                        subtitle: node.synopsis,
                        badgeLabel:
                            StoryNodeKind.fromTags(node.tags).label,
                        badgeColor: StoryNodeKindStyle.color(
                          StoryNodeKind.fromTags(node.tags),
                        ),
                        selected: true,
                        elevated: true,
                        width: cardW,
                        titleMaxLines: 2,
                        subtitleMaxLines: 4,
                      ),
                      const SizedBox(height: AppTheme.spaceSm),
                      AppText(
                        showOut
                            ? '右半边是连出去的站'
                            : showIn
                                ? '左半边是连进来的站'
                                : '左右滑查看连接',
                        role: AppTextRole.caption,
                        textAlign: TextAlign.center,
                      ),
                    ],
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
                                  label: '整理排版',
                                  onPressed: _autoLayout,
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
                                  onPressed: _selectedId == null &&
                                          _selectedEdgeId == null
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

class _EdgeEditorBody extends StatefulWidget {
  const _EdgeEditorBody({
    required this.edge,
    required this.from,
    required this.to,
    required this.onSave,
    required this.onDelete,
  });

  final StoryEdge edge;
  final StoryNode? from;
  final StoryNode? to;
  final Future<void> Function(StoryEdge next) onSave;
  final Future<void> Function() onDelete;

  @override
  State<_EdgeEditorBody> createState() => _EdgeEditorBodyState();
}

class _EdgeEditorBodyState extends State<_EdgeEditorBody> {
  late final TextEditingController _title;
  late final TextEditingController _detail;
  var _busy = false;
  String? _aiError;

  @override
  void initState() {
    super.initState();
    final fallback =
        widget.edge.kind == EdgeKind.branch ? '岔路' : '继续';
    _title = TextEditingController(
      text: widget.edge.label?.trim().isNotEmpty == true
          ? widget.edge.label!
          : fallback,
    );
    _detail = TextEditingController(text: widget.edge.detail ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _detail.dispose();
    super.dispose();
  }

  Future<void> _expandWithAi() async {
    setState(() {
      _busy = true;
      _aiError = null;
    });
    try {
      final expanded = await ExpandEdgeDetailAction(
        textClient: AppScope.textClientOf(context),
      ).expand(
        endpoint: AppScope.settingsOf(context).ai.text,
        title: _title.text,
        detail: _detail.text,
        fromTitle: widget.from?.title,
        fromSynopsis: widget.from?.synopsis,
        toTitle: widget.to?.title,
        toSynopsis: widget.to?.synopsis,
      );
      if (!mounted) return;
      setState(() {
        _detail.text = expanded;
        _busy = false;
      });
    } on AiTextException catch (error) {
      if (!mounted) return;
      setState(() {
        _aiError = error.message;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _aiError = '没写出来，请稍后再试';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSectionHeader(
            '这条路',
            subtitle: '通向${widget.to?.title ?? widget.edge.to}',
          ),
          AppTextField(label: '标题', controller: _title),
          const SizedBox(height: AppTheme.spaceSm),
          AppTextField(
            label: '详细说明',
            controller: _detail,
            minLines: 3,
            maxLines: 8,
          ),
          const SizedBox(height: AppTheme.spaceXs),
          const AppText(
            '可以只写关键词，再让 AI 帮你展开',
            role: AppTextRole.caption,
          ),
          if (_aiError != null) ...[
            const SizedBox(height: AppTheme.spaceSm),
            AppText(_aiError!, role: AppTextRole.caption),
          ],
          const SizedBox(height: AppTheme.spaceMd),
          AppButton(
            label: _busy ? '正在写…' : '让 AI 写详细一点',
            variant: AppButtonVariant.secondary,
            onPressed: _busy ? null : _expandWithAi,
            expanded: true,
          ),
          const SizedBox(height: AppTheme.spaceSm),
          AppButton(
            label: '保存',
            onPressed: _busy
                ? null
                : () async {
                    final labelText = _title.text.trim();
                    final detailText = _detail.text.trim();
                    await widget.onSave(
                      widget.edge.copyWith(
                        label: labelText.isEmpty ? null : labelText,
                        detail: detailText.isEmpty ? null : detailText,
                        clearLabel: labelText.isEmpty,
                        clearDetail: detailText.isEmpty,
                      ),
                    );
                    if (context.mounted) Navigator.of(context).pop();
                  },
            expanded: true,
          ),
          const SizedBox(height: AppTheme.spaceSm),
          AppButton(
            label: '删掉这条连线',
            variant: AppButtonVariant.ghost,
            onPressed: _busy
                ? null
                : () async {
                    await widget.onDelete();
                    if (context.mounted) Navigator.of(context).pop();
                  },
          ),
        ],
      ),
    );
  }
}
