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
        kind: AiProviderKind.openAiCompatible,
        baseUrl: 'https://api.example.com/v1/',
        apiKey: 'sk-test',
      ),
    );

    expect(models, ['a-model', 'b-model']);
  });

  test('throws when api key missing for providers that need it', () async {
    final catalog = HttpOpenAiModelCatalog(client: MockClient((_) async {
      fail('should not call network');
    }));

    expect(
      () => catalog.listModels(
        const AiEndpointConfig(
          kind: AiProviderKind.openai,
          baseUrl: 'https://api.openai.com/v1',
        ),
      ),
      throwsA(isA<AiModelCatalogException>()),
    );
  });
}
