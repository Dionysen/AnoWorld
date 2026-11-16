import 'package:anoworld/app/settings_controller.dart';
import 'package:anoworld/data/settings/memory_settings_repository.dart';
import 'package:anoworld/domain/settings/appearance_settings.dart';
import 'package:anoworld/foundation/fonts/file_system_font_repository.dart';
import 'package:anoworld/foundation/fonts/system_font.dart';
import 'package:anoworld/foundation/fonts/system_font_catalog.dart';
import 'package:anoworld/foundation/theme/theme_color_pack.dart';
import 'package:anoworld/foundation/theme/theme_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

void main() {
  SettingsController controller() {
    return SettingsController(
      repository: MemorySettingsRepository(),
      platformBrightness: Brightness.dark,
      fonts: FileSystemFontRepository(
        catalog: _EmptyCatalog(),
        directories: const <Directory>[],
        importedFontsDirectory: () async =>
            Directory.systemTemp.createTempSync('aw_theme_test_fonts'),
      ),
    );
  }

  test('light and dark pack memory stay independent', () async {
    final c = controller();
    await c.load();

    await c.setThemeMode(AppThemeModeSetting.dark);
    await c.applyPack(ThemeColorPack.builtInId(ThemePreset.cursorDark));
    expect(c.appearance.darkPackId, 'cursorDark');

    await c.setThemeMode(AppThemeModeSetting.light);
    await c.applyPack(ThemeColorPack.builtInId(ThemePreset.mint));
    expect(c.appearance.lightPackId, 'mint');
    expect(c.appearance.darkPackId, 'cursorDark');
  });

  test('save as theme and restore defaults', () async {
    final c = controller();
    await c.load();
    await c.setThemeMode(AppThemeModeSetting.dark);
    await c.applyPack(ThemeColorPack.builtInId(ThemePreset.ocean));

    final before = c.activeTokens.accent;
    await c.updateToken(ThemeToken.accent, 0xFFFF0000);
    expect(c.activeTokens.accent, 0xFFFF0000);
    expect(c.isActivePackCustomized, isTrue);

    await c.saveCurrentAsTheme('主题测试');
    expect(c.appearance.customPacks, isNotEmpty);
    expect(c.activePackId.startsWith('custom_'), isTrue);

    await c.updateToken(ThemeToken.accent, 0xFF00FF00);
    await c.restoreDefaults();
    expect(c.activeTokens.accent, 0xFFFF0000);

    await c.applyPack(ThemeColorPack.builtInId(ThemePreset.ocean));
    expect(c.activeTokens.accent, before);
  });
}

class _EmptyCatalog extends SystemFontCatalog {
  @override
  Future<List<SystemFont>> listFonts() async => const [];
}
