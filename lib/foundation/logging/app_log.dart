import 'dart:collection';
import 'dart:developer' as developer;

import 'package:anoworld/foundation/logging/app_log_entry.dart';
import 'package:anoworld/foundation/logging/app_log_level.dart';
import 'package:flutter/foundation.dart';

/// In-memory ring buffer + console output for diagnostics (debug UI reads [entries]).
class AppLog extends ChangeNotifier {
  AppLog._();

  static final AppLog instance = AppLog._();

  static const int maxBufferedEntries = 2000;

  final ListQueue<AppLogEntry> _entries = ListQueue();
  int _nextId = 1;

  UnmodifiableListView<AppLogEntry> get entries =>
      UnmodifiableListView(_entries);

  int get length => _entries.length;

  AppLogEntry? entryAtNewestFirst(int index) {
    if (index < 0 || index >= _entries.length) return null;
    return _entries.elementAt(_entries.length - 1 - index);
  }

  void info(String message, {String tag = 'app'}) {
    _record(AppLogLevel.info, tag, message);
  }

  void warning(String message, {String tag = 'app'}) {
    _record(AppLogLevel.warning, tag, message);
  }

  void error(
    String message, {
    String tag = 'app',
    Object? error,
    StackTrace? stackTrace,
  }) {
    _record(
      AppLogLevel.error,
      tag,
      message,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void clear() {
    if (_entries.isEmpty) return;
    _entries.clear();
    notifyListeners();
  }

  void _record(
    AppLogLevel level,
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    final entry = AppLogEntry(
      id: _nextId++,
      time: DateTime.now(),
      level: level,
      tag: tag.trim().isEmpty ? 'app' : tag.trim(),
      message: message,
      error: error,
      stackTrace: stackTrace,
    );

    if (kDebugMode) {
      _pushBuffered(entry);
      notifyListeners();
    }

    _printToConsole(entry);
  }

  void _pushBuffered(AppLogEntry entry) {
    _entries.addLast(entry);
    while (_entries.length > maxBufferedEntries) {
      _entries.removeFirst();
    }
  }

  void _printToConsole(AppLogEntry entry) {
    final head = '${entry.level.name.toUpperCase()} '
        '[${entry.tag}] ${entry.message}';
    if (entry.level == AppLogLevel.error) {
      developer.log(
        head,
        name: entry.tag,
        error: entry.error,
        stackTrace: entry.stackTrace,
        level: 1000,
      );
      if (kDebugMode) {
        debugPrint(head);
        if (entry.error != null) debugPrint(entry.error.toString());
        if (entry.stackTrace != null) debugPrint(entry.stackTrace.toString());
      }
      return;
    }

    if (kDebugMode) {
      developer.log(head, name: entry.tag);
      debugPrint(head);
    }
  }
}