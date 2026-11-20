import 'package:anoworld/domain/ai/create/create_tool_result.dart';

/// One staged change inside a turn: the tool that proposed it plus its
/// confirm payload (`kind` / `ops` / preview fields).
class CreateTurnProposal {
  const CreateTurnProposal({required this.toolName, required this.preview});

  final String toolName;
  final Map<String, dynamic> preview;

  /// Proposal kind (`world.patch`, `main.replace`, ...); falls back to the
  /// tool name for payloads without one.
  String get kind => preview['kind']?.toString() ?? toolName;
}

/// Outcome of one create-assistant turn.
///
/// A normal turn leaves one of these meaningful:
/// - [proposals]: changes waiting for the user's confirmation (cross-layer
///   mode may carry several, one per layer);
/// - [answer]: plain chat text with nothing to write;
/// - [errorMessage]: the turn could not finish.
///
/// [calledTools] records tool names in call order for logs and diagnostics.
class CreateAgentTurnResult {
  const CreateAgentTurnResult({
    this.toolName,
    this.result,
    this.proposals = const <CreateTurnProposal>[],
    this.answer = '',
    this.errorMessage,
    this.calledTools = const <String>[],
  });

  const CreateAgentTurnResult.error(String message)
    : toolName = null,
      result = null,
      proposals = const <CreateTurnProposal>[],
      answer = '',
      errorMessage = message,
      calledTools = const <String>[];

  /// Last tool name, or the proposal kind for a text-only reply.
  final String? toolName;

  /// The single-proposal result, kept for callers that only read one change.
  final CreateToolResult? result;

  /// Every staged change of this turn, in the order the model submitted them.
  final List<CreateTurnProposal> proposals;

  final String answer;
  final String? errorMessage;
  final List<String> calledTools;

  /// First proposal preview: the one-change shorthand.
  Map<String, dynamic>? get proposal => proposals.isNotEmpty
      ? proposals.first.preview
      : result?.userConfirmPayload;

  bool get hasProposal =>
      proposals.isNotEmpty || result?.userConfirmPayload != null;

  bool get hasAnswer =>
      result == null && errorMessage == null && answer.isNotEmpty;

  /// Proposal-level failure message from the tool itself.
  String? get toolError => result?.errorMessage;
}
