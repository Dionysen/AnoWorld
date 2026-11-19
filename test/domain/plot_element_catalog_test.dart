import 'package:anoworld/domain/models/plot_element.dart';
import 'package:anoworld/domain/settings/built_in_plot_elements.dart';
import 'package:anoworld/domain/settings/plot_element_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('effectiveList starts with all built-ins', () {
    final catalog = PlotElementCatalog();
    expect(catalog.effectiveList.length, BuiltInPlotElements.all.length);
    expect(catalog.effectiveList.first.id, BuiltInPlotElements.all.first.id);
  });

  test('updateBuiltIn stores override and restore clears it', () {
    final id = BuiltInPlotElements.all.first.id;
    var catalog = PlotElementCatalog().updateBuiltIn(
      id: id,
      keyword: '改过的词',
      description: '改过的描述',
    );
    expect(catalog.isModifiedBuiltIn(id), isTrue);
    expect(catalog.byId(id)?.keyword, '改过的词');

    catalog = catalog.restoreBuiltIn(id);
    expect(catalog.isModifiedBuiltIn(id), isFalse);
    expect(catalog.byId(id)?.keyword, BuiltInPlotElements.all.first.keyword);
  });

  test('delete built-in hides it; restoreAll brings it back and keeps custom', () {
    final seedId = BuiltInPlotElements.all.first.id;
    final custom = const PlotElement(
      id: 'pe_custom_1',
      keyword: '自建',
      description: '用户条目',
    );
    var catalog = PlotElementCatalog()
        .upsertCustom(custom)
        .delete(seedId);
    expect(catalog.byId(seedId), isNull);
    expect(catalog.byId(custom.id)?.keyword, '自建');

    catalog = catalog.restoreAllBuiltIns();
    expect(catalog.byId(seedId)?.id, seedId);
    expect(catalog.byId(custom.id)?.keyword, '自建');
    expect(catalog.overrides, isEmpty);
    expect(catalog.deletedBuiltInIds, isEmpty);
  });

  test('upsertCustom updates existing custom row', () {
    const first = PlotElement(
      id: 'pe_custom_2',
      keyword: '甲',
      description: '一',
    );
    final catalog = PlotElementCatalog()
        .upsertCustom(first)
        .upsertCustom(first.copyWith(keyword: '乙', description: '二'));
    expect(catalog.custom, hasLength(1));
    expect(catalog.byId(first.id)?.keyword, '乙');
  });

  test('json round-trip keeps overrides deleted and custom', () {
    final id = BuiltInPlotElements.all.first.id;
    final original = PlotElementCatalog()
        .updateBuiltIn(id: id, keyword: '覆写', description: '说明')
        .delete(BuiltInPlotElements.all[1].id)
        .upsertCustom(
          const PlotElement(
            id: 'pe_x',
            keyword: '自定义',
            description: '内容',
          ),
        );
    final restored = PlotElementCatalog.fromJson(original.toJson());
    expect(restored.overrides[id]?.keyword, '覆写');
    expect(restored.deletedBuiltInIds, contains(BuiltInPlotElements.all[1].id));
    expect(restored.custom.single.keyword, '自定义');
  });

  test('resolveSelected skips missing ids and builds prompt block', () {
    final catalog = PlotElementCatalog();
    final seed = BuiltInPlotElements.all.first;
    final resolved = catalog.resolveSelected([seed.id, 'pe_missing']);
    expect(resolved, hasLength(1));
    expect(resolved.single.id, seed.id);

    final block = catalog.promptBlockForSelected([seed.id]);
    expect(block, contains('可用剧情元素'));
    expect(block, contains(seed.keyword));
    expect(catalog.promptBlockForSelected(const []), isEmpty);
  });

  test('clipDescription caps at max chars', () {
    final long = '字' * (kPlotElementDescriptionMaxChars + 20);
    expect(
      PlotElementCatalog.clipDescription(long).length,
      kPlotElementDescriptionMaxChars,
    );
  });
}
