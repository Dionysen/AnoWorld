import 'package:anoworld/foundation/history/undo_stack.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('undo and redo restore snapshots', () {
    var value = 'a';
    final stack = UndoStack();

    void apply(String next) => value = next;

    void commit(String next) {
      final before = value;
      apply(next);
      stack.addSwap(before: before, after: next, apply: apply);
    }

    commit('b');
    commit('c');
    expect(value, 'c');
    expect(stack.canUndo, isTrue);
    expect(stack.canRedo, isFalse);

    stack.undo();
    expect(value, 'b');
    expect(stack.canRedo, isTrue);

    stack.undo();
    expect(value, 'a');
    expect(stack.canUndo, isFalse);

    stack.redo();
    expect(value, 'b');
    stack.redo();
    expect(value, 'c');
  });

  test('new edit clears redo', () {
    var value = 0;
    final stack = UndoStack();
    void apply(int next) => value = next;
    void commit(int next) {
      final before = value;
      apply(next);
      stack.addSwap(before: before, after: next, apply: apply);
    }

    commit(1);
    commit(2);
    stack.undo();
    expect(value, 1);
    commit(9);
    expect(stack.canRedo, isFalse);
    stack.undo();
    expect(value, 1);
  });

  test('add during replay is ignored', () {
    var value = 'x';
    final stack = UndoStack();
    void apply(String next) {
      final before = value;
      value = next;
      // Mistaken re-entrant record — must not corrupt stacks.
      stack.addSwap(before: before, after: next, apply: (v) => value = v);
    }

    stack.addSwap(before: 'x', after: 'y', apply: apply);
    value = 'y';
    stack.undo();
    expect(value, 'x');
    expect(stack.undoDepth, 0);
    expect(stack.redoDepth, 1);
  });
}
