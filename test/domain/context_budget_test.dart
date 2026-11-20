import 'package:anoworld/domain/ai/context_budget.dart';
import 'package:anoworld/foundation/ai/st_ai_preset.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('budget is contextLength minus reserved output', () {
    final budget = ContextBudget.of(
      const GenerationPreset(contextLength: 8000, maxTokens: 2000),
    );

    expect(budget.inputTokens, 6000);
  });

  test('budget never drops below the floor', () {
    final budget = ContextBudget.of(
      const GenerationPreset(contextLength: 4096, maxTokens: 8192),
    );

    expect(budget.inputTokens, ContextBudget.minInputTokens);
  });

  test('the default 1M preset leaves room for anything', () {
    final budget = ContextBudget.of(const GenerationPreset());

    expect(budget.inputTokens, greaterThan(900000));
  });

  test('remaining never goes negative', () {
    const budget = ContextBudget(inputTokens: 100);

    expect(budget.remaining(40), 60);
    expect(budget.remaining(100), 0);
    expect(budget.remaining(180), 0);
  });

  test('keepNewest drops the oldest items that no longer fit', () {
    const budget = ContextBudget(inputTokens: 100);
    final items = <String>['aaaa', '中文', 'aaaa'];

    final kept = budget.keepNewest(items, (s) => s, tokens: 3);

    expect(kept, <String>['中文', 'aaaa']);
  });

  test('keepNewest keeps everything when the budget is ample', () {
    const budget = ContextBudget(inputTokens: 100);
    final items = <String>['a', 'b', 'c'];

    expect(budget.keepNewest(items, (s) => s, tokens: 50), items);
  });

  test('keepNewest can be forced to keep the newest item', () {
    const budget = ContextBudget(inputTokens: 10);
    final items = <String>['aaaa', '中文中文'];

    final kept = budget.keepNewest(items, (s) => s, tokens: 0, minItems: 1);

    expect(kept, <String>['中文中文']);
  });

  test('keepTail returns the text whole when it already fits', () {
    const budget = ContextBudget(inputTokens: 100);

    expect(budget.keepTail('hello 你好', tokens: 50), 'hello 你好');
    expect(budget.keepTail('', tokens: 50), '');
  });

  test('keepTail keeps the newest characters', () {
    const budget = ContextBudget(inputTokens: 100);

    expect(budget.keepTail('hello world 你好世界', tokens: 4), '你好世界');
  });

  test('keepTail cuts on a nearby space instead of mid word', () {
    const budget = ContextBudget(inputTokens: 100);

    expect(budget.keepTail('aaaa bbbb cccc', tokens: 2), 'cccc');
  });

  test('keepTail returns nothing when no tokens are left', () {
    const budget = ContextBudget(inputTokens: 100);

    expect(budget.keepTail('还有一点内容', tokens: 0), '');
  });
}
