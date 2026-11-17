import 'package:anoworld/home/library_display_prefs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('persists view mode and avatar shape', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final controller = LibraryDisplayController(
      preferences: await SharedPreferences.getInstance(),
    );
    await controller.load();
    expect(controller.prefs.viewMode, LibraryViewMode.list);
    expect(controller.prefs.avatarShape, LibraryAvatarShape.circle);

    await controller.setViewMode(LibraryViewMode.compactGrid);
    await controller.setAvatarShape(LibraryAvatarShape.rectangle);

    final again = LibraryDisplayController(
      preferences: await SharedPreferences.getInstance(),
    );
    await again.load();
    expect(again.prefs.viewMode, LibraryViewMode.compactGrid);
    expect(again.prefs.avatarShape, LibraryAvatarShape.rectangle);
  });
}
