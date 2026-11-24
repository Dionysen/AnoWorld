import 'package:anoworld/data/ai/http_openai_model_catalog.dart';
import 'package:anoworld/domain/ai/ai_model_catalog.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('lists model ids from OpenAI-compatible response', () async {
    final client = MockClient((request) async {
      expect(request.url.toString(), 'https://api.example.com/v1/models');
      expect(request.headers['Authorization'], 'Bearer sk-test');
      return http.Response(
        '{"data":[{"id":"b-model"},{"id":"a-model"}]}',
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final catalog = HttpOpenAiModelCatalog(client: client);
    final models = await catalog.listModels(
      const AiEndpointConfig(
        baseUrl: 'https://api.example.com/v1/',
        apiKey: 'sk-test',
        model: '',
        needsApiKey: true,
        defaultBaseUrl: 'http://localhost:8080/v1',
      ),
    );

    expect(models, ['a-model', 'b-model']);
  });

  test('lists ComfyUI checkpoints from /models/checkpoints', () async {
    final client = MockClient((request) async {
      expect(
        request.url.toString(),
        'http://127.0.0.1:8188/models/checkpoints',
      );
      return http.Response(
        '["NoobAI-XL-Vpred-v1.0.safetensors","other.safetensors"]',
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final catalog = HttpOpenAiModelCatalog(client: client);
    final models = await catalog.listModels(
      const AiEndpointConfig(
        baseUrl: 'http://127.0.0.1:8188',
        apiKey: '',
        model: '',
        needsApiKey: false,
        defaultBaseUrl: 'http://127.0.0.1:8188',
        imageKind: AiImageProviderKind.comfyui,
      ),
    );

    expect(models, [
      'NoobAI-XL-Vpred-v1.0.safetensors',
      'other.safetensors',
    ]);
  });

  test('throws when api key missing for providers that need it', () async {
    final catalog = HttpOpenAiModelCatalog(client: MockClient((_) async {
      fail('should not call network');
    }));

    expect(
      () => catalog.listModels(
        const AiEndpointConfig(
          baseUrl: 'https://api.openai.com/v1',
          apiKey: '',
          model: '',
          needsApiKey: true,
        ),
      ),
      throwsA(isA<AiModelCatalogException>()),
    );
  });

  test('lists ComfyUI loras from /models/loras', () async {
    final client = MockClient((request) async {
      expect(
        request.url.toString(),
        'http://127.0.0.1:8188/models/loras',
      );
      return http.Response(
        '["RLI(noobai)0.1v.safetensors","Nicole.safetensors"]',
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final catalog = HttpOpenAiModelCatalog(client: client);
    final loras = await catalog.listLoras(
      const AiEndpointConfig(
        baseUrl: 'http://127.0.0.1:8188',
        apiKey: '',
        model: '',
        needsApiKey: false,
        defaultBaseUrl: 'http://127.0.0.1:8188',
        imageKind: AiImageProviderKind.comfyui,
      ),
    );

    expect(loras, [
      'Nicole.safetensors',
      'RLI(noobai)0.1v.safetensors',
    ]);
  });

  test('listLoras is empty for non-Comfy providers', () async {
    final catalog = HttpOpenAiModelCatalog(client: MockClient((_) async {
      fail('should not call network');
    }));
    final loras = await catalog.listLoras(
      const AiEndpointConfig(
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'sk',
        model: 'dall-e-3',
        needsApiKey: true,
        imageKind: AiImageProviderKind.openai,
      ),
    );
    expect(loras, isEmpty);
  });
}
