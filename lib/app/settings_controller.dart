import 'dart:math' as math;

import 'package:anoworld/domain/repositories/settings_repository.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/domain/settings/appearance_settings.dart';
import 'package:anoworld/foundation/fonts/file_system_font_repository.dart';
import 'package:anoworld/foundation/fonts/system_font.dart';
import 'package:anoworld/foundation/theme/theme_color_pack.dart';
import 'package:anoworld/foundation/theme/theme_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Loads and persists AI + appearance settings; notifies [MaterialApp].
class SettingsController extends ChangeNotifier {
  SettingsController({
    required this.repository,
    FileSystemFontRepository? fonts,
    Brightness? platformBrightness,
  })  : _fonts = fonts ?? FileSystemFontRepository(),
        platformBrightness = platformBrightness ??
            SchedulerBinding.instance.platformDispatcher.platformBrightness;

  final SettingsRepository repository;
  final FileSystemFontRepository _fonts;

  AiSettings ai = const AiSettings();
  AppearanceSettings appearance = AppearanceSettings();
  Brightness platformBrightness;
  List<SystemFont> fontCatalog = const [];
  bool fontsLoading = false;
  bool fontsLoaded = false;
  bool loaded = false;
  var _nextCustomSeq = 1;

  bool get isEffectivelyDark => appearance.isEffectivelyDark(platformBrightness);

  ThemeTokens get activeTokens => appearance.activeTokens(platformBrightness);

  String get activePackId => appearance.activePackId(platformBrightness);

  ThemeColorPack? get activePack => appearance.packById(activePackId);

  bool get isActivePackCustomized {
    final pack = activePack;
    return pack == null || pack.tokens != activeTokens;
  }

  Future<void> load() async {
    ai = await repository.loadAi();
    appearance = await repository.loadAppearance();
    _nextCustomSeq = _deriveNextCustomSeq(appearance.customPacks);
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

  void syncPlatformBrightness(Brightness brightness) {
    if (platformBrightness == brightness) return;
    platformBrightness = brightness;
    notifyListeners();
  }

  Future<void> setThemeMode(AppThemeModeSetting mode) async {
    if (appearance.mode == mode) return;
    await updateAppearance(appearance.copyWith(mode: mode));
  }

  Future<void> applyPack(String packId) async {
    final pack = appearance.packById(packId);
    if (pack == null) return;
    if (isEffectivelyDark) {
      await updateAppearance(
        appearance.copyWith(darkTokens: pack.tokens, darkPackId: pack.id),
      );
    } else {
      await updateAppearance(
        appearance.copyWith(lightTokens: pack.tokens, lightPackId: pack.id),
      );
    }
  }

  Future<void> updateToken(ThemeToken token, int value) async {
    if (isEffectivelyDark) {
      await updateAppearance(
        appearance.copyWith(
          darkTokens: appearance.darkTokens.withValue(token, value),
        ),
      );
    } else {
      await updateAppearance(
        appearance.copyWith(
          lightTokens: appearance.lightTokens.withValue(token, value),
        ),
      );
    }
  }

  Future<void> restoreDefaults() async {
    final pack = activePack;
    if (pack == null) return;
    await applyPack(pack.id);
  }

  int nextDefaultThemeNumber() {
    final pattern = RegExp(r'^(?:主题|Theme)\s*(\d+)$', caseSensitive: false);
    var max = 0;
    for (final pack in appearance.customPacks) {
      final match = pattern.firstMatch(pack.name.trim());
      if (match != null) {
        max = math.max(max, int.parse(match.group(1)!));
      }
    }
    return max + 1;
  }

  Future<void> saveCurrentAsTheme(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final pack = _createCustomPack(name: trimmed, tokens: activeTokens);
    final packs = [...appearance.customPacks, pack];
    var next = appearance.copyWith(customPacks: packs);
    next = isEffectivelyDark
        ? next.copyWith(darkPackId: pack.id)
        : next.copyWith(lightPackId: pack.id);
    await updateAppearance(next);
  }

  Future<void> renameCustomPack(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final index = appearance.customPacks.indexWhere((p) => p.id == id);
    if (index < 0) return;
    final packs = List<ThemeColorPack>.of(appearance.customPacks);
    packs[index] = packs[index].copyWith(name: trimmed);
    await updateAppearance(appearance.copyWith(customPacks: packs));
  }

  Future<void> copyCustomPack(String id, String name) async {
    final source = appearance.customPacks.where((p) => p.id == id).firstOrNull;
    final trimmed = name.trim();
    if (source == null || trimmed.isEmpty) return;
    final pack = _createCustomPack(name: trimmed, tokens: source.tokens);
    await updateAppearance(
      appearance.copyWith(customPacks: [...appearance.customPacks, pack]),
    );
  }

  Future<void> deleteCustomPack(String id) async {
    if (!appearance.customPacks.any((p) => p.id == id)) return;
    var next = appearance.copyWith(
      customPacks: [
        for (final pack in appearance.customPacks)
          if (pack.id != id) pack,
      ],
    );
    if (next.lightPackId == id) {
      next = next.copyWith(
        lightPackId: ThemeColorPack.builtInId(ThemePreset.light),
        lightTokens: ThemeTokens.presets[ThemePreset.light]!,
      );
    }
    if (next.darkPackId == id) {
      next = next.copyWith(
        darkPackId: ThemeColorPack.builtInId(ThemePreset.darkModern),
        darkTokens: ThemeTokens.defaults,
      );
    }
    await updateAppearance(next);
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

  ThemeColorPack _createCustomPack({
    required String name,
    required ThemeTokens tokens,
  }) {
    final id = 'custom_$_nextCustomSeq';
    _nextCustomSeq += 1;
    return ThemeColorPack(id: id, name: name, tokens: tokens);
  }

  int _deriveNextCustomSeq(List<ThemeColorPack> packs) {
    var max = 0;
    for (final pack in packs) {
      final match = RegExp(r'^custom_(\d+)$').firstMatch(pack.id);
      if (match != null) {
        max = math.max(max, int.parse(match.group(1)!));
      }
    }
    return max + 1;
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
