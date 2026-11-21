import 'package:anoworld/domain/ai/ai_prompt_context.dart';
import 'package:anoworld/domain/ai/create/create_tool_services.dart';
import 'package:anoworld/domain/card_import/st_card_project_mapper.dart';
import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';

class CreateToolContext {
  const CreateToolContext({
    this.draft,
    this.project,
    this.ai,
    this.minGraphStations = AiSettings.defaultMinGraphStations,
    required this.services,
  });

  final StCardImportDraft? draft;
  final Project? project;
  final AiPromptContext? ai;

  /// Floor for full `main.replace` skeletons (from AI settings).
  final int minGraphStations;

  final CreateToolServices services;

  CreateToolContext copyWith({
    StCardImportDraft? draft,
    Project? project,
    AiPromptContext? ai,
    int? minGraphStations,
  }) {
    return CreateToolContext(
      draft: draft ?? this.draft,
      project: project ?? this.project,
      ai: ai ?? this.ai,
      minGraphStations: minGraphStations ?? this.minGraphStations,
      services: services,
    );
  }
}