import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logging/app_log.dart';
import 'app_layout.dart';

/// Remembers the master pane width so every master-detail hub keeps the same
/// divider position — across tab switches and, when [storageKey] is set, across
/// restarts.
///
/// Storage failures are logged, never thrown: a divider position is a display
/// preference and must not break a page that is otherwise fine.
class AppPaneWidthController extends ChangeNotifier {
  AppPaneWidthController({
    this.preferences,
    this.storageKey,
    double initialWidth = AppLayout.masterPaneDefaultWidth,
  }) : _masterPaneWidth = initialWidth;

  SharedPreferences? preferences;

  /// When null the width only lives in memory.
  final String? storageKey;

  double _masterPaneWidth;

  double get masterPaneWidth => _masterPaneWidth;

  /// Live update while dragging; persist separately so a drag does not write
  /// prefs on every frame.
  void setMasterPaneWidth(double width) {
    if (width == _masterPaneWidth) return;
    _masterPaneWidth = width;
    notifyListeners();
  }

  Future<void> load() async {
    final key = storageKey;
    if (key == null) return;
    try {
      final store = preferences ??= await SharedPreferences.getInstance();
      final saved = store.getDouble(key);
      if (saved == null || saved <= 0 || saved == _masterPaneWidth) return;
      _masterPaneWidth = saved;
      notifyListeners();
    } catch (error) {
      AppLog.instance.warning(
        '读取分栏宽度失败，沿用默认值：$error',
        tag: 'layout.pane',
      );
    }
  }

  Future<void> persist() async {
    final key = storageKey;
    if (key == null) return;
    try {
      final store = preferences ??= await SharedPreferences.getInstance();
      await store.setDouble(key, _masterPaneWidth);
    } catch (error) {
      AppLog.instance.warning(
        '保存分栏宽度失败：$error',
        tag: 'layout.pane',
      );
    }
  }
}
