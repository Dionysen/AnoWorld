import 'package:anoworld/app/project_change_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bumps one revision per write, per story', () {
    final notifier = ProjectChangeNotifier();
    addTearDown(notifier.dispose);

    var notifications = 0;
    notifier.addListener(() => notifications++);

    expect(notifier.revisionOf('p1'), 0);

    notifier.markChanged('p1');
    expect(notifications, 1);
    expect(notifier.revisionOf('p1'), 1);
    expect(notifier.revisionOf('p2'), 0);

    // A second write is a new revision, so a page that already reloaded once
    // still sees the next change.
    notifier.markChanged('p1');
    expect(notifier.revisionOf('p1'), 2);
    expect(notifications, 2);
  });

  test('two listeners both see the same revision', () {
    final notifier = ProjectChangeNotifier();
    addTearDown(notifier.dispose);

    final seen = <int>[];
    notifier
      ..addListener(() => seen.add(notifier.revisionOf('p1')))
      ..addListener(() => seen.add(notifier.revisionOf('p1')));

    notifier.markChanged('p1');
    // Reading does not consume anything: every open page can refresh.
    expect(seen, <int>[1, 1]);
  });
}
