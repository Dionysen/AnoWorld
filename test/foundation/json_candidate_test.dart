import 'package:anoworld/foundation/ai/json_candidate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decodes fenced json', () {
    final decoded = decodeJsonCandidate('```json\n{"a":1}\n```');
    expect(decoded, {'a': 1});
  });

  test('decodes object slice from prose', () {
    final decoded = decodeJsonCandidate('here: {"b":true} thanks');
    expect(decoded, {'b': true});
  });

  test('returns null for garbage', () {
    expect(decodeJsonCandidate('not json'), isNull);
  });
}
