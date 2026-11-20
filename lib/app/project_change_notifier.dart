import 'package:flutter/foundation.dart';

/// Tells open pages that a story package was written elsewhere (for example by
/// the create assistant). Pages holding a copy reload instead of showing stale
/// nodes / counts.
///
/// Each project carries a revision counter, so every open page of the same
/// story can react to one write. A single flag would be consumed by whichever
/// page listened first (story detail under the graph), leaving the rest stale.
class ProjectChangeNotifier extends ChangeNotifier {
  final Map<String, int> _revisions = <String, int>{};

  void markChanged(String projectId) {
    _revisions[projectId] = revisionOf(projectId) + 1;
    notifyListeners();
  }

  /// Bumped on every write; pages remember the value they last loaded.
  int revisionOf(String projectId) => _revisions[projectId] ?? 0;
}
