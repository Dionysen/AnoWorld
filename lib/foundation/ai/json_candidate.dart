import 'dart:convert';

/// Tries several shapes of model output until one decodes as JSON.
///
/// Candidate order (aligned with NativeTavern `ChatChoicePromptService`):
/// fenced ```json``` → full trimmed text → first `{…}` / `[…]` slice.
Object? decodeJsonCandidate(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;

  final candidates = <String>[];

  final fenceMatch = RegExp(
    r'```(?:json)?\s*([\s\S]*?)```',
    caseSensitive: false,
  ).firstMatch(trimmed);
  if (fenceMatch != null) {
    candidates.add(fenceMatch.group(1)!.trim());
  }

  candidates.add(trimmed);

  final objectStart = trimmed.indexOf('{');
  final objectEnd = trimmed.lastIndexOf('}');
  if (objectStart >= 0 && objectEnd > objectStart) {
    candidates.add(trimmed.substring(objectStart, objectEnd + 1));
  }

  final arrayStart = trimmed.indexOf('[');
  final arrayEnd = trimmed.lastIndexOf(']');
  if (arrayStart >= 0 && arrayEnd > arrayStart) {
    candidates.add(trimmed.substring(arrayStart, arrayEnd + 1));
  }

  final seen = <String>{};
  for (final candidate in candidates) {
    if (!seen.add(candidate)) continue;
    try {
      return jsonDecode(candidate);
    } catch (_) {
      // Try next candidate.
    }
  }
  return null;
}
