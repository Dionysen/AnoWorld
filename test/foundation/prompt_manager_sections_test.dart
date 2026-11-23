import 'package:anoworld/foundation/ai/st_prompt_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('addCustomSection appends an editable custom entry', () {
    final config = PromptManagerConfig.defaultConfig().addCustomSection(
      name: '第二人称',
      identifier: 'custom_1',
      content: '写得更口语',
    );

    final added = config.sortedSections.last;
    expect(added.type, PromptSectionType.custom);
    expect(added.identifier, 'custom_1');
    expect(added.name, '第二人称');
    expect(added.content, '写得更口语');
    expect(added.isEditable, isTrue);
    expect(
      config.sortedSections.map((s) => s.order).toList(),
      List.generate(config.sortedSections.length, (i) => i),
    );
  });

  test('removeSectionAt drops a custom entry and reindexes the rest', () {
    final base = PromptManagerConfig.defaultConfig()
        .addCustomSection(name: '甲', identifier: 'custom_a')
        .addCustomSection(name: '乙', identifier: 'custom_b');

    final index = base.sortedSections.indexWhere(
      (s) => s.identifier == 'custom_a',
    );
    final removed = base.removeSectionAt(index);

    expect(
      removed.sortedSections.any((s) => s.identifier == 'custom_a'),
      isFalse,
    );
    expect(
      removed.sortedSections.any((s) => s.identifier == 'custom_b'),
      isTrue,
    );
    expect(
      removed.sortedSections.map((s) => s.order).toList(),
      List.generate(removed.sortedSections.length, (i) => i),
    );
  });

  test('removeSectionAt refuses built-in sections', () {
    final base = PromptManagerConfig.defaultConfig();
    final before = base.sortedSections.length;

    final after = base.removeSectionAt(0);

    expect(after.sortedSections.length, before);
    expect(after.sortedSections.first.type, PromptSectionType.systemPrompt);
  });

  test('removeCustomSections drops every selected custom entry', () {
    final base = PromptManagerConfig.defaultConfig()
        .addCustomSection(name: '甲', identifier: 'custom_a')
        .addCustomSection(name: '乙', identifier: 'custom_b')
        .addCustomSection(name: '丙', identifier: 'custom_c');

    final removed = base.removeCustomSections(['custom_a', 'custom_c']);

    expect(
      removed.sortedSections.map((s) => s.identifier).whereType<String>(),
      ['custom_b'],
    );
    expect(
      removed.sortedSections.map((s) => s.order).toList(),
      List.generate(removed.sortedSections.length, (i) => i),
    );
  });

  test('removeCustomSections never touches built-in sections', () {
    final base = PromptManagerConfig.defaultConfig().addCustomSection(
      name: '甲',
      identifier: 'custom_a',
    );
    final before = base.sortedSections.length;

    final after = base.removeCustomSections([
      'custom_a',
      'main',
      'chatHistory',
    ]);

    expect(after.sortedSections.length, before - 1);
    expect(
      after.sortedSections.any((s) => s.type == PromptSectionType.systemPrompt),
      isTrue,
    );
    expect(
      after.sortedSections.any((s) => s.type == PromptSectionType.chatHistory),
      isTrue,
    );
  });
}
