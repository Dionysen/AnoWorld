import 'package:anoworld/foundation/layout/app_layout.dart';
import 'package:anoworld/foundation/layout/app_pane_width.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('defaults to the shared master width and notifies on change', () {
    final controller = AppPaneWidthController();
    var notified = 0;
    controller.addListener(() => notified++);

    expect(controller.masterPaneWidth, AppLayout.masterPaneDefaultWidth);

    controller.setMasterPaneWidth(420);
    controller.setMasterPaneWidth(420);

    expect(controller.masterPaneWidth, 420);
    // Repeating the same width must not spam listeners during a drag.
    expect(notified, 1);
  });

  test('persists the width and restores it on load', () async {
    final first = AppPaneWidthController(storageKey: 'test.pane_width');
    first.setMasterPaneWidth(455);
    await first.persist();

    final second = AppPaneWidthController(storageKey: 'test.pane_width');
    await second.load();

    expect(second.masterPaneWidth, 455);
  });

  test('without a storage key nothing is written', () async {
    final controller = AppPaneWidthController();
    controller.setMasterPaneWidth(300);
    await controller.persist();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), isEmpty);
  });

  test('ignores a corrupt persisted width', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'test.pane_width': -1.0,
    });
    final controller = AppPaneWidthController(storageKey: 'test.pane_width');

    await controller.load();

    expect(controller.masterPaneWidth, AppLayout.masterPaneDefaultWidth);
  });
}
