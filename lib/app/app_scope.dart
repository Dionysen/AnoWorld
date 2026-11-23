import 'package:anoworld/app/project_change_notifier.dart';
import 'package:anoworld/app/settings_controller.dart';
import 'package:anoworld/data/ai/http_openai_model_catalog.dart';
import 'package:anoworld/domain/ai/ai_model_catalog.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/repositories/project_folder_repository.dart';
import 'package:anoworld/domain/repositories/project_repository.dart';
import 'package:anoworld/domain/repositories/save_repository.dart';
import 'package:anoworld/foundation/layout/app_pane_width.dart';
import 'package:anoworld/home/create_assistant_controller.dart';
import 'package:anoworld/home/library_display_prefs.dart';
import 'package:flutter/widgets.dart';

/// App-wide services. Business pages read repositories from here.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.projects,
    required this.saves,
    required this.folders,
    required this.settings,
    required this.libraryDisplay,
    required this.paneWidth,
    required this.createAssistant,
    required this.projectChanges,
    this.modelCatalog,
    this.textClient,
    required super.child,
  });

  final ProjectRepository projects;
  final SaveRepository saves;
  final ProjectFolderRepository folders;
  final SettingsController settings;
  final LibraryDisplayController libraryDisplay;
  final AppPaneWidthController paneWidth;
  final CreateAssistantController createAssistant;
  final ProjectChangeNotifier projectChanges;
  final AiModelCatalog? modelCatalog;
  final AiTextClient? textClient;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in context');
    return scope!;
  }

  static ProjectRepository projectsOf(BuildContext context) =>
      of(context).projects;

  static SaveRepository savesOf(BuildContext context) => of(context).saves;

  static ProjectFolderRepository foldersOf(BuildContext context) =>
      of(context).folders;

  static SettingsController settingsOf(BuildContext context) =>
      of(context).settings;

  static LibraryDisplayController libraryDisplayOf(BuildContext context) =>
      of(context).libraryDisplay;

  /// Shared master-detail divider position (wide-window list | detail hubs).
  static AppPaneWidthController paneWidthOf(BuildContext context) =>
      of(context).paneWidth;

  static CreateAssistantController createAssistantOf(BuildContext context) =>
      of(context).createAssistant;

  static ProjectChangeNotifier projectChangesOf(BuildContext context) =>
      of(context).projectChanges;

  static AiModelCatalog modelCatalogOf(BuildContext context) =>
      of(context).modelCatalog ?? HttpOpenAiModelCatalog();

  static AiTextClient textClientOf(BuildContext context) =>
      of(context).textClient ?? EndpointAiTextClient();

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      projects != oldWidget.projects ||
      saves != oldWidget.saves ||
      folders != oldWidget.folders ||
      settings != oldWidget.settings ||
      libraryDisplay != oldWidget.libraryDisplay ||
      paneWidth != oldWidget.paneWidth ||
      createAssistant != oldWidget.createAssistant ||
      projectChanges != oldWidget.projectChanges ||
      modelCatalog != oldWidget.modelCatalog ||
      textClient != oldWidget.textClient;
}
