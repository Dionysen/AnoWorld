import 'package:anoworld/app/project_change_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('marks a story as changed and clears it after reload', () {
    final notifier = ProjectChangeNotifier();
    addTearDown(notifier.dispose);

    var notifications = 0;
    notifier.addListener(() => notifications++);

    expect(notifier.isChanged('p1'), isFalse);

    notifier.markChanged('p1');
    expect(notifications, 1);
    expect(notifier.isChanged('p1'), isTrue);
    expect(notifier.isChanged('p2'), isFalse);

    notifier.clear('p1');
    expect(notifier.isChanged('p1'), isFalse);
    expect(notifications, 1);
  });
}
