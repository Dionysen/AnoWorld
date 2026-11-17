import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/ai/expand_edge_detail_action.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/foundation/ai/st_ai_preset.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTextClient implements AiTextClient {
  String? lastUser;
  String response = '夜里敲门，客栈掌柜犹豫后开门。';

  @override
  Future<String> complete({
    required AiTextEndpoint endpoint,
    required String system,
    required String user,
    GenerationPreset? generation,
  }) async {
    lastUser = user;
    return response;
  }
}

void main() {
  const endpoint = AiTextEndpoint(
    baseUrl: 'https://example.com/v1',
    apiKey: 'sk-test',
    model: 'gpt-test',
  );

  test('expands title and detail via text client', () async {
    final client = _FakeTextClient();
    final action = ExpandEdgeDetailAction(textClient: client);
    final out = await action.expand(
      endpoint: endpoint,
      title: '敲门投宿',
      detail: '雨夜',
      fromTitle: '城门',
      toTitle: '客栈',
    );
    expect(out, contains('客栈'));
    expect(client.lastUser, contains('敲门投宿'));
    expect(client.lastUser, contains('雨夜'));
  });

  test('requires a title', () async {
    final action = ExpandEdgeDetailAction(textClient: _FakeTextClient());
    expect(
      () => action.expand(endpoint: endpoint, title: '  ', detail: ''),
      throwsA(isA<AiTextException>()),
    );
  });
}
