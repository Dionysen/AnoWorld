import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'app_scope.dart';
import 'project_change_notifier.dart';

/// Reloads a story page after another writer saved the package.
///
/// Every listener tracks its own [ProjectChangeNotifier.revisionOf] value, so
/// one write refreshes all open pages of that story (story detail under the
/// graph, graph, cast / world-book editors, plot-element picker) instead of
/// only the first page that happens to read a flag.
mixin ProjectChangeWatcher<T extends StatefulWidget> on State<T> {
  ProjectChangeNotifier? _changes;
  int _seenRevision = 0;

  /// Story shown by this page.
  String get watchedProjectId;

  /// Pull the saved package again.
  void reloadAfterExternalWrite();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final changes = AppScope.projectChangesOf(context);
    if (identical(_changes, changes)) return;
    _changes?.removeListener(_onExternalWrite);
    _changes = changes..addListener(_onExternalWrite);
    // A write that landed before this page mounted is already in the store.
    _seenRevision = changes.revisionOf(watchedProjectId);
  }

  @override
  void dispose() {
    _changes?.removeListener(_onExternalWrite);
    super.dispose();
  }

  void _onExternalWrite() {
    final changes = _changes;
    if (changes == null) return;
    final revision = changes.revisionOf(watchedProjectId);
    if (revision == _seenRevision) return;
    _seenRevision = revision;
    _runWhenIdle(() {
      if (mounted) reloadAfterExternalWrite();
    });
  }

  /// Runs [action] outside build / layout, without waiting for a frame the app
  /// may never draw (the writer can finish while the UI sits still).
  void _runWhenIdle(VoidCallback action) {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      scheduleMicrotask(action);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => action());
  }
}
