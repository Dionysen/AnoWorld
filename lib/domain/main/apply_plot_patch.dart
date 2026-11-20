import 'package:anoworld/domain/models/plot_element.dart';
import 'package:anoworld/domain/project/entity_id.dart';
import 'package:anoworld/domain/settings/plot_element_catalog.dart';

/// Plot-element state a proposal is applied to: the global library plus the
/// story's own selection. Both travel together because adding an element
/// touches the library and the selection at once.
class PlotPatchState {
  const PlotPatchState({required this.catalog, required this.selection});

  final PlotElementCatalog catalog;
  final PlotElementSelection selection;
}

class ApplyPlotPatchException implements Exception {
  const ApplyPlotPatchException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Ops that only pick from (or add to) the plot-element library.
///
/// `select` / `deselect` take `ids`; `add_element` takes `keyword` plus an
/// optional `description` and `category` name, writes a custom library row and
/// selects it. Library rows themselves are never rewritten here — editing a
/// row stays a library-UI job.
class ApplyPlotPatch {
  const ApplyPlotPatch();

  PlotPatchState apply(
    PlotPatchState base,
    List<Map<String, dynamic>> ops,
  ) {
    if (ops.isEmpty) {
      throw const ApplyPlotPatchException('缺少 ops');
    }
    var state = base;
    for (final op in ops) {
      final name = (op['op']?.toString() ?? '').trim();
      switch (name) {
        case 'select':
          state = _select(state, op, selected: true);
        case 'deselect':
          state = _select(state, op, selected: false);
        case 'add_element':
          state = _addElement(state, op);
        case '':
          throw const ApplyPlotPatchException('缺少操作类型');
        default:
          throw ApplyPlotPatchException('不认识的操作：$name');
      }
    }
    return state;
  }

  PlotPatchState _select(
    PlotPatchState state,
    Map<String, dynamic> op, {
    required bool selected,
  }) {
    final ids = _idsOf(op);
    if (ids.isEmpty) {
      throw ApplyPlotPatchException(
        selected ? 'select 缺少 ids' : 'deselect 缺少 ids',
      );
    }
    final unknown = [
      for (final id in ids)
        if (state.catalog.byId(id) == null) id,
    ];
    if (unknown.isNotEmpty) {
      throw ApplyPlotPatchException(
        '剧情元素库里没有：${unknown.join('、')}',
      );
    }
    return PlotPatchState(
      catalog: state.catalog,
      selection: state.selection.withIds(ids, selected: selected),
    );
  }

  PlotPatchState _addElement(
    PlotPatchState state,
    Map<String, dynamic> op,
  ) {
    final keyword = (op['keyword']?.toString() ?? '').trim();
    if (keyword.isEmpty) {
      throw const ApplyPlotPatchException('add_element 缺少 keyword');
    }
    final description = (op['description']?.toString() ?? '').trim();
    // Reusing an identical row keeps a retried op from duplicating the library.
    for (final row in state.catalog.effectiveList) {
      if (row.keyword == keyword && row.description == description) {
        return PlotPatchState(
          catalog: state.catalog,
          selection: state.selection.withIds(<String>[row.id], selected: true),
        );
      }
    }
    final category = (op['category']?.toString() ?? '').trim();
    final element = PlotElement(
      id: newEntityId('pe'),
      keyword: keyword,
      description: description,
      categoryId: _categoryIdOf(state.catalog, category),
    );
    return PlotPatchState(
      catalog: state.catalog.upsertCustom(element),
      selection: state.selection.withIds(<String>[element.id], selected: true),
    );
  }

  /// Category by display name; unknown or blank names land in 未分类.
  static String _categoryIdOf(PlotElementCatalog catalog, String name) {
    if (name.isEmpty) return '';
    for (final category in catalog.categories) {
      if (category.name.trim() == name) return category.id;
    }
    return '';
  }

  static List<String> _idsOf(Map<String, dynamic> op) {
    final raw = op['ids'] ?? op['id'];
    final out = <String>[];
    if (raw is String) {
      _addId(out, raw);
    } else if (raw is List) {
      for (final item in raw) {
        if (item is String) _addId(out, item);
      }
    }
    return out;
  }

  static void _addId(List<String> out, String raw) {
    final id = raw.trim();
    if (id.isEmpty || out.contains(id)) return;
    out.add(id);
  }
}
