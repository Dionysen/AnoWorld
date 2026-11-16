import 'package:flutter/material.dart';

import 'theme_tokens.dart';

extension ThemePresetLabels on ThemePreset {
  String get label => switch (this) {
        ThemePreset.light => '浅色',
        ThemePreset.grey => '灰色',
        ThemePreset.slate => '石板',
        ThemePreset.claude => 'Claude Code',
        ThemePreset.mint => '薄荷',
        ThemePreset.purple => '紫色',
        ThemePreset.hermes => 'Hermes',
        ThemePreset.ocean => '海洋',
        ThemePreset.darkModern => '深色现代',
        ThemePreset.graphite => '石墨',
        ThemePreset.forest => '深林',
        ThemePreset.espresso => '咖啡',
        ThemePreset.midnight => '午夜',
        ThemePreset.dusk => '暮色',
        ThemePreset.cursorDark => 'Cursor 深色',
      };

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

extension ThemeTokenLabels on ThemeToken {
  String get label => switch (this) {
        ThemeToken.editorSurface => '应用背景',
        ThemeToken.sidebarSurface => '面板背景',
        ThemeToken.controlSurface => '按钮和输入框',
        ThemeToken.border => '边框',
        ThemeToken.divider => '分割线',
        ThemeToken.primaryText => '主文字',
        ThemeToken.mutedText => '次要文字',
        ThemeToken.accent => '强调色',
        ThemeToken.secondaryAccent => '次要强调色',
        ThemeToken.tertiaryAccent => '辅助强调色',
        ThemeToken.cursor => '光标',
        ThemeToken.chatBackground => '聊天背景',
        ThemeToken.characterBubble => '角色气泡',
        ThemeToken.userBubble => '我的气泡',
        ThemeToken.chatText => '消息文字',
        ThemeToken.dialogueText => '对白文字',
      };

  String get description => switch (this) {
        ThemeToken.editorSurface => '窗口底色',
        ThemeToken.sidebarSurface => '侧栏与弹层',
        ThemeToken.controlSurface => '按钮、菜单、输入框',
        ThemeToken.border => '控件描边',
        ThemeToken.divider => '列表分隔线',
        ThemeToken.primaryText => '标题与正文',
        ThemeToken.mutedText => '提示与说明',
        ThemeToken.accent => '选中与高亮',
        ThemeToken.secondaryAccent => '第二强调',
        ThemeToken.tertiaryAccent => '第三强调',
        ThemeToken.cursor => '输入光标',
        ThemeToken.chatBackground => '聊天页底色',
        ThemeToken.characterBubble => '角色气泡',
        ThemeToken.userBubble => '我的气泡',
        ThemeToken.chatText => '叙述文字',
        ThemeToken.dialogueText => '引号对白',
      };

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
