import 'package:anoworld/domain/repositories/project_repository.dart';
import 'package:flutter/widgets.dart';

/// App-wide services. Business pages read repositories from here.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.projects,
    required super.child,
  });

  final ProjectRepository projects;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in context');
    return scope!;
  }

  static ProjectRepository projectsOf(BuildContext context) =>
      of(context).projects;

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      projects != oldWidget.projects;
}
