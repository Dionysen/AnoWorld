import 'package:anoworld/domain/ai/ai_prompt_context.dart';
import 'package:anoworld/domain/ai/create/create_tool_services.dart';
import 'package:anoworld/domain/card_import/st_card_project_mapper.dart';
import 'package:anoworld/domain/models/project.dart';

class CreateToolContext {
  const CreateToolContext({
    this.draft,
    this.project,
    this.ai,
    required this.services,
  });

  final StCardImportDraft? draft;
  final Project? project;
  final AiPromptContext? ai;
  final CreateToolServices services;

  CreateToolContext copyWith({
    StCardImportDraft? draft,
    Project? project,
    AiPromptContext? ai,
  }) {
    return CreateToolContext(
      draft: draft ?? this.draft,
      project: project ?? this.project,
      ai: ai ?? this.ai,
      services: services,
    );
  }
}