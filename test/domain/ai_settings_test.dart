import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AiSettings migrates legacy flat endpoints', () {
    final settings = AiSettings.fromJson(<String, dynamic>{
      'text': <String, dynamic>{
        'baseUrl': 'https://api.example.com/v1',
        'apiKey': 'sk-old',
        'model': 'gpt-old',
      },
    });

    expect(settings.text.kind, AiProviderKind.openAiCompatible);
    expect(settings.text.baseUrl, 'https://api.example.com/v1');
    expect(settings.text.model, 'gpt-old');
  });

  test('AiSettings migrates multi-provider active entry', () {
    final settings = AiSettings.fromJson(<String, dynamic>{
      'text': <String, dynamic>{
        'activeId': 'p2',
        'providers': [
          <String, dynamic>{
            'id': 'p1',
            'kind': 'openai',
            'baseUrl': 'https://api.openai.com/v1',
            'model': 'gpt-a',
          },
          <String, dynamic>{
            'id': 'p2',
            'kind': 'deepSeek',
            'baseUrl': 'https://api.deepseek.com/v1',
            'apiKey': 'sk',
            'model': 'deepseek-chat',
          },
        ],
      },
    });

    expect(settings.text.kind, AiProviderKind.deepSeek);
    expect(settings.text.model, 'deepseek-chat');
  });

  test('switching kind restores slot when available', () {
    var settings = const AiSettings(
      text: AiEndpointConfig(
        kind: AiProviderKind.openai,
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'sk-oai',
        model: 'gpt-4o-mini',
      ),
    );
    settings = settings.withText(settings.text);
    settings = settings.switchTextKind(AiProviderKind.deepSeek);
    expect(settings.text.kind, AiProviderKind.deepSeek);
    expect(settings.text.baseUrl, AiProviderKind.deepSeek.defaultBaseUrl);

    settings = settings.switchTextKind(AiProviderKind.openai);
    expect(settings.text.apiKey, 'sk-oai');
    expect(settings.text.model, 'gpt-4o-mini');
  });
}
