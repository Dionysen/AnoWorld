import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Works-library layout (aligned with NativeTavern character browse).
enum LibraryViewMode {
  /// Avatar + title + subtitle.
  list,

  /// Compact name row.
  simpleList,

  /// Cover grid (wider tiles).
  grid,

  /// Denser cover grid.
  compactGrid,
}

/// Avatar geometry for the full list layout.
enum LibraryAvatarShape {
  circle,
  square,
  rectangle,
}

extension LibraryViewModeX on LibraryViewMode {
  LibraryViewMode get next => switch (this) {
        LibraryViewMode.list => LibraryViewMode.simpleList,
        LibraryViewMode.simpleList => LibraryViewMode.grid,
        LibraryViewMode.grid => LibraryViewMode.compactGrid,
        LibraryViewMode.compactGrid => LibraryViewMode.list,
      };

  IconData get icon => switch (this) {
        LibraryViewMode.list => Icons.view_agenda_outlined,
        LibraryViewMode.simpleList => Icons.view_list_outlined,
        LibraryViewMode.grid => Icons.grid_view,
        LibraryViewMode.compactGrid => Icons.view_compact,
      };
}

extension LibraryAvatarShapeX on LibraryAvatarShape {
  LibraryAvatarShape get next => switch (this) {
        LibraryAvatarShape.circle => LibraryAvatarShape.square,
        LibraryAvatarShape.square => LibraryAvatarShape.rectangle,
        LibraryAvatarShape.rectangle => LibraryAvatarShape.circle,
      };

  IconData get icon => switch (this) {
        LibraryAvatarShape.circle => Icons.circle_outlined,
        LibraryAvatarShape.square => Icons.square_outlined,
        LibraryAvatarShape.rectangle => Icons.crop_portrait_outlined,
      };
}

class LibraryDisplayPrefs {
  const LibraryDisplayPrefs({
    this.viewMode = LibraryViewMode.list,
    this.avatarShape = LibraryAvatarShape.circle,
  });

  final LibraryViewMode viewMode;
  final LibraryAvatarShape avatarShape;

  LibraryDisplayPrefs copyWith({
    LibraryViewMode? viewMode,
    LibraryAvatarShape? avatarShape,
  }) {
    return LibraryDisplayPrefs(
      viewMode: viewMode ?? this.viewMode,
      avatarShape: avatarShape ?? this.avatarShape,
    );
  }
}

/// Persists works-library display prefs (SharedPreferences).
class LibraryDisplayController extends ChangeNotifier {
  LibraryDisplayController({SharedPreferences? this.preferences});

  static const viewModeKey = 'anoworld.library.view_mode.v1';
  static const avatarShapeKey = 'anoworld.library.avatar_shape.v1';

  SharedPreferences? preferences;
  LibraryDisplayPrefs prefs = const LibraryDisplayPrefs();
  bool loaded = false;

  Future<SharedPreferences> _prefs() async {
    return preferences ??= await SharedPreferences.getInstance();
  }

  Future<void> load() async {
    final store = await _prefs();
    final viewRaw = store.getString(viewModeKey);
    final shapeRaw = store.getString(avatarShapeKey);
    this.prefs = LibraryDisplayPrefs(
      viewMode: LibraryViewMode.values.asNameMap()[viewRaw] ??
          LibraryViewMode.list,
      avatarShape: LibraryAvatarShape.values.asNameMap()[shapeRaw] ??
          LibraryAvatarShape.circle,
    );
    loaded = true;
    notifyListeners();
  }

  Future<void> setViewMode(LibraryViewMode viewMode) async {
    if (prefs.viewMode == viewMode) return;
    prefs = prefs.copyWith(viewMode: viewMode);
    notifyListeners();
    await (await _prefs()).setString(viewModeKey, viewMode.name);
  }

  Future<void> setAvatarShape(LibraryAvatarShape avatarShape) async {
    if (prefs.avatarShape == avatarShape) return;
    prefs = prefs.copyWith(avatarShape: avatarShape);
    notifyListeners();
    await (await _prefs()).setString(avatarShapeKey, avatarShape.name);
  }
}
