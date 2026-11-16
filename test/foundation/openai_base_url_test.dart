import 'package:anoworld/foundation/ai/openai_base_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('strips trailing slash and endpoint suffixes', () {
    expect(
      normalizeOpenAiBaseUrl('https://api.example.com/v1/'),
      'https://api.example.com/v1',
    );
    expect(
      normalizeOpenAiBaseUrl('https://api.example.com/v1/models'),
      'https://api.example.com/v1',
    );
    expect(
      normalizeOpenAiBaseUrl('https://api.example.com/v1/chat/completions'),
      'https://api.example.com/v1',
    );
  });
}
