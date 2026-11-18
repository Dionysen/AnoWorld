import 'package:anoworld/domain/validation/project_issue.dart';

/// JSON-friendly tool result for Runner / future assistant.
class CreateToolResult {
  const CreateToolResult._({
    required this.ok,
    this.payload,
    this.validationIssues,
    this.userConfirmPayload,
    this.errorMessage,
  });

  final bool ok;
  final Map<String, dynamic>? payload;
  final List<ProjectIssue>? validationIssues;
  final Map<String, dynamic>? userConfirmPayload;
  final String? errorMessage;

  factory CreateToolResult.success(Map<String, dynamic> payload) {
    return CreateToolResult._(ok: true, payload: payload);
  }

  factory CreateToolResult.validationFailed(List<ProjectIssue> issues) {
    return CreateToolResult._(ok: false, validationIssues: issues);
  }

  factory CreateToolResult.userConfirmRequired(Map<String, dynamic> preview) {
    return CreateToolResult._(
      ok: true,
      userConfirmPayload: preview,
    );
  }

  factory CreateToolResult.error(String message) {
    return CreateToolResult._(ok: false, errorMessage: message);
  }
}