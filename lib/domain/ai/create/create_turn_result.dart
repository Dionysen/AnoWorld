import 'package:anoworld/domain/ai/create/create_tool_result.dart';

/// Outcome of one create-assistant turn.
///
/// Exactly one of [result] (a proposal), [answer] (plain chat text) or
/// [errorMessage] is meaningful; [calledTools] records tool names in call order
/// for logs and diagnostics.
class CreateAgentTurnResult {
  const CreateAgentTurnResult({
    this.toolName,
    this.result,
    this.answer = '',
    this.errorMessage,
    this.calledTools = const <String>[],
  });

  const CreateAgentTurnResult.error(String message)
      : toolName = null,
        result = null,
        answer = '',
        errorMessage = message,
        calledTools = const <String>[];

  /// Last tool name, or the proposal kind for a text-only reply.
  final String? toolName;
  final CreateToolResult? result;
  final String answer;
  final String? errorMessage;
  final List<String> calledTools;

  Map<String, dynamic>? get proposal => result?.userConfirmPayload;

  bool get hasProposal => proposal != null;

  bool get hasAnswer =>
      result == null && errorMessage == null && answer.isNotEmpty;

  /// Proposal-level failure message from the tool itself.
  String? get toolError => result?.errorMessage;
}
