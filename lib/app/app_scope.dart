import 'package:anoworld/app/settings_controller.dart';
import 'package:anoworld/domain/repositories/project_repository.dart';
import 'package:anoworld/domain/repositories/save_repository.dart';
import 'package:flutter/widgets.dart';

/// App-wide services. Business pages read repositories from here.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.projects,
    required this.saves,
    required this.settings,
    required super.child,
  });

  final ProjectRepository projects;
  final SaveRepository saves;
  final SettingsController settings;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in context');
    return scope!;
  }

  static ProjectRepository projectsOf(BuildContext context) =>
      of(context).projects;

  static SaveRepository savesOf(BuildContext context) => of(context).saves;

  static SettingsController settingsOf(BuildContext context) =>
      of(context).settings;

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      projects != oldWidget.projects ||
      saves != oldWidget.saves ||
      settings != oldWidget.settings;
}
