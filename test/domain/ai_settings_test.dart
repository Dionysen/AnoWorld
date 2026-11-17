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

    expect(settings.text.kind, AiTextProviderKind.openAiCompatible);
    expect(settings.text.baseUrl, 'https://api.example.com/v1');
    expect(settings.text.model, 'gpt-old');
  });

  test('image channel migrates old text provider kinds', () {
    final settings = AiSettings.fromJson(<String, dynamic>{
      'image': <String, dynamic>{
        'kind': 'deepSeek',
        'baseUrl': 'https://api.deepseek.com/v1',
        'model': 'x',
      },
    });
    expect(settings.image.kind, AiImageProviderKind.openAiCompatible);
  });

  test('text and image provider lists differ', () {
    expect(
      AiTextProviderKind.values.map((e) => e.name).toSet().contains('comfyui'),
      isFalse,
    );
    expect(
      AiImageProviderKind.values.map((e) => e.name).contains('comfyui'),
      isTrue,
    );
    expect(
      AiImageProviderKind.values.map((e) => e.name).contains('deepSeek'),
      isFalse,
    );
  });

  test('switching text kind restores slot when available', () {
    var settings = const AiSettings(
      text: AiTextEndpoint(
        kind: AiTextProviderKind.openai,
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'sk-oai',
        model: 'gpt-4o-mini',
      ),
    );
    settings = settings.withText(settings.text);
    settings = settings.switchTextKind(AiTextProviderKind.deepSeek);
    expect(settings.text.kind, AiTextProviderKind.deepSeek);

    settings = settings.switchTextKind(AiTextProviderKind.openai);
    expect(settings.text.apiKey, 'sk-oai');
    expect(settings.text.model, 'gpt-4o-mini');
  });

  test('text endpoint round-trips reasoningEffort', () {
    const endpoint = AiTextEndpoint(
      kind: AiTextProviderKind.openai,
      model: 'gpt-4o',
      reasoningEffort: AiReasoningEffort.high,
    );
    final restored = AiTextEndpoint.fromJson(endpoint.toJson());
    expect(restored.reasoningEffort, AiReasoningEffort.high);
    expect(
      AiTextEndpoint.fromJson(<String, dynamic>{}).reasoningEffort,
      AiReasoningEffort.auto,
    );
  });
}
