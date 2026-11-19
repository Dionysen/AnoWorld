import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/home/library_display_prefs.dart';

/// Localized names for library layout options (shown in pickers, not stored).
String libraryViewModeLabel(AppStrings strings, LibraryViewMode mode) {
  return switch (mode) {
    LibraryViewMode.list => strings.viewModeDetailedList,
    LibraryViewMode.simpleList => strings.viewModeSimpleList,
    LibraryViewMode.grid => strings.viewModeGrid,
    LibraryViewMode.compactGrid => strings.viewModeCompactGrid,
  };
}

/// Localized names for avatar shapes.
String libraryAvatarShapeLabel(AppStrings strings, LibraryAvatarShape shape) {
  return switch (shape) {
    LibraryAvatarShape.circle => strings.avatarCircle,
    LibraryAvatarShape.square => strings.avatarSquare,
    LibraryAvatarShape.rectangle => strings.avatarRectangle,
  };
}
