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
        ThemeToken.secondaryAccent => '次强调色',
        ThemeToken.tertiaryAccent => '第三强调色',
        ThemeToken.cursor => '光标',
        ThemeToken.chatBackground => '聊天背景',
        ThemeToken.characterBubble => '角色气泡背景',
        ThemeToken.userBubble => '用户气泡背景',
        ThemeToken.chatText => '文字颜色',
        ThemeToken.dialogueText => '说话文字颜色',
      };

  String get description => switch (this) {
        ThemeToken.editorSurface => '整个应用的底色。',
        ThemeToken.sidebarSurface => '侧边栏和弹出面板。',
        ThemeToken.controlSurface => '按钮、菜单和输入框。',
        ThemeToken.border => '按钮和输入框的描边。',
        ThemeToken.divider => '列表和分区之间的分隔线。',
        ThemeToken.primaryText => '标题和正文。',
        ThemeToken.mutedText => '提示和说明文字。',
        ThemeToken.accent => '高亮和选中效果。',
        ThemeToken.secondaryAccent => '用来区分区块和操作的另一种强调色。',
        ThemeToken.tertiaryAccent => '再一种强调色，用在需要区分的地方。',
        ThemeToken.cursor => '输入时闪烁的光标。',
        ThemeToken.chatBackground => '没有设置背景图时，聊天页的底色。',
        ThemeToken.characterBubble => '角色消息气泡的颜色。',
        ThemeToken.userBubble => '你发出的消息气泡颜色。',
        ThemeToken.chatText => '消息里的普通文字。',
        ThemeToken.dialogueText => '引号里说的话会用这个颜色，并加粗显示。',
      };
}
