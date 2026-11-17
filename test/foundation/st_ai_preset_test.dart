import 'dart:convert';
import 'dart:io';

import 'package:anoworld/foundation/ai/st_ai_preset.dart';
import 'package:anoworld/foundation/ai/st_prompt_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
  });
}