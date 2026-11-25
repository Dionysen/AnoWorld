import 'package:anoworld/domain/main/apply_plot_patch.dart';
import 'package:anoworld/domain/models/plot_element.dart';
import 'package:anoworld/domain/settings/plot_element_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

PlotElementCatalog _catalog() => PlotElementCatalog(
      custom: <PlotElement>[
        PlotElement(id: 'pe_rain', keyword: '暴雨封路', description: '出城的桥被冲断'),
        PlotElement(id: 'pe_letter', keyword: '旧信', description: '迟到十年的信'),
      ],
    );

PlotPatchState _state({
  PlotElementCatalog? catalog,
  List<String> selected = const <String>[],
  List<String> packs = const <String>[],
}) {
  return PlotPatchState(
    catalog: catalog ?? _catalog(),
    selection: PlotElementSelection(
      selectedIds: selected,
      appliedPackIds: packs,
    ),
  );
}

void main() {
  setUpAll(ensureTestSeedsLoaded);

  const applier = ApplyPlotPatch();

  test('select adds ids without touching the library', () {
    final base = _state();
    final next = applier.apply(base, [
      {
        'op': 'select',
        'ids': ['pe_rain', 'pe_letter'],
      },
    ]);

    expect(next.selection.selectedIds, <String>['pe_rain', 'pe_letter']);
    expect(identical(next.catalog, base.catalog), isTrue);
    expect(next.selection.appliedPackIds, isEmpty);
  });

  test('select keeps pack ids and ignores duplicates', () {
    final next = applier.apply(
      _state(selected: ['pe_letter'], packs: ['pack_a']),
      [
        {
          'op': 'select',
          'ids': ['pe_letter', 'pe_letter', 'pe_rain'],
        },
      ],
    );

    expect(next.selection.selectedIds, <String>['pe_letter', 'pe_rain']);
    expect(next.selection.appliedPackIds, <String>['pack_a']);
  });

  test('deselect removes ids and leaves the rest', () {
    final next = applier.apply(
      _state(selected: ['pe_rain', 'pe_letter']),
      [
        {
          'op': 'deselect',
          'ids': ['pe_rain'],
        },
      ],
    );

    expect(next.selection.selectedIds, <String>['pe_letter']);
  });

  test('deselecting something not selected is a no-op', () {
    final base = _state(selected: ['pe_letter']);
    final next = applier.apply(base, [
      {
        'op': 'deselect',
        'ids': ['pe_rain'],
      },
    ]);

    expect(next.selection.selectedIds, <String>['pe_letter']);
  });

  test('an id missing from the library fails the whole proposal', () {
    expect(
      () => applier.apply(_state(), [
        {
          'op': 'select',
          'ids': ['pe_rain', 'pe_missing'],
        },
      ]),
      throwsA(
        isA<ApplyPlotPatchException>().having(
          (e) => e.message,
          'message',
          contains('pe_missing'),
        ),
      ),
    );
  });

  test('select needs at least one id', () {
    expect(
      () => applier.apply(_state(), [
        {'op': 'select'},
      ]),
      throwsA(isA<ApplyPlotPatchException>()),
    );
  });

  test('an unknown op is rejected', () {
    expect(
      () => applier.apply(_state(), [
        {'op': 'rename'},
      ]),
      throwsA(isA<ApplyPlotPatchException>()),
    );
  });

  test('add_element writes a library row and selects it', () {
    final base = _state();
    final next = applier.apply(base, [
      {
        'op': 'add_element',
        'keyword': '断电',
        'description': '整条街忽然停电，有人在黑暗里靠近',
      },
    ]);

    final added = next.selection.selectedIds.single;
    expect(added, startsWith('pe_'));
    expect(next.catalog.byId(added)?.keyword, '断电');
    expect(next.catalog.custom, hasLength(3));
    // The base state is untouched.
    expect(base.catalog.custom, hasLength(2));
  });

  test('add_element resolves a category by its display name', () {
    final catalog = _catalog();
    final next = applier.apply(
      _state(catalog: catalog),
      [
        {
          'op': 'add_element',
          'keyword': '断电',
          'description': '有人趁黑靠近',
          'category': '悬疑',
        },
      ],
    );

    final added = next.catalog.byId(next.selection.selectedIds.single)!;
    expect(next.catalog.categoryNameOf(added.categoryId), '悬疑');

    final unknownName = applier.apply(
      _state(catalog: catalog),
      [
        {
          'op': 'add_element',
          'keyword': '断电',
          'description': '有人趁黑靠近',
          'category': '不存在的分类',
        },
      ],
    );
    final uncategorized =
        unknownName.catalog.byId(unknownName.selection.selectedIds.single)!;
    expect(uncategorized.categoryId, '');
  });

  test('repeating the same add_element reuses the row', () {
    final first = applier.apply(_state(), [
      {
        'op': 'add_element',
        'keyword': '断电',
        'description': '有人趁黑靠近',
      },
    ]);
    final second = applier.apply(first, [
      {
        'op': 'add_element',
        'keyword': '断电',
        'description': '有人趁黑靠近',
      },
    ]);

    expect(second.catalog.custom, hasLength(3));
    expect(second.selection.selectedIds, first.selection.selectedIds);
  });

  test('add_element needs a keyword', () {
    expect(
      () => applier.apply(_state(), [
        {'op': 'add_element', 'description': '没有关键词'},
      ]),
      throwsA(isA<ApplyPlotPatchException>()),
    );
  });

  test('an empty op list is rejected', () {
    expect(
      () => applier.apply(_state(), const <Map<String, dynamic>>[]),
      throwsA(isA<ApplyPlotPatchException>()),
    );
  });
}
