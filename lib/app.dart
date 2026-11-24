import 'dart:async';
import 'dart:typed_data';

import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/app/project_change_notifier.dart';
import 'package:anoworld/app/settings_controller.dart';
import 'package:anoworld/app/visual_image_job_controller.dart';
import 'package:anoworld/data/folder/file_project_folder_repository.dart';
import 'package:anoworld/data/project/folder_project_repository.dart';
import 'package:anoworld/data/save/file_save_repository.dart';
import 'package:anoworld/data/settings/prefs_settings_repository.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/repositories/project_folder_repository.dart';
import 'package:anoworld/domain/repositories/project_repository.dart';
import 'package:anoworld/domain/repositories/save_repository.dart';
import 'package:anoworld/domain/repositories/settings_repository.dart';
import 'package:anoworld/domain/settings/appearance_settings.dart';
import 'package:anoworld/foundation/ai/variables_service.dart';
import 'package:anoworld/foundation/frame/immersive_frame.dart';
import 'package:anoworld/foundation/layout/app_pane_width.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/home/create_assistant_controller.dart';
import 'package:anoworld/home/create_assistant_overlay.dart';
import 'package:anoworld/home/home_page.dart';
import 'package:anoworld/home/library_display_prefs.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class App extends StatefulWidget {
  const App({
    super.key,
    this.projects,
    this.saves,
    this.folders,
    this.settingsRepository,
    this.settingsController,
    this.libraryDisplay,
    this.paneWidth,
    this.createAssistant,
    this.textClient,
    this.pickImportDirectory,
    this.pickImportPackage,
  });

  final ProjectRepository? projects;
  final SaveRepository? saves;
  final ProjectFolderRepository? folders;
  final SettingsRepository? settingsRepository;
  final SettingsController? settingsController;
  final LibraryDisplayController? libraryDisplay;
  final AppPaneWidthController? paneWidth;
  final CreateAssistantController? createAssistant;
  final AiTextClient? textClient;
  final Future<String?> Function()? pickImportDirectory;
  final Future<Uint8List?> Function()? pickImportPackage;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  late final SettingsController _settings = widget.settingsController ??
      SettingsController(
        repository: widget.settingsRepository ?? PrefsSettingsRepository(),
      );
  late final LibraryDisplayController _libraryDisplay =
      widget.libraryDisplay ?? LibraryDisplayController();
  late final AppPaneWidthController _paneWidth =
      widget.paneWidth ?? AppPaneWidthController(storageKey: _paneWidthKey);

  /// Persisted master-detail divider position (see [AppPaneWidthController]).
  static const String _paneWidthKey = 'anoworld.master_pane_width.v1';
  late final CreateAssistantController _createAssistant =
      widget.createAssistant ?? CreateAssistantController();
  final ProjectChangeNotifier _projectChanges = ProjectChangeNotifier();

  /// One repository instance for the whole app: the picture jobs keep the same
  /// object the pages write through, so a job's save is never split across
  /// two repositories.
  late final ProjectRepository _projects =
      widget.projects ?? FolderProjectRepository();
  late final VisualImageJobController _visualJobs = VisualImageJobController(
    projects: _projects,
    changes: _projectChanges,
  );
  final GlobalKey<CreateAssistantOverlayScopeState> _assistantOverlayKey =
      GlobalKey<CreateAssistantOverlayScopeState>();
  late final CreateAssistantNavigatorObserver _assistantObserver =
      CreateAssistantNavigatorObserver(
    _createAssistant,
    onStackChanged: () {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _assistantOverlayKey.currentState?.bringToFront();
      });
    },
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.settingsController == null) {
      unawaited(VariablesService.instance.initialize());
      _settings.load();
    }
    if (widget.libraryDisplay == null) {
      _libraryDisplay.load();
    }
    if (widget.paneWidth == null) {
      _paneWidth.load();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.settingsController == null) {
      _settings.dispose();
    }
    if (widget.libraryDisplay == null) {
      _libraryDisplay.dispose();
    }
    if (widget.paneWidth == null) {
      _paneWidth.dispose();
    }
    if (widget.createAssistant == null) {
      _createAssistant.dispose();
    }
    _visualJobs.dispose();
    _projectChanges.dispose();
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    _settings.syncPlatformBrightness(
      WidgetsBinding.instance.platformDispatcher.platformBrightness,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      projects: _projects,
      saves: widget.saves ?? FileSaveRepository(),
      folders: widget.folders ?? FileProjectFolderRepository(),
      settings: _settings,
      libraryDisplay: _libraryDisplay,
      paneWidth: _paneWidth,
      createAssistant: _createAssistant,
      projectChanges: _projectChanges,
      visualJobs: _visualJobs,
      textClient: widget.textClient,
      child: ListenableBuilder(
        listenable: _settings,
        builder: (context, _) {
          final appearance = _settings.appearance;
          return MaterialApp(
            title: 'AnoWorld',
            debugShowCheckedModeBanner: false,
            localizationsDelegates: AppStringsSetup.delegates,
            supportedLocales: AppStringsSetup.supportedLocales,
            localeResolutionCallback: AppStringsSetup.resolveLocale,
            theme: AppTheme.light(appearance),
            darkTheme: AppTheme.dark(appearance),
            themeMode: appearance.mode.material,
            navigatorObservers: [_assistantObserver],
            builder: (context, child) {
              Widget framed =
                  ImmersiveFrame(child: child ?? const SizedBox.shrink());
              // Windows Flutter AX bridge can desync on list/overlay updates
              // (flutter/flutter#182444) and spam / crash. Empty semantics is a
              // backstop if WM_GETOBJECT still reaches the engine somehow.
              if (defaultTargetPlatform == TargetPlatform.windows) {
                framed = ExcludeSemantics(child: framed);
              }
              return framed;
            },
            home: CreateAssistantOverlayScope(
              key: _assistantOverlayKey,
              controller: _createAssistant,
              child: HomePage(
                pickImportDirectory: widget.pickImportDirectory,
                pickImportPackage: widget.pickImportPackage,
              ),
            ),
          );
        },
      ),
    );
  }
}
