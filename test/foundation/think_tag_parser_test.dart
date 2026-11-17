import 'package:anoworld/foundation/ai/think_tag_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('extracts leading think block', () {
    final (content, reasoning) = ThinkTagParser.extract(
      '<think>plan</think>\nhello',
    );
    expect(content, 'hello');
    expect(reasoning, 'plan');
  });

  test('leaves plain text alone', () {
    final (content, reasoning) = ThinkTagParser.extract('plain');
    expect(content, 'plain');
    expect(reasoning, isNull);
  });
}
