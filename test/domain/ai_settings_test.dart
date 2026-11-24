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

  test('minBridgeLines defaults, clamps and round-trips', () {
    expect(
      const AiSettings().minBridgeLines,
      AiSettings.defaultMinBridgeLines,
    );
    expect(
      AiSettings.fromJson(<String, dynamic>{}).minBridgeLines,
      AiSettings.defaultMinBridgeLines,
    );

    final clampedHigh = const AiSettings().copyWith(minBridgeLines: 99);
    expect(clampedHigh.minBridgeLines, AiSettings.minBridgeLinesUpperBound);

    final clampedLow = AiSettings.fromJson(<String, dynamic>{
      'minBridgeLines': 0,
    });
    expect(clampedLow.minBridgeLines, AiSettings.minBridgeLinesLowerBound);

    final restored = AiSettings.fromJson(<String, dynamic>{
      'minBridgeLines': 5,
    });
    expect(restored.minBridgeLines, 5);
    expect(restored.toJson()['minBridgeLines'], 5);
  });

  test('image steps/upscale/size defaults and round-trip', () {
    expect(const AiImageEndpoint().steps, AiImageEndpoint.defaultSteps);
    expect(const AiImageEndpoint().upscale, isFalse);
    expect(
      const AiImageEndpoint().portraitWidth,
      AiImageEndpoint.defaultPortraitWidth,
    );
    expect(
      const AiImageEndpoint().sceneHeight,
      AiImageEndpoint.defaultSceneHeight,
    );
    expect(
      ImageGenSizePresets.scene.any((p) => p.aspectLabel == '16:9'),
      isTrue,
    );

    final restored = AiImageEndpoint.fromJson(<String, dynamic>{
      'kind': 'comfyui',
      'baseUrl': 'http://127.0.0.1:8188',
      'steps': 8,
      'upscale': true,
      'portraitWidth': 512,
      'portraitHeight': 768,
      'sceneWidth': 1280,
      'sceneHeight': 704,
    });
    expect(restored.steps, 8);
    expect(restored.upscale, isTrue);
    expect(restored.portraitWidth, 512);
    expect(restored.sceneWidth, 1280);
    expect(restored.sceneHeight, 704);
    expect(restored.toJson()['sceneWidth'], 1280);
    expect(restored.lora, AiImageEndpoint.defaultLora);
    expect(restored.loraStrength, AiImageEndpoint.defaultLoraStrength);

    final legacy = AiImageEndpoint.fromJson(<String, dynamic>{
      'resolution': 'small',
    });
    expect(legacy.portraitWidth, 512);
    expect(legacy.sceneWidth, 768);

    expect(
      const AiImageEndpoint().copyWith(steps: 99).steps,
      AiImageEndpoint.stepsUpperBound,
    );
    expect(AiImageEndpoint.clampSize(700), 704);
  });

  test('ComfyUI lora round-trips and can be cleared', () {
    const endpoint = AiImageEndpoint(
      kind: AiImageProviderKind.comfyui,
      baseUrl: 'http://127.0.0.1:8188',
      lora: 'Nicole.safetensors',
      loraStrength: 0.7,
    );
    final restored = AiImageEndpoint.fromJson(endpoint.toJson());
    expect(restored.lora, 'Nicole.safetensors');
    expect(restored.loraStrength, 0.7);
    expect(restored.resolvedLoraName, 'Nicole.safetensors');

    final cleared = endpoint.copyWith(clearLora: true);
    expect(cleared.lora, isEmpty);
    expect(cleared.resolvedLoraName, isNull);

    final off = AiImageEndpoint.fromJson(<String, dynamic>{
      'kind': 'comfyui',
      'lora': '',
    });
    expect(off.lora, isEmpty);

    final switched = const AiImageEndpoint().switchKind(
      AiImageProviderKind.comfyui,
    );
    expect(switched.lora, AiImageEndpoint.defaultLora);
  });

  test('minGraphStations defaults, clamps and round-trips', () {
    expect(
      const AiSettings().minGraphStations,
      AiSettings.defaultMinGraphStations,
    );
    final clamped = const AiSettings().copyWith(minGraphStations: 1);
    expect(clamped.minGraphStations, AiSettings.minGraphStationsLowerBound);
    final restored = AiSettings.fromJson(<String, dynamic>{
      'minGraphStations': 12,
    });
    expect(restored.minGraphStations, 12);
    expect(restored.toJson()['minGraphStations'], 12);
  });
}
