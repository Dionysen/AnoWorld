import 'package:flutter/foundation.dart';

/// One reversible step. Callers apply the forward change first, then [UndoStack.add].
abstract class UndoEntry {
  void undo();
  void redo();
}

/// Swaps between two immutable [T] snapshots via [apply].
class StateSwapEntry<T> implements UndoEntry {
  StateSwapEntry({
    required this.before,
    required this.after,
    required this.apply,
  });

  final T before;
  final T after;
  final ValueChanged<T> apply;

  @override
  void undo() => apply(before);

  @override
  void redo() => apply(after);
}

/// Generic undo/redo stack. Domain-agnostic; push [UndoEntry] implementations
/// (e.g. [StateSwapEntry]) from feature code.
class UndoStack extends ChangeNotifier {
  UndoStack({this.capacity = 80});

  final int capacity;
  final List<UndoEntry> _undo = [];
  final List<UndoEntry> _redo = [];
  bool _replaying = false;

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  bool get isReplaying => _replaying;
  int get undoDepth => _undo.length;
  int get redoDepth => _redo.length;

  /// Records a completed forward change. Cleared when [capacity] is exceeded.
  /// No-ops while an undo/redo is applying (so [apply] callbacks stay quiet).
  void add(UndoEntry entry) {
    if (_replaying) return;
    _undo.add(entry);
    if (_undo.length > capacity) {
      _undo.removeAt(0);
    }
    _redo.clear();
    notifyListeners();
  }

  /// Convenience for snapshot editors: record [before]→[after] with [apply].
  void addSwap<T>({
    required T before,
    required T after,
    required ValueChanged<T> apply,
  }) {
    add(StateSwapEntry<T>(before: before, after: after, apply: apply));
  }

  void undo() {
    if (!canUndo) return;
    final entry = _undo.removeLast();
    _replaying = true;
    try {
      entry.undo();
      _redo.add(entry);
    } finally {
      _replaying = false;
    }
    notifyListeners();
  }

  void redo() {
    if (!canRedo) return;
    final entry = _redo.removeLast();
    _replaying = true;
    try {
      entry.redo();
      _undo.add(entry);
    } finally {
      _replaying = false;
    }
    notifyListeners();
  }

  void clear() {
    if (_undo.isEmpty && _redo.isEmpty) return;
    _undo.clear();
    _redo.clear();
    notifyListeners();
  }
}
