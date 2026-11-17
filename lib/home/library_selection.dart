import 'package:flutter/foundation.dart';

/// Multi-select state for library lists (saves / works).
class LibrarySelectionController extends ChangeNotifier {
  bool _selectionMode = false;
  final Set<String> _ids = <String>{};

  bool get selectionMode => _selectionMode;
  bool get hasSelection => _ids.isNotEmpty;
  int get selectedCount => _ids.length;
  Set<String> get selectedIds => Set<String>.unmodifiable(_ids);

  bool isSelected(String id) => _ids.contains(id);

  void enter(String? id) {
    _selectionMode = true;
    _ids.clear();
    if (id != null) _ids.add(id);
    notifyListeners();
  }

  void exit() {
    if (!_selectionMode && _ids.isEmpty) return;
    _selectionMode = false;
    _ids.clear();
    notifyListeners();
  }

  void toggle(String id) {
    if (!_selectionMode) {
      enter(id);
      return;
    }
    if (!_ids.add(id)) _ids.remove(id);
    notifyListeners();
  }

  void toggleSelectAll(Iterable<String> allIds) {
    final ids = allIds.toList(growable: false);
    if (_ids.length == ids.length && ids.every(_ids.contains)) {
      _ids.clear();
    } else {
      _ids
        ..clear()
        ..addAll(ids);
    }
    _selectionMode = true;
    notifyListeners();
  }
}
