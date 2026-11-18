import 'package:flutter/foundation.dart';

/// Multi-select state for flat lists (editors, settings pickers).
class AppListSelectionController extends ChangeNotifier {
  bool _active = false;
  final Set<String> _ids = <String>{};

  bool get active => _active;
  bool get hasSelection => _ids.isNotEmpty;
  int get count => _ids.length;
  Set<String> get ids => Set<String>.unmodifiable(_ids);

  bool isSelected(String id) => _ids.contains(id);

  void enter({String? id}) {
    _active = true;
    _ids.clear();
    if (id != null) _ids.add(id);
    notifyListeners();
  }

  void exit() {
    if (!_active && _ids.isEmpty) return;
    _active = false;
    _ids.clear();
    notifyListeners();
  }

  void toggle(String id) {
    if (!_active) {
      enter(id: id);
      return;
    }
    if (!_ids.add(id)) _ids.remove(id);
    notifyListeners();
  }

  void toggleAll(Iterable<String> allIds) {
    final all = allIds.toList(growable: false);
    if (_ids.length == all.length && all.every(_ids.contains)) {
      _ids.clear();
    } else {
      _ids
        ..clear()
        ..addAll(all);
    }
    _active = true;
    notifyListeners();
  }
}