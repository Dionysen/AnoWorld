import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/data/project/folder_project_repository.dart';
import 'package:anoworld/data/save/file_save_repository.dart';
import 'package:anoworld/domain/repositories/project_repository.dart';
import 'package:anoworld/domain/repositories/save_repository.dart';
import 'package:anoworld/foundation/frame/immersive_frame.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/home/home_page.dart';
import 'package:flutter/material.dart';

class App extends StatelessWidget {
  const App({
    super.key,
    this.projects,
    this.saves,
    this.pickImportDirectory,
  });

  /// Override for tests. Production uses [FolderProjectRepository].
  final ProjectRepository? projects;

  /// Override for tests. Production uses [FileSaveRepository].
  final SaveRepository? saves;

  /// Override folder picker for tests.
  final Future<String?> Function()? pickImportDirectory;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      projects: projects ?? FolderProjectRepository(),
      saves: saves ?? FileSaveRepository(),
      child: MaterialApp(
        title: 'AnoWorld',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.data,
        builder: (context, child) {
          return ImmersiveFrame(child: child ?? const SizedBox.shrink());
        },
        home: HomePage(pickImportDirectory: pickImportDirectory),
      ),
    );
  }
}
