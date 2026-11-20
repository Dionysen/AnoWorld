import 'package:anoworld/domain/ai/context_budget.dart';
import 'package:anoworld/foundation/ai/openai_chat_message.dart';
import 'package:anoworld/foundation/text/token_estimator.dart';

/// Keeps a create-assistant tool loop inside the input budget by shrinking old
/// tool replies, not by dropping messages: an assistant `tool_calls` message
/// without its matching `tool` reply is rejected by most providers.
///
/// The newest tool reply always survives, so the model never continues from an
/// answer whose own result it can no longer see.
class CreateHistoryFit {
  const CreateHistoryFit();

  /// Replacement body for an elided reply; tells the model it can read again.
  static const String elidedBody =
      '{"ok":true,"elided":true,"note":"较早的读取结果已省略，需要时重新调用即可"}';

  ({List<OpenAiChatMessage> messages, int elided}) fit(
    List<OpenAiChatMessage> messages, {
    required ContextBudget budget,
  }) {
    final costs = <int>[for (final message in messages) _cost(message)];
    var total = costs.fold<int>(0, (sum, cost) => sum + cost);
    if (total <= budget.inputTokens) {
      return (messages: messages, elided: 0);
    }
    final newestTool = messages.lastIndexWhere((m) => m.role == 'tool');
    final stubCost = TokenEstimator.estimate(elidedBody);
    final fitted = List<OpenAiChatMessage>.of(messages);
    var elided = 0;
    for (var i = 0; i < fitted.length && total > budget.inputTokens; i++) {
      if (fitted[i].role != 'tool' || i == newestTool) continue;
      final saved = costs[i] - stubCost;
      if (saved <= 0) continue;
      fitted[i] = OpenAiChatMessage(
        role: 'tool',
        toolCallId: fitted[i].toolCallId,
        name: fitted[i].name,
        content: elidedBody,
      );
      total -= saved;
      elided++;
    }
    return (messages: fitted, elided: elided);
  }

  static int _cost(OpenAiChatMessage message) {
    var tokens = TokenEstimator.estimate(message.content);
    for (final call in message.toolCalls) {
      tokens += TokenEstimator.estimate('${call.name}${call.arguments}');
    }
    return tokens;
  }
}
