import 'package:anoworld/domain/repositories/settings_repository.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/domain/settings/appearance_settings.dart';
import 'package:anoworld/foundation/fonts/file_system_font_repository.dart';
import 'package:anoworld/foundation/fonts/system_font.dart';
import 'package:flutter/foundation.dart';

/// Loads and persists AI + appearance settings; notifies [MaterialApp].
class SettingsController extends ChangeNotifier {
  SettingsController({
    required this.repository,
    FileSystemFontRepository? fonts,
  }) : _fonts = fonts ?? FileSystemFontRepository();

  final SettingsRepository repository;
  final FileSystemFontRepository _fonts;

  AiSettings ai = const AiSettings();
  AppearanceSettings appearance = const AppearanceSettings();
  List<SystemFont> fontCatalog = const [];
  bool fontsLoading = false;
  bool fontsLoaded = false;
  bool loaded = false;

  Future<void> load() async {
    ai = await repository.loadAi();
    appearance = await repository.loadAppearance();
    loaded = true;
    notifyListeners();
    await _restoreSavedFont();
  }

  Future<void> updateAi(AiSettings next) async {
    ai = next;
    notifyListeners();
    await repository.saveAi(next);
  }

  Future<void> updateAppearance(AppearanceSettings next) async {
    appearance = next;
    notifyListeners();
    await repository.saveAppearance(next);
  }

  Future<void> ensureFontsLoaded({bool force = false}) async {
    if (fontsLoading) return;
    if (fontsLoaded && !force) return;
    fontsLoading = true;
    notifyListeners();
    try {
      fontCatalog = await _fonts.listFonts();
      fontsLoaded = true;
    } on Object {
      fontsLoaded = true;
    } finally {
      fontsLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectFont(SystemFont? font) async {
    if (font == null) {
      await updateAppearance(appearance.copyWith(clearFont: true));
      return;
    }
    final family = await _fonts.loadFont(font);
    if (family == null) return;
    await updateAppearance(
      appearance.copyWith(fontFamily: family, fontPath: font.path),
    );
  }

  Future<bool> importFontFromPath(String sourcePath) async {
    final imported = await _fonts.importFont(sourcePath);
    if (imported == null) return false;
    try {
      fontCatalog = await _fonts.listFonts();
      fontsLoaded = true;
    } on Object {
      if (!fontCatalog.any((f) => f.path == imported.path)) {
        fontCatalog = [...fontCatalog, imported];
        fontsLoaded = true;
      }
    }
    notifyListeners();
    await selectFont(imported);
    return appearance.fontPath == imported.path;
  }

  Future<bool> deleteImportedFont(SystemFont font) async {
    final ok = await _fonts.deleteImportedFont(font);
    if (!ok) return false;
    try {
      fontCatalog = await _fonts.listFonts();
      fontsLoaded = true;
    } on Object {
      fontCatalog = fontCatalog.where((f) => f.path != font.path).toList();
    }
    if (appearance.fontPath == font.path) {
      await selectFont(null);
    } else {
      notifyListeners();
    }
    return true;
  }

  String selectedFontLabel({String systemLabel = '系统默认'}) {
    final path = appearance.fontPath;
    if (path == null || path.isEmpty) {
      final family = appearance.fontFamily;
      if (family != null && family.isNotEmpty) return family;
      return systemLabel;
    }
    for (final font in fontCatalog) {
      if (font.path == path) return font.family;
    }
    final parts = path.split(RegExp(r'[/\\]'));
    return parts.isEmpty ? path : parts.last;
  }

  Future<void> _restoreSavedFont() async {
    final path = appearance.fontPath;
    if (path == null || path.isEmpty) return;
    if (await _fonts.fontFileMissing(path)) {
      await updateAppearance(appearance.copyWith(clearFont: true));
      return;
    }
    final family =
        await _fonts.loadFont(SystemFont(family: '', path: path));
    if (family != null) {
      await updateAppearance(appearance.copyWith(fontFamily: family));
    }
  }
}
