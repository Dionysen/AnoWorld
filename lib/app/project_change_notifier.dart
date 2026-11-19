import 'package:flutter/foundation.dart';

/// Tells open pages that a story package was written elsewhere (for example by
/// the create assistant). Pages holding a copy reload instead of showing stale
/// nodes / counts.
class ProjectChangeNotifier extends ChangeNotifier {
  final Set<String> _changed = <String>{};

  void markChanged(String projectId) {
    _changed.add(projectId);
    notifyListeners();
  }

  bool isChanged(String projectId) => _changed.contains(projectId);

  void clear(String projectId) => _changed.remove(projectId);
}
