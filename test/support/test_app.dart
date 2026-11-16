import 'dart:io';

import 'package:anoworld/app.dart';
import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/app/settings_controller.dart';
import 'package:anoworld/data/project/memory_project_repository.dart';
import 'package:anoworld/data/save/memory_save_repository.dart';
import 'package:anoworld/data/settings/memory_settings_repository.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/repositories/project_repository.dart';
import 'package:anoworld/domain/repositories/save_repository.dart';
import 'package:anoworld/domain/settings/appearance_settings.dart';
import 'package:anoworld/foundation/fonts/file_system_font_repository.dart';
import 'package:anoworld/foundation/fonts/system_font.dart';
import 'package:anoworld/foundation/fonts/system_font_catalog.dart';
import 'package:anoworld/foundation/frame/immersive_frame.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:flutter/material.dart';

SettingsController testSettingsController() {
  return SettingsController(
    repository: MemorySettingsRepository(),
    fonts: FileSystemFontRepository(
      catalog: _EmptyFontCatalog(),
      directories: const <Directory>[],
      importedFontsDirectory: () async =>
          Directory.systemTemp.createTempSync('aw_test_fonts'),
    ),
  );
}

class _EmptyFontCatalog extends SystemFontCatalog {
  @override
  Future<List<SystemFont>> listFonts() async => const [];
}

App testApp({
  ProjectRepository? projects,
  SaveRepository? saves,
  SettingsController? settings,
  AiTextClient? textClient,
  Future<String?> Function()? pickImportDirectory,
}) {
  final controller = settings ?? testSettingsController();
  return App(
    projects: projects ?? MemoryProjectRepository(),
    saves: saves ?? MemorySaveRepository(),
    settingsController: controller,
    textClient: textClient,
    pickImportDirectory: pickImportDirectory,
  );
}

Widget testScoped({
  required Widget home,
  ProjectRepository? projects,
  SaveRepository? saves,
  SettingsController? settings,
  AiTextClient? textClient,
}) {
  final controller = settings ?? testSettingsController();
  return AppScope(
    projects: projects ?? MemoryProjectRepository(),
    saves: saves ?? MemorySaveRepository(),
    settings: controller,
    textClient: textClient,
    child: ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final appearance = controller.appearance;
        return MaterialApp(
          theme: AppTheme.light(appearance),
          darkTheme: AppTheme.dark(appearance),
          themeMode: appearance.mode.material,
          builder: (context, child) =>
              ImmersiveFrame(child: child ?? const SizedBox.shrink()),
          home: home,
        );
      },
    ),
  );
}
