import 'package:anoworld/foundation/frame/window_geometry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('rejects frames smaller than the chrome floor', () {
    expect(
      WindowGeometry.tryParse(<String, Object?>{
        'x': 10,
        'y': 10,
        'width': 40,
        'height': 40,
        'maximized': false,
      }),
      isNull,
    );
  });

  test('prefs store round-trips a plausible frame', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = PrefsWindowGeometryStore(
      preferences: await SharedPreferences.getInstance(),
    );
    const geometry = WindowGeometry(
      x: 120,
      y: 80,
      width: 960,
      height: 640,
      maximized: true,
    );

    await store.save(geometry);
    final loaded = await store.load();

    expect(loaded, isNotNull);
    expect(loaded!.x, 120);
    expect(loaded.y, 80);
    expect(loaded.width, 960);
    expect(loaded.height, 640);
    expect(loaded.maximized, isTrue);
  });
}
