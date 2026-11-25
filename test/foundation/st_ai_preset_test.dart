import 'dart:convert';
import 'dart:io';

import 'package:anoworld/foundation/ai/st_ai_preset.dart';
import 'package:anoworld/foundation/ai/st_prompt_manager.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

void main() {
  setUpAll(ensureTestSeedsLoaded);

  group('SillyTavern preset import', () {
    test('imports default OpenAI preset fixture', () {
      final raw = File('test/fixtures/st_preset_default.json').readAsStringSync();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      expect(AIPreset.isSillyTavernFormat(json), isTrue);

      final preset = AIPreset.fromSillyTavernJson(json, 'imported');
      expect(preset.name, isNotEmpty);
      expect(preset.generationSettings.temperature, greaterThan(0));
      expect(preset.promptManagerConfig, isNotNull);
      expect(preset.promptManagerConfig!.sections, isNotEmpty);
    });

    test('export round-trips generation and prompts', () {
      final raw = File('test/fixtures/st_preset_default.json').readAsStringSync();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final preset = AIPreset.fromSillyTavernJson(json, 'rt');

      final exported = preset.toExportJson();
      expect(exported['temperature'], preset.generationSettings.temperature);
      expect(exported['prompts'], isA<List<dynamic>>());
      expect(exported['prompt_order'], isA<List<dynamic>>());

      final again = AIPreset.fromSillyTavernJson(exported, 'rt2');
      expect(
        again.generationSettings.temperature,
        preset.generationSettings.temperature,
      );
      expect(
        again.promptManagerConfig?.sections.length,
        preset.promptManagerConfig?.sections.length,
      );
    });

    test('PromptManagerConfig preserves jailbreak identifier', () {
      final raw = File('test/fixtures/st_preset_default.json').readAsStringSync();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final config = PromptManagerConfig.fromSillyTavernJson(json);
      final jailbreak = config.sections.where(
        (s) => s.identifier == 'jailbreak' || s.type == PromptSectionType.postHistoryInstructions,
      );
      expect(jailbreak, isNotEmpty);
    });

    test('ST import stays flat with empty categories', () {
      final raw = File('test/fixtures/st_preset_default.json').readAsStringSync();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final preset = AIPreset.fromSillyTavernJson(json, 'flat');
      final config = preset.promptManagerConfig!;
      expect(config.categories, isEmpty);
      expect(config.sections.every((s) => s.categoryId == null), isTrue);
    });

    test('_anoworld categories survive export then re-import', () {
      final seeded = PromptManagerConfig.defaultConfig();
      expect(seeded.categories, isNotEmpty);

      final preset = AIPreset(
        id: 'aw_roundtrip',
        name: 'Roundtrip',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
        generationSettings: const GenerationPreset(),
        promptManagerConfig: seeded,
      );
      final exported = preset.toExportJson();
      expect(exported['_anoworld'], isA<Map<String, dynamic>>());
      final anoworld = exported['_anoworld'] as Map<String, dynamic>;
      expect(anoworld['promptCategories'], isA<List<dynamic>>());
      expect(anoworld['promptCategoryById'], isA<Map>());

      final again = AIPreset.fromSillyTavernJson(exported, 'aw_roundtrip_2');
      final restored = again.promptManagerConfig!;
      expect(
        restored.sortedCategories.map((c) => c.id).toList(),
        seeded.sortedCategories.map((c) => c.id).toList(),
      );
      expect(
        restored.sections
            .where((s) => s.identifier == 'aw_style_slice_of_life')
            .single
            .categoryId,
        'aw_cat_style',
      );
    });

    test('export without _anoworld imports as uncategorized', () {
      final seeded = PromptManagerConfig.defaultConfig();
      final preset = AIPreset(
        id: 'no_meta',
        name: 'No Meta',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
        generationSettings: const GenerationPreset(),
        promptManagerConfig: seeded,
      );
      final exported = preset.toExportJson();
      exported.remove('_anoworld');

      final again = AIPreset.fromSillyTavernJson(exported, 'no_meta_2');
      final config = again.promptManagerConfig!;
      expect(config.categories, isEmpty);
      expect(config.sections.every((s) => s.categoryId == null), isTrue);
    });
  });
}