import 'package:anoworld/domain/ai/create/create_assistant_target.dart';

/// Persisted create-assistant conversation (story pick + messages + composer).
class CreateAssistantDraft {
  const CreateAssistantDraft({
    this.projectId,
    this.projectTitle = '',
    this.composer = '',
    this.lines = const [],
    this.target = CreateAssistantTarget.graph,
  });

  final String? projectId;
  final String projectTitle;
  final String composer;
  final List<CreateAssistantDraftLine> lines;
  final CreateAssistantTarget target;

  bool get isEmpty =>
      (projectId == null || projectId!.isEmpty) &&
      projectTitle.trim().isEmpty &&
      composer.trim().isEmpty &&
      lines.isEmpty;

  Map<String, Object?> toJson() => {
        'projectId': projectId,
        'projectTitle': projectTitle,
        'composer': composer,
        'target': target.wireName,
        'lines': [for (final line in lines) line.toJson()],
      };

  static CreateAssistantDraft? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<Object?, Object?>.from(raw);
    final linesRaw = map['lines'];
    final lines = <CreateAssistantDraftLine>[];
    if (linesRaw is List) {
      for (final item in linesRaw) {
        final line = CreateAssistantDraftLine.tryParse(item);
        if (line != null) lines.add(line);
      }
    }
    final id = map['projectId'];
    return CreateAssistantDraft(
      projectId: id is String && id.isNotEmpty ? id : null,
      projectTitle: map['projectTitle'] is String
          ? map['projectTitle'] as String
          : '',
      composer: map['composer'] is String ? map['composer'] as String : '',
      target: CreateAssistantTarget.parse(
        map['target'] is String ? map['target'] as String : null,
      ),
      lines: lines,
    );
  }
}

class CreateAssistantDraftLine {
  const CreateAssistantDraftLine({
    required this.role,
    required this.text,
  });

  /// `user` or `assistant`.
  final String role;
  final String text;

  Map<String, Object?> toJson() => {'role': role, 'text': text};

  static CreateAssistantDraftLine? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<Object?, Object?>.from(raw);
    final role = map['role'];
    final text = map['text'];
    if (role is! String || text is! String) return null;
    if (role != 'user' && role != 'assistant') return null;
    if (text.trim().isEmpty) return null;
    return CreateAssistantDraftLine(role: role, text: text);
  }
}
