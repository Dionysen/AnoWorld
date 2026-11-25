import 'dart:convert';
import 'dart:io';

import 'package:anoworld/domain/settings/built_in_ai_presets.dart';
import 'package:anoworld/domain/settings/built_in_plot_elements.dart';
import 'package:anoworld/domain/settings/seed_catalog.dart';
import 'package:anoworld/foundation/ai/st_prompt_manager.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

void main() {
  setUp(() {
    SeedCatalog.resetForTest();
  });

  test('loads plot elements, presets and prompt default from assets', () {
    ensureTestSeedsLoaded();

    expect(BuiltInPlotElementCategories.all, isNotEmpty);
    expect(BuiltInPlotElements.all, isNotEmpty);
    expect(BuiltInPlotElements.containsId('pe_stray_cat'), isTrue);
    expect(BuiltInPlotElements.byId['pe_stray_cat']?.keyword, '救助流浪猫');

    expect(BuiltInAIPresets.all, isNotEmpty);
    expect(BuiltInAIPresets.defaultPreset.id, 'default');
    expect(BuiltInAIPresets.defaultPreset.isBuiltIn, isTrue);

    final prompt = PromptManagerConfig.defaultConfig();
    expect(prompt.sections, isNotEmpty);
    expect(prompt.categories.length, 6);
    expect(
      prompt.sortedCategories.map((c) => c.name).toList(),
      ['常规规范', '炼金与选修', '内在罗盘', '关系引力', '研究母题', '文风'],
    );
    expect(
      prompt.sections.any((s) => s.type == PromptSectionType.systemPrompt),
      isTrue,
    );
    expect(
      prompt.sections.any((s) => s.identifier == 'aw_anti_collapse' && s.enabled),
      isTrue,
    );
    expect(
      prompt.sections.any((s) => s.identifier == 'aw_writing_craft' && s.enabled),
      isTrue,
    );
    expect(
      prompt.sections.any((s) => s.identifier == 'aw_word_alchemy' && s.enabled),
      isTrue,
    );
    expect(
      prompt.sections.any(
        (s) => s.identifier == 'aw_style_slice_of_life' && !s.enabled,
      ),
      isTrue,
    );
    expect(
      prompt.sections.where((s) => s.type == PromptSectionType.custom).length,
      greaterThanOrEqualTo(20),
    );
    expect(BuiltInAIPresets.defaultPreset.generationSettings.topP, 0.88);
    expect(
      BuiltInAIPresets.defaultPreset.generationSettings.frequencyPenalty,
      0.3,
    );
  });

  test('asset JSON round-trips through applyParsed', () {
    final plot = jsonDecode(
      File(SeedCatalog.plotElementsAsset).readAsStringSync(),
    );
    final presets = jsonDecode(
      File(SeedCatalog.aiPresetsAsset).readAsStringSync(),
    );
    final prompt = jsonDecode(
      File(SeedCatalog.promptDefaultAsset).readAsStringSync(),
    );
    SeedCatalog.applyParsed(
      plotJson: plot,
      presetsJson: presets,
      promptJson: prompt,
    );
    expect(SeedCatalog.elements.length, (plot as Map)['elements'].length);
    expect(SeedCatalog.presets.length, (presets as Map)['presets'].length);
  });
}
