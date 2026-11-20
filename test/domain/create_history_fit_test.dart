import 'package:anoworld/domain/ai/context_budget.dart';
import 'package:anoworld/domain/ai/create/create_history_fit.dart';
import 'package:anoworld/foundation/ai/openai_chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const fit = CreateHistoryFit();

  OpenAiChatMessage tool(String id, String body) =>
      OpenAiChatMessage(role: 'tool', toolCallId: id, content: body);

  String body(int size) => '设' * size;

  test('leaves an in-budget loop untouched', () {
    final messages = <OpenAiChatMessage>[
      const OpenAiChatMessage(role: 'system', content: '规则'),
      const OpenAiChatMessage(role: 'user', content: '把客栈改得更冷'),
      tool('call_1', body(10)),
    ];

    final fitted = fit.fit(
      messages,
      budget: const ContextBudget(inputTokens: 2048),
    );

    expect(fitted.elided, 0);
    expect(fitted.messages, same(messages));
  });

  test('elides old tool replies and keeps the newest one', () {
    final messages = <OpenAiChatMessage>[
      OpenAiChatMessage(role: 'system', content: body(20)),
      OpenAiChatMessage(role: 'user', content: body(10)),
      const OpenAiChatMessage(
        role: 'assistant',
        toolCalls: <OpenAiToolCall>[
          OpenAiToolCall(id: 'call_1', name: 'world.read_entry'),
        ],
      ),
      tool('call_1', body(400)),
      const OpenAiChatMessage(
        role: 'assistant',
        toolCalls: <OpenAiToolCall>[
          OpenAiToolCall(id: 'call_2', name: 'cast.read_member'),
        ],
      ),
      tool('call_2', body(400)),
    ];

    final fitted = fit.fit(
      messages,
      budget: const ContextBudget(inputTokens: 500),
    );

    expect(fitted.elided, 1);
    expect(fitted.messages, hasLength(messages.length));
    expect(
      [for (final m in fitted.messages) m.role],
      [for (final m in messages) m.role],
    );
    expect(fitted.messages[3].content, CreateHistoryFit.elidedBody);
    expect(fitted.messages[3].toolCallId, 'call_1');
    // The reply the model last acted on stays readable.
    expect(fitted.messages[5].content, body(400));
  });

  test('never elides the only tool reply, even when still over budget', () {
    final messages = <OpenAiChatMessage>[
      OpenAiChatMessage(role: 'user', content: body(10)),
      tool('call_1', body(5000)),
    ];

    final fitted = fit.fit(
      messages,
      budget: const ContextBudget(inputTokens: 100),
    );

    expect(fitted.elided, 0);
    expect(fitted.messages[1].content, body(5000));
  });

  test('keeps non-tool messages intact', () {
    final messages = <OpenAiChatMessage>[
      OpenAiChatMessage(role: 'system', content: body(300)),
      OpenAiChatMessage(role: 'user', content: body(300)),
      tool('call_1', body(200)),
      tool('call_2', body(200)),
    ];

    final fitted = fit.fit(
      messages,
      budget: const ContextBudget(inputTokens: 400),
    );

    expect(fitted.messages[0].content, body(300));
    expect(fitted.messages[1].content, body(300));
    expect(fitted.messages[2].content, CreateHistoryFit.elidedBody);
  });
}
