import 'dart:async';

import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/data/project/graph_node_thumbnail_files.dart';
import 'package:anoworld/create/main_graph/main_graph_view_nav.dart';
import 'package:anoworld/create/main_graph/story_node_kind_style.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/ai/expand_edge_detail_action.dart';
import 'package:anoworld/domain/main/main_graph_layout.dart';
import 'package:anoworld/domain/main/main_graph_ops.dart';
import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/models/story_node_kind.dart';
import 'package:anoworld/foundation/graph/graph_models.dart';
import 'package:anoworld/foundation/graph/graph_node_thumbnail.dart';
import 'package:anoworld/foundation/graph/graph_overview_map.dart';
import 'package:anoworld/foundation/graph/graph_viewport.dart';
import 'package:anoworld/foundation/graph/graph_viewport_controller.dart';
import 'package:anoworld/foundation/history/undo_stack.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_circle_button.dart';
import 'package:anoworld/foundation/widgets/app_empty_state.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_nav_shell.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/foundation/widgets/app_select_field.dart';
import 'package:anoworld/foundation/widgets/app_docked_panel.dart';
import 'package:anoworld/foundation/widgets/app_sheet.dart';
import 'package:anoworld/foundation/widgets/app_switch.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/foundation/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Main skeleton editor: canvas (UX A) + focus camera for small screens (UX B).
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
  bool _overviewOpen = false;
  bool _showGrid = false;
  String? _selectedId;
  String? _selectedEdgeId;
  final Map<String, Uint8List> _nodeThumbnails = {};
  final _viewportCamera = GraphViewportController();
  final _overviewPanelKey = GlobalKey<AppDockedPanelState>();
  final _history = UndoStack();
  Timer? _saveDebounce;
  MainStory? _dragOriginMain;

  @override
  void initState() {
    super.initState();
    _history.addListener(_onHistoryChanged);
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _history.removeListener(_onHistoryChanged);
    _history.dispose();
    _viewportCamera.dispose();
    super.dispose();
  }

  void _onHistoryChanged() {
    if (mounted) setState(() {});
  }

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
      _history.clear();
      _dragOriginMain = null;
      setState(() {
        _project = project;
        _selectedId = project.main.startNodeId;
        _loading = false;
      });
      await _loadThumbnailsFromDisk();
      if (mounted) {
        // ignore: unawaited_futures
        _refreshNodeThumbnails(project.main);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _applyMain(
    MainStory main, {
    required bool refreshThumbnails,
  }) async {
    final project = _project;
    if (project == null) return;
    final next = project.copyWith(
      main: main,
      meta: project.meta.copyWith(updatedAt: DateTime.now().toUtc()),
    );
    setState(() => _project = next);
    await AppScope.projectsOf(context).save(next);
    if (!mounted) return;
    if (refreshThumbnails) {
      // ignore: unawaited_futures
      _refreshNodeThumbnails(next.main);
    }
  }

  Future<void> _persist(
    MainStory main, {
    bool refreshThumbnails = true,
  }) async {
    final project = _project;
    if (project == null) return;
    final before = project.main;
    if (!_history.isReplaying && !identical(before, main)) {
      _history.addSwap<MainStory>(
        before: before,
        after: main,
        apply: (snapshot) {
          // ignore: unawaited_futures
          _applyMain(snapshot, refreshThumbnails: true);
        },
      );
    }
    await _applyMain(main, refreshThumbnails: refreshThumbnails);
  }

  /// Layout drag: update UI immediately, debounce disk write, skip thumbnails.
  /// One undo step is recorded on [GraphViewport.onNodeDragEnd].
  void _moveNodeLocal(String id, double x, double y) {
    final project = _project;
    if (project == null) return;
    _dragOriginMain ??= project.main;
    final main = _ops.moveNode(project.main, id, NodeLayout(x: x, y: y));
    setState(() {
      _project = project.copyWith(
        main: main,
        meta: project.meta.copyWith(updatedAt: DateTime.now().toUtc()),
      );
    });
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 280), () async {
      final latest = _project;
      if (latest == null || !mounted) return;
      await AppScope.projectsOf(context).save(latest);
    });
  }

  void _onNodeDragEnd() {
    final origin = _dragOriginMain;
    final project = _project;
    _dragOriginMain = null;
    if (origin == null || project == null) return;
    if (identical(origin, project.main)) return;
    _history.addSwap<MainStory>(
      before: origin,
      after: project.main,
      apply: (snapshot) {
        // ignore: unawaited_futures
        _applyMain(snapshot, refreshThumbnails: false);
      },
    );
  }

  void _undo() => _history.undo();

  void _redo() => _history.redo();

  Future<void> _openMoreMenu() async {
    await showAppSheet<void>(
      context: context,
      size: AppSheetSize.compact,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.pagePadding,
                AppTheme.spaceXs,
                AppTheme.pagePadding,
                AppTheme.spaceMd,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AppSectionHeader('画布'),
                  AppListTile(
                    title: '显示网格',
                    subtitle: '缩放时自动调整间距',
                    icon: Icons.grid_on_outlined,
                    trailing: AppSwitch(
                      value: _showGrid,
                      onChanged: (value) {
                        setState(() => _showGrid = value);
                        setSheetState(() {});
                      },
                    ),
                    onTap: () {
                      setState(() => _showGrid = !_showGrid);
                      setSheetState(() {});
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _loadThumbnailsFromDisk() async {
    final dir =
        await AppScope.projectsOf(context).directoryFor(widget.projectId);
    if (dir == null || !mounted) return;
    final disk = await GraphNodeThumbnailFiles.readAll(dir);
    if (!mounted) return;
    setState(() {
      _nodeThumbnails
        ..clear()
        ..addAll(disk);
    });
  }

  Future<void> _refreshNodeThumbnails(
    MainStory main, {
    Iterable<String>? onlyIds,
  }) async {
    if (!mounted) return;
    final graph = _graphNodes(main);
    final targets = onlyIds?.toSet() ?? graph.map((n) => n.id).toSet();
    final dir =
        await AppScope.projectsOf(context).directoryFor(widget.projectId);
    if (!mounted) return;

    for (final data in graph) {
      if (!targets.contains(data.id)) continue;
      if (!mounted) return;
      final png = await GraphNodeThumbnail.capture(context, data: data);
      if (png == null || !mounted) continue;
      if (dir != null) {
        await GraphNodeThumbnailFiles.write(dir, data.id, png);
      }
      _nodeThumbnails[data.id] = png;
    }

    final alive = graph.map((n) => n.id).toSet();
    final removed = _nodeThumbnails.keys
        .where((id) => !alive.contains(id))
        .toList(growable: false);
    for (final id in removed) {
      _nodeThumbnails.remove(id);
      if (dir != null) {
        await GraphNodeThumbnailFiles.delete(dir, id);
      }
    }
    if (mounted) setState(() {});
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

  Future<void> _copyNode(String nodeId) async {
    final project = _project;
    if (project == null) return;
    final before = project.main.nodes.map((n) => n.id).toSet();
    final next = _ops.duplicateNode(project.main, nodeId);
    await _persist(next);
    if (!mounted) return;
    final created = next.nodes.map((n) => n.id).toSet().difference(before);
    setState(() {
      _selectedId = created.isEmpty ? _selectedId : created.first;
      _selectedEdgeId = null;
    });
  }

  Future<bool> _confirmDeleteNode(String title) async {
    final confirmed = await showAppSheet<bool>(
      context: context,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pagePadding,
            AppTheme.spaceXs,
            AppTheme.pagePadding,
            AppTheme.spaceMd,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppSectionHeader('删除这一站？'),
              AppText(
                title.trim().isEmpty
                    ? '连到它的线也会一起去掉'
                    : '「$title」和连到它的线都会去掉',
                role: AppTextRole.body,
              ),
              const SizedBox(height: AppTheme.spaceMd),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: '取消',
                      variant: AppButtonVariant.secondary,
                      onPressed: () => Navigator.pop(sheetContext, false),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceSm),
                  Expanded(
                    child: AppButton(
                      label: '删除',
                      onPressed: () => Navigator.pop(sheetContext, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    return confirmed == true;
  }

  Future<void> _deleteNode(String nodeId) async {
    final project = _project;
    if (project == null) return;
    if (project.main.nodes.length <= 1) return;
    final title = project.main.nodeById(nodeId)?.title ?? '';
    final ok = await _confirmDeleteNode(title);
    if (!ok || !mounted) return;
    await _persist(_ops.removeNode(project.main, nodeId));
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
                            final ok = await _confirmDeleteNode(node.title);
                            if (!ok || !mounted) return;
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
    final focusId = _selectedId ??
        (_cardMode ? main.startNodeId : null);
    return GraphViewport(
      camera: _viewportCamera,
      nodes: _graphNodes(main),
      edges: _graphEdges(main),
      selectedId: focusId,
      selectedEdgeId: _cardMode ? null : _selectedEdgeId,
      focusSelected: _cardMode,
      onSelect: (id) => setState(() {
        _selectedId = id ?? (_cardMode ? focusId : null);
        if (id != null) _selectedEdgeId = null;
      }),
      onSelectEdge: _cardMode
          ? null
          : (id) => setState(() {
                _selectedEdgeId = id;
                if (id != null) _selectedId = null;
              }),
      onMove: _moveNodeLocal,
      onNodeDragEnd: _onNodeDragEnd,
      onConnect: _connect,
      onOpenOutput: (_, portId) => _openEdgeEditor(portId),
      onAddOutput: (_) => _tipAddOutput(),
      onOpenNode: _openNodeEditor,
      onCopyNode: _copyNode,
      onDeleteNode: main.nodes.length <= 1 ? null : _deleteNode,
      onAddNode: _addNode,
      onArrange: _autoLayout,
      showGrid: _showGrid,
    );
  }

  void _setViewMode(int index, Project project) {
    final card = index == 1;
    if (card && _overviewOpen) {
      _requestCloseOverview();
    }
    setState(() {
      _cardMode = card;
      if (card) {
        _selectedId ??= project.main.startNodeId;
        _selectedEdgeId = null;
        _overviewOpen = false;
      }
    });
  }

  void _toggleOverview() {
    if (_cardMode) return;
    if (_overviewOpen) {
      _requestCloseOverview();
      return;
    }
    setState(() => _overviewOpen = true);
  }

  void _requestCloseOverview() {
    if (!_overviewOpen) return;
    final panel = _overviewPanelKey.currentState;
    if (panel != null) {
      // ignore: unawaited_futures
      panel.dismiss();
      return;
    }
    setState(() => _overviewOpen = false);
  }

  void _onOverviewDismissed() {
    if (!_overviewOpen) return;
    setState(() => _overviewOpen = false);
  }

  Widget? _buildOverviewPanel(MainStory main) {
    if (!_overviewOpen || _cardMode) return null;
    return AppDockedPanel(
      key: _overviewPanelKey,
      onDismiss: _onOverviewDismissed,
      header: const Padding(
        padding: EdgeInsets.fromLTRB(
          AppTheme.pagePadding,
          0,
          AppTheme.pagePadding,
          0,
        ),
        child: AppSectionHeader(
          '走向全览',
          subtitle: '滑动地图移动镜头，点外侧或拖标题收起',
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.pagePadding,
          0,
          AppTheme.pagePadding,
          AppTheme.pagePadding,
        ),
        child: GraphOverviewMap(
          camera: _viewportCamera,
          nodes: _graphNodes(main),
          edges: _graphEdges(main),
          thumbnails: _nodeThumbnails,
        ),
      ),
    );
  }

  Widget _buildEditor(Project project) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): _undo,
        const SingleActivator(
          LogicalKeyboardKey.keyZ,
          meta: true,
          shift: true,
        ): _redo,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _undo,
        const SingleActivator(
          LogicalKeyboardKey.keyZ,
          control: true,
          shift: true,
        ): _redo,
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): _redo,
      },
      child: Focus(
        autofocus: true,
        child: AppNavShell(
          destinations: mainGraphViewNavItems,
          selectedIndex: _cardMode ? 1 : 0,
          onDestinationSelected: (index) => _setViewMode(index, project),
          forceCompact: true,
          railTopInset: 0,
          bottomNavExtra: AppBottomNavExtraCapsule(
            icon: Icons.map_outlined,
            selectedIcon: Icons.map,
            label: '全图',
            enabled: !_cardMode,
            selected: _overviewOpen,
            onPressed: _toggleOverview,
          ),
          bottomPanel: _buildOverviewPanel(project.main),
          onBottomPanelBarrierTap:
              _overviewOpen ? _requestCloseOverview : null,
          body: Builder(
            builder: (context) {
              final bottom = MediaQuery.paddingOf(context).bottom;
              return Padding(
                padding: EdgeInsets.only(bottom: bottom),
                child: _buildCanvas(project.main),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final project = _project;
    final editorReady = !_loading && _error == null && project != null;
    return AppPage(
      title: '情节走向',
      onBack: () => Navigator.of(context).maybePop(),
      actions: [
        AppCircleButton(
          icon: Icons.undo,
          tooltip: '撤销',
          onPressed: editorReady && _history.canUndo ? _undo : null,
        ),
        AppCircleButton(
          icon: Icons.redo,
          tooltip: '重做',
          onPressed: editorReady && _history.canRedo ? _redo : null,
        ),
        AppCircleButton(
          icon: Icons.more_horiz,
          tooltip: '更多',
          onPressed: editorReady ? _openMoreMenu : null,
        ),
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
                  : _buildEditor(project),
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
