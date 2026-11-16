import 'package:anoworld/app.dart';
import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/app/settings_controller.dart';
import 'package:anoworld/data/project/memory_project_repository.dart';
import 'package:anoworld/data/save/memory_save_repository.dart';
import 'package:anoworld/data/settings/memory_settings_repository.dart';
import 'package:anoworld/domain/repositories/project_repository.dart';
import 'package:anoworld/domain/repositories/save_repository.dart';
import 'package:anoworld/domain/settings/appearance_settings.dart';
import 'package:anoworld/foundation/frame/immersive_frame.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:flutter/material.dart';

SettingsController testSettingsController() {
  return SettingsController(repository: MemorySettingsRepository());
}

App testApp({
  ProjectRepository? projects,
  SaveRepository? saves,
  SettingsController? settings,
  Future<String?> Function()? pickImportDirectory,
}) {
  final controller = settings ?? testSettingsController();
  return App(
    projects: projects ?? MemoryProjectRepository(),
    saves: saves ?? MemorySaveRepository(),
    settingsController: controller,
    pickImportDirectory: pickImportDirectory,
  );
}

Widget testScoped({
  required Widget home,
  ProjectRepository? projects,
  SaveRepository? saves,
  SettingsController? settings,
}) {
  final controller = settings ?? testSettingsController();
  return AppScope(
    projects: projects ?? MemoryProjectRepository(),
    saves: saves ?? MemorySaveRepository(),
    settings: controller,
    child: ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final appearance = controller.appearance;
        return MaterialApp(
          theme: AppTheme.light(appearance.preset),
          darkTheme: AppTheme.dark(appearance.preset),
          themeMode: appearance.mode.material,
          builder: (context, child) =>
              ImmersiveFrame(child: child ?? const SizedBox.shrink()),
          home: home,
        );
      },
    ),
  );
}
