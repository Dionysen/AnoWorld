import 'package:anoworld/domain/models/plot_element.dart';
import 'package:anoworld/domain/models/plot_element_category.dart';
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

  test(
    'delete built-in hides it; restoreAll brings it back and keeps custom',
    () {
      final seedId = BuiltInPlotElements.all.first.id;
      final custom = const PlotElement(
        id: 'pe_custom_1',
        keyword: '自建',
        description: '用户条目',
      );
      var catalog = PlotElementCatalog().upsertCustom(custom).delete(seedId);
      expect(catalog.byId(seedId), isNull);
      expect(catalog.byId(custom.id)?.keyword, '自建');

      catalog = catalog.restoreAllBuiltIns();
      expect(catalog.byId(seedId)?.id, seedId);
      expect(catalog.byId(custom.id)?.keyword, '自建');
      expect(catalog.overrides, isEmpty);
      expect(catalog.deletedBuiltInIds, isEmpty);
    },
  );

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
          const PlotElement(id: 'pe_x', keyword: '自定义', description: '内容'),
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

  test('every built-in seed belongs to a built-in category', () {
    for (final seed in BuiltInPlotElements.all) {
      expect(
        BuiltInPlotElementCategories.containsId(seed.categoryId),
        isTrue,
        reason: seed.id,
      );
      expect(
        BuiltInPlotElementCategories.byId[seed.categoryId]!.name.isNotEmpty,
        isTrue,
      );
    }
    expect(
      PlotElementCatalog().categories,
      hasLength(BuiltInPlotElementCategories.all.length),
    );
  });

  test('elementsOfCategory groups visible rows', () {
    final catalog = PlotElementCatalog();
    final daily = catalog.elementsOfCategory(
      BuiltInPlotElementCategories.daily.id,
    );
    expect(daily, isNotEmpty);
    expect(
      daily.every((e) => e.categoryId == BuiltInPlotElementCategories.daily.id),
      isTrue,
    );
    expect(catalog.uncategorizedElements, isEmpty);
  });

  test('assignCategory moves built-in without losing keyword/description', () {
    final seed = BuiltInPlotElements.all.first;
    final catalog = PlotElementCatalog().assignCategory(
      seed.id,
      BuiltInPlotElementCategories.mystery.id,
    );
    final row = catalog.byId(seed.id)!;
    expect(row.categoryId, BuiltInPlotElementCategories.mystery.id);
    expect(row.keyword, seed.keyword);
    expect(row.description, seed.description);
    expect(catalog.isModifiedBuiltIn(seed.id), isTrue);

    final restored = catalog.assignCategory(seed.id, seed.categoryId);
    expect(restored.isModifiedBuiltIn(seed.id), isFalse);
    expect(restored.byId(seed.id)?.categoryId, seed.categoryId);
  });

  test('assignCategory keeps custom rows and ignores unknown categories', () {
    const custom = PlotElement(
      id: 'pe_custom_cat',
      keyword: '自建',
      description: '用户条目',
    );
    var catalog = PlotElementCatalog().upsertCustom(custom);
    expect(catalog.uncategorizedElements.single.id, custom.id);

    catalog = catalog.assignCategory(custom.id, 'missing_category');
    expect(catalog.byId(custom.id)?.categoryId, '');
  });

  test('custom categories can be added and renamed', () {
    var catalog = PlotElementCatalog().addCategory(
      const PlotElementCategory(id: 'pe_cat_x', name: '都市'),
    );
    expect(catalog.categoryById('pe_cat_x')?.name, '都市');
    expect(catalog.categories.last.id, 'pe_cat_x');

    catalog = catalog.renameCategory('pe_cat_x', '都市奇谈');
    expect(catalog.categoryById('pe_cat_x')?.name, '都市奇谈');
    expect(catalog.customCategories.single.name, '都市奇谈');
  });

  test('built-in category renames stay on the seed and reset restores', () {
    final seed = BuiltInPlotElementCategories.daily;
    var catalog = PlotElementCatalog().renameCategory(seed.id, '生活');
    expect(catalog.categoryById(seed.id)?.name, '生活');
    expect(catalog.customCategories, isEmpty);

    catalog = catalog.restoreAllBuiltIns();
    expect(catalog.categoryById(seed.id)?.name, seed.name);
  });

  test('json round-trip keeps custom categories and renames', () {
    final original = PlotElementCatalog()
        .renameCategory(BuiltInPlotElementCategories.crisis.id, '险情')
        .addCategory(const PlotElementCategory(id: 'pe_cat_y', name: '校园'));
    final restored = PlotElementCatalog.fromJson(original.toJson());
    expect(
      restored.categoryRenames[BuiltInPlotElementCategories.crisis.id],
      '险情',
    );
    expect(restored.customCategories.single.name, '校园');
  });

  test('category fields survive element json round-trip', () {
    const element = PlotElement(
      id: 'pe_cat_round',
      keyword: '值日',
      description: '放学后留下打扫',
      categoryId: 'pe_cat_daily',
    );
    final back = PlotElement.fromJson(element.toJson());
    expect(back.categoryId, 'pe_cat_daily');
    expect(
      PlotElement.fromJson(const <String, dynamic>{
        'id': 'pe_legacy',
        'keyword': '旧条',
        'description': '旧描述',
      }).categoryId,
      isEmpty,
    );
  });
}
