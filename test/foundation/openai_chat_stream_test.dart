import 'dart:convert';

import 'package:anoworld/foundation/ai/openai_chat_client.dart';
import 'package:anoworld/foundation/ai/openai_chat_message.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// Sends the body as separate chunks, so SSE line handling is exercised.
class _ChunkedClient extends http.BaseClient {
  _ChunkedClient(this.chunks, {this.contentType = 'text/event-stream'});

  final List<String> chunks;
  final String contentType;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream<List<int>>.fromIterable(chunks.map(utf8.encode)),
      200,
      headers: {'content-type': contentType},
    );
  }
}

void main() {
  test('streams SSE deltas and asks for stream mode', () async {
    late String body;
    final client = _ChunkedClient(<String>[
      'data: {"choices":[{"delta":{"content":"你"}}]}\n\n',
      'data: {"choices":[{"delta":{"content":"好"}}]}\n\ndata: {"choices":',
      '[{"delta":{"content":"！"},"finish_reason":"stop"}]}\n\n',
      'data: [DONE]\n\n',
    ]);
    final chat = OpenAiChatClient(
      client: _RecordingClient(
        client,
        (request) => body = (request as http.Request).body,
      ),
    );

    final deltas = await chat
        .stream(
          baseUrl: 'https://api.example.com/v1',
          apiKey: 'sk-test',
          model: 'demo',
          messages: const [
            OpenAiChatMessage(role: 'user', content: 'hi'),
          ],
        )
        .toList();

    expect(body, contains('"stream":true'));
    expect(
      deltas.map((delta) => delta.content).join(),
      '你好！',
    );
    expect(deltas.last.finishReason, 'stop');
  });

  test('one-shot JSON body is delivered as a single delta', () async {
    final client = _ChunkedClient(
      <String>[
        '{"choices":[{"message":{"content":"整段",'
            '"reasoning_content":"想过"}}]}',
      ],
      contentType: 'application/json',
    );
    final chat = OpenAiChatClient(client: client);

    final deltas = await chat
        .stream(
          baseUrl: 'https://api.example.com/v1',
          apiKey: 'sk-test',
          model: 'demo',
          messages: const [
            OpenAiChatMessage(role: 'user', content: 'hi'),
          ],
        )
        .toList();

    expect(deltas.first.reasoning, '想过');
    expect(deltas.last.content, '整段');
  });

  test('keeps serve-side errors as request failures', () async {
    final client = _ChunkedClient(
      <String>['{"error":{"message":"余额不足"}}'],
      contentType: 'application/json',
    );
    final chat = OpenAiChatClient(
      client: _StatusClient(client, 402),
    );

    await expectLater(
      chat
          .stream(
            baseUrl: 'https://api.example.com/v1',
            apiKey: 'sk-test',
            model: 'demo',
            messages: const [
              OpenAiChatMessage(role: 'user', content: 'hi'),
            ],
          )
          .toList(),
      throwsA(
        isA<OpenAiChatException>().having(
          (error) => error.message,
          'message',
          '余额不足',
        ),
      ),
    );
  });

  test('names an empty stream instead of returning nothing', () async {
    final client = _ChunkedClient(<String>[
      'data: {"choices":[{"delta":{}}]}\n\ndata: [DONE]\n\n',
    ]);
    final chat = OpenAiChatClient(client: client);

    await expectLater(
      chat
          .stream(
            baseUrl: 'https://api.example.com/v1',
            apiKey: 'sk-test',
            model: 'demo',
            messages: const [
              OpenAiChatMessage(role: 'user', content: 'hi'),
            ],
          )
          .toList(),
      throwsA(isA<OpenAiChatException>()),
    );
  });
}

/// Forwards sends to [inner] while letting the test inspect the request.
class _RecordingClient extends http.BaseClient {
  _RecordingClient(this.inner, this.onRequest);

  final http.BaseClient inner;
  final void Function(http.BaseRequest request) onRequest;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    onRequest(request);
    return inner.send(request);
  }
}

/// Same as [_ChunkedClient] but with a custom status code.
class _StatusClient extends http.BaseClient {
  _StatusClient(this.inner, this.status);

  final http.BaseClient inner;
  final int status;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await inner.send(request);
    return http.StreamedResponse(
      response.stream,
      status,
      headers: response.headers,
    );
  }
}
