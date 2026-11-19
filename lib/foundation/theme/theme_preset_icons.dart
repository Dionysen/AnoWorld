import 'package:flutter/material.dart';

import 'theme_tokens.dart';

/// Icon per built-in color pack. Names live in the app's copy layer.
extension ThemePresetIcons on ThemePreset {
  IconData get icon => switch (this) {
        ThemePreset.light => Icons.light_mode_outlined,
        ThemePreset.grey => Icons.blur_on_outlined,
        ThemePreset.slate => Icons.layers_outlined,
        ThemePreset.claude => Icons.auto_stories_outlined,
        ThemePreset.mint => Icons.eco_outlined,
        ThemePreset.purple => Icons.color_lens_outlined,
        ThemePreset.hermes => Icons.send_outlined,
        ThemePreset.ocean => Icons.water_outlined,
        ThemePreset.darkModern => Icons.dark_mode_outlined,
        ThemePreset.graphite => Icons.grain_outlined,
        ThemePreset.forest => Icons.park_outlined,
        ThemePreset.espresso => Icons.coffee_outlined,
        ThemePreset.midnight => Icons.nights_stay_outlined,
        ThemePreset.dusk => Icons.wb_twilight_outlined,
        ThemePreset.cursorDark => Icons.terminal_outlined,
      };
}

/// Icon per editable color slot. Names live in the app's copy layer.
extension ThemeTokenIcons on ThemeToken {
  IconData get icon => switch (this) {
        ThemeToken.editorSurface => Icons.crop_landscape_outlined,
        ThemeToken.sidebarSurface => Icons.view_sidebar_outlined,
        ThemeToken.controlSurface => Icons.smart_button_outlined,
        ThemeToken.border => Icons.border_style_outlined,
        ThemeToken.divider => Icons.horizontal_rule,
        ThemeToken.primaryText => Icons.title,
        ThemeToken.mutedText => Icons.notes_outlined,
        ThemeToken.accent => Icons.highlight_outlined,
        ThemeToken.secondaryAccent => Icons.filter_2_outlined,
        ThemeToken.tertiaryAccent => Icons.filter_3_outlined,
        ThemeToken.cursor => Icons.text_fields,
        ThemeToken.chatBackground => Icons.chat_bubble_outline,
        ThemeToken.characterBubble => Icons.forum_outlined,
        ThemeToken.userBubble => Icons.chat_outlined,
        ThemeToken.chatText => Icons.format_color_text_outlined,
        ThemeToken.dialogueText => Icons.format_quote_outlined,
      };
}
