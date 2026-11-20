/// Persisted create-assistant conversation of one story (messages + composer).
class CreateAssistantDraft {
  const CreateAssistantDraft({
    this.projectId,
    this.projectTitle = '',
    this.composer = '',
    this.lines = const [],
  });

  final String? projectId;
  final String projectTitle;
  final String composer;
  final List<CreateAssistantDraftLine> lines;

  bool get isEmpty => composer.trim().isEmpty && lines.isEmpty;

  Map<String, Object?> toJson() => {
        'projectId': projectId,
        'projectTitle': projectTitle,
        'composer': composer,
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
      lines: lines,
    );
  }
}

/// Every story's conversation, plus what the panel was doing last.
///
/// One transcript per story: switching stories swaps the visible messages
/// instead of appending to a shared log, and deleting a story drops its
/// transcript with it.
class CreateAssistantDrafts {
  const CreateAssistantDrafts({
    this.lastProjectId,
    this.composer = '',
    this.byStory = const <String, CreateAssistantDraft>{},
  });

  /// Story the panel was on, so a restart resumes the same conversation.
  final String? lastProjectId;

  /// Input typed before any story was picked.
  final String composer;

  /// Conversations by story id.
  final Map<String, CreateAssistantDraft> byStory;

  bool get isEmpty => byStory.isEmpty && composer.trim().isEmpty;

  CreateAssistantDrafts withoutStory(String projectId) {
    final next = Map<String, CreateAssistantDraft>.of(byStory)
      ..remove(projectId);
    return CreateAssistantDrafts(
      lastProjectId: lastProjectId == projectId ? null : lastProjectId,
      composer: composer,
      byStory: next,
    );
  }

  Map<String, Object?> toJson() => {
        'lastProjectId': lastProjectId,
        'composer': composer,
        'stories': {
          for (final entry in byStory.entries)
            entry.key: entry.value.toJson(),
        },
      };

  static CreateAssistantDrafts? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<Object?, Object?>.from(raw);
    final storiesRaw = map['stories'];
    final byStory = <String, CreateAssistantDraft>{};
    if (storiesRaw is Map) {
      for (final entry in storiesRaw.entries) {
        final id = entry.key;
        if (id is! String || id.isEmpty) continue;
        final draft = CreateAssistantDraft.tryParse(entry.value);
        if (draft != null) byStory[id] = draft;
      }
    }
    final last = map['lastProjectId'];
    return CreateAssistantDrafts(
      lastProjectId: last is String && last.isNotEmpty ? last : null,
      composer: map['composer'] is String ? map['composer'] as String : '',
      byStory: byStory,
    );
  }

  /// Reads the single-conversation draft of the previous version.
  static CreateAssistantDrafts fromLegacyDraft(CreateAssistantDraft draft) {
    final id = draft.projectId;
    return CreateAssistantDrafts(
      lastProjectId: id,
      composer: id == null ? draft.composer : '',
      byStory: {?id: draft},
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
