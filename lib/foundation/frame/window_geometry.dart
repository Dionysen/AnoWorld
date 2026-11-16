import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

/// Outer desktop window frame in the host's screen coordinates.
final class WindowGeometry {
  const WindowGeometry({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.maximized = false,
  });

  final double x;
  final double y;
  final double width;
  final double height;
  final bool maximized;

  bool get isPlausible {
    final min = AppTheme.windowMinSize;
    return width >= min.width &&
        height >= min.height &&
        width.isFinite &&
        height.isFinite &&
        x.isFinite &&
        y.isFinite;
  }

  Map<String, Object> toMap() => <String, Object>{
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'maximized': maximized,
  };

  static WindowGeometry? tryParse(Map<Object?, Object?>? raw) {
    if (raw == null) {
      return null;
    }
    final x = (raw['x'] as num?)?.toDouble();
    final y = (raw['y'] as num?)?.toDouble();
    final width = (raw['width'] as num?)?.toDouble();
    final height = (raw['height'] as num?)?.toDouble();
    if (x == null || y == null || width == null || height == null) {
      return null;
    }
    final geometry = WindowGeometry(
      x: x,
      y: y,
      width: width,
      height: height,
      maximized: raw['maximized'] == true,
    );
    return geometry.isPlausible ? geometry : null;
  }
}

/// Persists the last desktop window frame across launches.
abstract class WindowGeometryStore {
  Future<WindowGeometry?> load();

  Future<void> save(WindowGeometry geometry);
}

/// [SharedPreferences]-backed store. Safe to use from foundation.
final class PrefsWindowGeometryStore implements WindowGeometryStore {
  PrefsWindowGeometryStore({this._preferences});

  static const _x = 'window.geometry.x';
  static const _y = 'window.geometry.y';
  static const _width = 'window.geometry.width';
  static const _height = 'window.geometry.height';
  static const _maximized = 'window.geometry.maximized';

  SharedPreferences? _preferences;

  Future<SharedPreferences> _prefs() async {
    final existing = _preferences;
    if (existing != null) {
      return existing;
    }
    final prefs = await SharedPreferences.getInstance();
    _preferences = prefs;
    return prefs;
  }

  @override
  Future<WindowGeometry?> load() async {
    final prefs = await _prefs();
    if (!prefs.containsKey(_width) || !prefs.containsKey(_height)) {
      return null;
    }
    return WindowGeometry.tryParse(<String, Object?>{
      'x': prefs.getDouble(_x) ?? 0,
      'y': prefs.getDouble(_y) ?? 0,
      'width': prefs.getDouble(_width),
      'height': prefs.getDouble(_height),
      'maximized': prefs.getBool(_maximized) ?? false,
    });
  }

  @override
  Future<void> save(WindowGeometry geometry) async {
    if (!geometry.isPlausible) {
      return;
    }
    final prefs = await _prefs();
    await prefs.setDouble(_x, geometry.x);
    await prefs.setDouble(_y, geometry.y);
    await prefs.setDouble(_width, geometry.width);
    await prefs.setDouble(_height, geometry.height);
    await prefs.setBool(_maximized, geometry.maximized);
  }
}
