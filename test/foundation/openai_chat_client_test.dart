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
    final result = await chat.complete(
      baseUrl: 'https://api.example.com/v1/',
      apiKey: 'sk-test',
      model: 'demo',
      messages: const [
        OpenAiChatMessage(role: 'user', content: 'hi'),
      ],
    );
    expect(result.content, 'hello');
    expect(result.reasoning, isNull);
  });

  test('includes reasoning_effort when provided', () async {
    final client = MockClient((request) async {
      expect(request.body, contains('"reasoning_effort":"high"'));
      return http.Response(
        '{"choices":[{"message":{"content":"ok"}}]}',
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final chat = OpenAiChatClient(client: client);
    final result = await chat.complete(
      baseUrl: 'https://api.example.com/v1',
      apiKey: 'sk-test',
      model: 'demo',
      reasoningEffort: 'high',
      messages: const [
        OpenAiChatMessage(role: 'user', content: 'hi'),
      ],
    );
    expect(result.content, 'ok');
  });

  test('includes nested reasoning for openrouter style', () async {
    final client = MockClient((request) async {
      expect(request.body, contains('"reasoning":{"effort":"low"}'));
      expect(request.body, isNot(contains('reasoning_effort')));
      return http.Response(
        '{"choices":[{"message":{"content":"ok"}}]}',
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final chat = OpenAiChatClient(client: client);
    final result = await chat.complete(
      baseUrl: 'https://openrouter.ai/api/v1',
      apiKey: 'sk-test',
      model: 'demo',
      reasoning: const {'effort': 'low'},
      messages: const [
        OpenAiChatMessage(role: 'user', content: 'hi'),
      ],
    );
    expect(result.content, 'ok');
  });

  test('extracts reasoning_content field', () async {
    final client = MockClient((request) async {
      return http.Response(
        '{"choices":[{"message":{"content":"你好",'
        '"reasoning_content":"先打招呼"}}]}',
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final chat = OpenAiChatClient(client: client);
    final result = await chat.complete(
      baseUrl: 'https://api.example.com/v1',
      apiKey: 'sk-test',
      model: 'demo',
      messages: const [
        OpenAiChatMessage(role: 'user', content: 'hi'),
      ],
    );
    expect(result.content, '你好');
    expect(result.reasoning, '先打招呼');
  });

  test('extracts leading think tags into reasoning', () async {
    final client = MockClient((request) async {
      return http.Response(
        '{"choices":[{"message":{"content":'
        '"<think>想一下</think>\\n正文"}}]}',
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final chat = OpenAiChatClient(client: client);
    final result = await chat.complete(
      baseUrl: 'https://api.example.com/v1',
      apiKey: 'sk-test',
      model: 'demo',
      messages: const [
        OpenAiChatMessage(role: 'user', content: 'hi'),
      ],
    );
    expect(result.content, '正文');
    expect(result.reasoning, '想一下');
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
