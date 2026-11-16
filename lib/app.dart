import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/app/settings_controller.dart';
import 'package:anoworld/data/project/folder_project_repository.dart';
import 'package:anoworld/data/save/file_save_repository.dart';
import 'package:anoworld/data/settings/prefs_settings_repository.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/repositories/project_repository.dart';
import 'package:anoworld/domain/repositories/save_repository.dart';
import 'package:anoworld/domain/repositories/settings_repository.dart';
import 'package:anoworld/domain/settings/appearance_settings.dart';
import 'package:anoworld/foundation/frame/immersive_frame.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/home/home_page.dart';
import 'package:flutter/material.dart';

class App extends StatefulWidget {
  const App({
    super.key,
    this.projects,
    this.saves,
    this.settingsRepository,
    this.settingsController,
    this.textClient,
    this.pickImportDirectory,
  });

  final ProjectRepository? projects;
  final SaveRepository? saves;
  final SettingsRepository? settingsRepository;
  final SettingsController? settingsController;
  final AiTextClient? textClient;
  final Future<String?> Function()? pickImportDirectory;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  late final SettingsController _settings = widget.settingsController ??
      SettingsController(
        repository: widget.settingsRepository ?? PrefsSettingsRepository(),
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.settingsController == null) {
      _settings.load();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.settingsController == null) {
      _settings.dispose();
    }
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
      projects: widget.projects ?? FolderProjectRepository(),
      saves: widget.saves ?? FileSaveRepository(),
      settings: _settings,
      textClient: widget.textClient,
      child: ListenableBuilder(
        listenable: _settings,
        builder: (context, _) {
          final appearance = _settings.appearance;
          return MaterialApp(
            title: 'AnoWorld',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(appearance),
            darkTheme: AppTheme.dark(appearance),
            themeMode: appearance.mode.material,
            builder: (context, child) {
              return ImmersiveFrame(child: child ?? const SizedBox.shrink());
            },
            home: HomePage(pickImportDirectory: widget.pickImportDirectory),
          );
        },
      ),
    );
  }
}
