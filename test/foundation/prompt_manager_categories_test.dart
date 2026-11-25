import 'package:anoworld/foundation/ai/st_prompt_manager.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

void main() {
  setUpAll(ensureTestSeedsLoaded);

  group('PromptCategory CRUD', () {
    test('seed default mounts eight craft families', () {
      final config = PromptManagerConfig.defaultConfig();
      expect(
        config.sortedCategories.map((c) => c.id).toList(),
        [
          'aw_cat_rules',
          'aw_cat_alchemy',
          'aw_cat_inner',
          'aw_cat_relation',
          'aw_cat_motif',
          'aw_cat_nsfw',
          'aw_cat_lens',
          'aw_cat_style',
        ],
      );
      expect(
        config.sortedCategories.map((c) => c.name).toList(),
        [
          '常规规范',
          '炼金与选修',
          '内在罗盘',
          '关系引力',
          '研究母题',
          'NSFW',
          '人称与代行',
          '文风',
        ],
      );

      expect(
        config
            .sectionsInCategory('aw_cat_style')
            .map((s) => s.identifier)
            .toList(),
        containsAll([
          'aw_style_slice_of_life',
          'aw_style_fantasy',
          'aw_style_mystery',
        ]),
      );
      expect(
        config.sectionsInCategory('aw_cat_alchemy').any(
          (s) => s.identifier == 'aw_paragraph_density',
        ),
        isTrue,
      );
      expect(
        config.sectionsInCategory('aw_cat_rules').any(
          (s) => s.identifier == 'aw_anti_collapse',
        ),
        isTrue,
      );
      expect(
        config.sectionsInCategory(null).any(
          (s) => s.type == PromptSectionType.systemPrompt,
        ),
        isTrue,
      );
      expect(
        config.sectionsInCategory(null).any(
          (s) => (s.identifier ?? '').startsWith('aw_style_'),
        ),
        isFalse,
      );
    });

    test('upsertCategory creates and renameCategory updates name', () {
      var config = PromptManagerConfig.defaultConfig().upsertCategory(
        id: 'cat_x',
        name: '临时族',
      );
      expect(config.categoryById('cat_x')?.name, '临时族');

      config = config.renameCategory('cat_x', '改名族');
      expect(config.categoryById('cat_x')?.name, '改名族');
      expect(config.categories.where((c) => c.id == 'cat_x').length, 1);
    });

    test('deleteCategory clears member categoryId', () {
      final base = PromptManagerConfig.defaultConfig();
      final styleMembers = base.sectionsInCategory('aw_cat_style');
      expect(styleMembers, isNotEmpty);

      final deleted = base.deleteCategory('aw_cat_style');
      expect(deleted.categoryById('aw_cat_style'), isNull);
      expect(deleted.sectionsInCategory('aw_cat_style'), isEmpty);
      for (final member in styleMembers) {
        final again = deleted.sections.firstWhere(
          (s) => s.identifier == member.identifier,
        );
        expect(again.categoryId, isNull);
      }
      expect(
        deleted.sectionsInCategory(null).length,
        greaterThan(base.sectionsInCategory(null).length),
      );
    });

    test('setSectionCategory assigns and clears', () {
      final base = PromptManagerConfig.defaultConfig();
      final index = base.sortedSections.indexWhere(
        (s) => s.type == PromptSectionType.persona,
      );
      expect(index, greaterThanOrEqualTo(0));
      expect(base.sortedSections[index].categoryId, isNull);

      final assigned = base.setSectionCategory(index, 'aw_cat_alchemy');
      expect(
        assigned.sortedSections[index].categoryId,
        'aw_cat_alchemy',
      );

      final cleared = assigned.setSectionCategory(index, null);
      expect(cleared.sortedSections[index].categoryId, isNull);
    });

    test('addCustomSection defaults to uncategorized', () {
      final config = PromptManagerConfig.defaultConfig().addCustomSection(
        name: '自定',
        identifier: 'custom_uncat',
      );
      final added = config.sortedSections.last;
      expect(added.identifier, 'custom_uncat');
      expect(added.categoryId, isNull);
      expect(added.isUserAdded, isTrue);
      expect(
        config.sectionsInCategory(null).any((s) => s.identifier == 'custom_uncat'),
        isTrue,
      );
    });

    test('seed crafts are custom; only ST slots are built-in types', () {
      final config = PromptManagerConfig.defaultConfig();
      final craft = config.sections
          .where((s) => s.identifier == 'aw_anti_collapse')
          .single;
      expect(craft.isCustom, isTrue);
      expect(craft.isUserAdded, isFalse);
      expect(
        config.sections
            .where((s) => s.type == PromptSectionType.systemPrompt)
            .single
            .isCustom,
        isFalse,
      );
    });

    test('toJson / fromJson round-trips categories and categoryId', () {
      final original = PromptManagerConfig.defaultConfig();
      final restored = PromptManagerConfig.fromJson(original.toJson());

      expect(
        restored.sortedCategories.map((c) => '${c.id}:${c.name}').toList(),
        original.sortedCategories.map((c) => '${c.id}:${c.name}').toList(),
      );
      expect(
        restored.sections
            .where((s) => s.categoryId != null)
            .map((s) => '${s.identifier}:${s.categoryId}')
            .toSet(),
        original.sections
            .where((s) => s.categoryId != null)
            .map((s) => '${s.identifier}:${s.categoryId}')
            .toSet(),
      );
    });

    test('withAnoWorldMeta restores categories onto a flat ST config', () {
      final seeded = PromptManagerConfig.defaultConfig();
      final flat = PromptManagerConfig(
        sections: [
          for (final s in seeded.sections) s.copyWith(clearCategoryId: true),
        ],
      );
      expect(flat.categories, isEmpty);
      expect(flat.sections.every((s) => s.categoryId == null), isTrue);

      final meta = <String, dynamic>{
        'promptCategories': seeded.categories.map((c) => c.toJson()).toList(),
        'promptCategoryById': {
          for (final s in seeded.sections)
            if (s.identifier != null &&
                s.categoryId != null &&
                s.categoryId!.isNotEmpty)
              s.identifier!: s.categoryId,
        },
      };
      final restored = flat.withAnoWorldMeta(meta);
      expect(restored.sortedCategories.length, seeded.sortedCategories.length);
      expect(
        restored.sections
            .where((s) => s.identifier == 'aw_style_slice_of_life')
            .single
            .categoryId,
        'aw_cat_style',
      );
    });

    test('reorderCategories swaps UI order only', () {
      final base = PromptManagerConfig.defaultConfig();
      final before = base.sortedCategories.map((c) => c.id).toList();
      expect(before.first, 'aw_cat_rules');

      final moved = base.reorderCategories(0, 2);
      expect(
        moved.sortedCategories.map((c) => c.id).toList(),
        [
          before[1],
          before[2],
          before[0],
          ...before.skip(3),
        ],
      );
      expect(
        moved.sortedCategories.map((c) => c.order).toList(),
        List.generate(moved.sortedCategories.length, (i) => i),
      );
    });

    test('reorderTopLevel can place a category before uncategorized items', () {
      final base = PromptManagerConfig.defaultConfig();
      final items = base.topLevelItems;
      expect(items.first.isCategory, isFalse);
      expect(
        items.any((e) => e.category?.id == 'aw_cat_style'),
        isTrue,
      );

      final styleIndex = items.indexWhere(
        (e) => e.category?.id == 'aw_cat_style',
      );
      expect(styleIndex, greaterThan(0));

      final moved = base.reorderTopLevel(styleIndex, 0);
      expect(moved.topLevelItems.first.category?.id, 'aw_cat_style');
      expect(moved.topLevelOrder.first, 'c:aw_cat_style');
      expect(
        moved.topLevelItems.any((e) => e.section != null),
        isTrue,
      );
    });

    test('moveSectionToCategory assigns and appends after last member', () {
      final base = PromptManagerConfig.defaultConfig();
      final index = base.sortedSections.indexWhere(
        (s) => s.type == PromptSectionType.persona,
      );
      expect(index, greaterThanOrEqualTo(0));
      expect(base.sortedSections[index].categoryId, isNull);

      final styleLast = base
          .sectionsInCategory('aw_cat_style')
          .last
          .identifier;
      final moved = base.moveSectionToCategory(index, 'aw_cat_style');
      final members = moved.sectionsInCategory('aw_cat_style');
      expect(members.last.type, PromptSectionType.persona);
      expect(
        members[members.length - 2].identifier,
        styleLast,
      );

      final clearedIndex = moved.sortedSections.indexWhere(
        (s) => s.type == PromptSectionType.persona,
      );
      final cleared = moved.moveSectionToCategory(clearedIndex, null);
      expect(
        cleared.sections
            .where((s) => s.type == PromptSectionType.persona)
            .single
            .categoryId,
        isNull,
      );
    });
  });
}
