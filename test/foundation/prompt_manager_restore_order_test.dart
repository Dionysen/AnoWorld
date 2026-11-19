import 'package:anoworld/foundation/ai/st_prompt_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<PromptSectionType> builtInTypes(PromptManagerConfig config) {
    return config.sortedSections
        .where((s) => !s.isCustom)
        .map((s) => s.type)
        .toList();
  }

  final defaults = builtInTypes(PromptManagerConfig.defaultConfig());

  test('restoreDefaultOrder undoes a built-in shuffle', () {
    final shuffled = PromptManagerConfig.defaultConfig().reorder(0, 5);
    expect(builtInTypes(shuffled), isNot(defaults));

    final restored = shuffled.restoreDefaultOrder();
    expect(builtInTypes(restored), defaults);
    expect(
      restored.sortedSections.map((s) => s.order).toList(),
      List.generate(restored.sortedSections.length, (i) => i),
    );
  });

  test('restoreDefaultOrder keeps custom sections in their slots', () {
    final config = PromptManagerConfig.defaultConfig()
        .addCustomSection(name: '我的段', identifier: 'custom_1', content: 'x')
        .reorder(11, 1);

    expect(config.sortedSections[1].name, '我的段');

    final restored = config.restoreDefaultOrder();
    expect(restored.sortedSections[1].name, '我的段');
    expect(restored.sortedSections[1].content, 'x');
    expect(builtInTypes(restored), defaults);
  });

  test('restoreDefaultOrder keeps edited content and enabled flags', () {
    final base = PromptManagerConfig.defaultConfig();
    final sorted = base.sortedSections;
    final personaIndex = sorted.indexWhere(
      (s) => s.type == PromptSectionType.persona,
    );
    final edited = base
        .updateSectionByIndex(
          0,
          sorted.first.copyWith(content: '自定义系统提示'),
        )
        .toggleSectionByIndex(personaIndex)
        .reorder(0, 3);

    final restored = edited.restoreDefaultOrder();
    expect(builtInTypes(restored), defaults);

    final systemPrompt = restored.sortedSections.first;
    expect(systemPrompt.type, PromptSectionType.systemPrompt);
    expect(systemPrompt.content, '自定义系统提示');
    expect(
      restored.sortedSections
          .firstWhere((s) => s.type == PromptSectionType.persona)
          .enabled,
      isFalse,
    );
  });
}
