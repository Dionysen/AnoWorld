import 'dart:io';

import 'package:anoworld/app.dart';
import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/app/settings_controller.dart';
import 'package:anoworld/data/folder/memory_project_folder_repository.dart';
import 'package:anoworld/data/project/memory_project_repository.dart';
import 'package:anoworld/data/save/memory_save_repository.dart';
import 'package:anoworld/data/settings/memory_settings_repository.dart';
import 'package:anoworld/domain/ai/ai_text_client.dart';
import 'package:anoworld/domain/repositories/project_folder_repository.dart';
import 'package:anoworld/domain/repositories/project_repository.dart';
import 'package:anoworld/domain/repositories/save_repository.dart';
import 'package:anoworld/domain/settings/appearance_settings.dart';
import 'package:anoworld/foundation/fonts/file_system_font_repository.dart';
import 'package:anoworld/foundation/fonts/system_font.dart';
import 'package:anoworld/foundation/fonts/system_font_catalog.dart';
import 'package:anoworld/foundation/frame/immersive_frame.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/home/library_display_prefs.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

Future<LibraryDisplayController> testLibraryDisplay({
  LibraryDisplayPrefs? prefs,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final controller = LibraryDisplayController(
    preferences: await SharedPreferences.getInstance(),
  );
  await controller.load();
  if (prefs != null) {
    await controller.setViewMode(prefs.viewMode);
    await controller.setAvatarShape(prefs.avatarShape);
  }
  return controller;
}

App testApp({
  ProjectRepository? projects,
  SaveRepository? saves,
  ProjectFolderRepository? folders,
  SettingsController? settings,
  LibraryDisplayController? libraryDisplay,
  AiTextClient? textClient,
  Future<String?> Function()? pickImportDirectory,
}) {
  final controller = settings ?? testSettingsController();
  return App(
    projects: projects ?? MemoryProjectRepository(),
    saves: saves ?? MemorySaveRepository(),
    folders: folders ?? MemoryProjectFolderRepository(),
    settingsController: controller,
    libraryDisplay: libraryDisplay ?? LibraryDisplayController(),
    textClient: textClient,
    pickImportDirectory: pickImportDirectory,
  );
}

Widget testScoped({
  required Widget home,
  ProjectRepository? projects,
  SaveRepository? saves,
  ProjectFolderRepository? folders,
  SettingsController? settings,
  LibraryDisplayController? libraryDisplay,
  AiTextClient? textClient,
}) {
  final controller = settings ?? testSettingsController();
  return AppScope(
    projects: projects ?? MemoryProjectRepository(),
    saves: saves ?? MemorySaveRepository(),
    folders: folders ?? MemoryProjectFolderRepository(),
    settings: controller,
    libraryDisplay: libraryDisplay ?? LibraryDisplayController(),
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
