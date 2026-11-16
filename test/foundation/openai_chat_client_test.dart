import 'package:anoworld/foundation/ai/openai_chat_client.dart';
import 'package:anoworld/foundation/ai/openai_chat_message.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('posts chat completions and returns content', () async {
    final client = MockClient((request) async {
      expect(
        request.url.toString(),
        'https://api.example.com/v1/chat/completions',
      );
      expect(request.headers['Authorization'], 'Bearer sk-test');
      expect(request.body, contains('"model":"demo"'));
      return http.Response(
        '{"choices":[{"message":{"content":"hello"}}]}',
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final chat = OpenAiChatClient(client: client);
    final text = await chat.complete(
      baseUrl: 'https://api.example.com/v1/',
      apiKey: 'sk-test',
      model: 'demo',
      messages: const [
        OpenAiChatMessage(role: 'user', content: 'hi'),
      ],
    );
    expect(text, 'hello');
  });

  test('throws when api key missing', () async {
    final chat = OpenAiChatClient(
      client: MockClient((_) async => fail('should not call')),
    );
    expect(
      () => chat.complete(
        baseUrl: 'https://api.example.com/v1',
        apiKey: '',
        needsApiKey: true,
        model: 'demo',
        messages: const [
          OpenAiChatMessage(role: 'user', content: 'hi'),
        ],
      ),
      throwsA(isA<OpenAiChatException>()),
    );
  });
}
