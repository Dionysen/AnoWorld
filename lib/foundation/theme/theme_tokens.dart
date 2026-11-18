import 'dart:math' as math;

/// Semantic color roles used by the app chrome and chat surfaces.
///
/// Values are opaque ARGB integers so this model stays independent from
/// Flutter's rendering library and can be stored by any platform adapter.
enum ThemeToken {
  editorSurface,
  sidebarSurface,
  controlSurface,
  border,
  divider,
  primaryText,
  mutedText,
  accent,
  secondaryAccent,
  tertiaryAccent,
  cursor,
  chatBackground,
  characterBubble,
  userBubble,
  chatText,
  dialogueText,
}

enum ThemePreset {
  light,
  grey,
  slate,
  claude,
  mint,
  purple,
  hermes,
  ocean,
  darkModern,
  /// Warm charcoal — soft copper accent.
  graphite,
  /// Deep evergreen — muted sage accent.
  forest,
  /// Coffee brown — soft terracotta accent.
  espresso,
  /// Soft indigo night — periwinkle accent.
  midnight,
  /// Mauve dusk — dusty rose accent.
  dusk,
  /// Cursor Dark — editor chrome from Cursor's dark theme.
  cursorDark;
}

class ThemeTokens {
  ThemeTokens({
    required this.editorSurface,
    required this.sidebarSurface,
    required this.controlSurface,
    required this.border,
    required this.divider,
    required this.primaryText,
    required this.mutedText,
    required this.accent,
    this.secondaryAccent = defaultSecondaryAccent,
    this.tertiaryAccent = defaultTertiaryAccent,
    required this.cursor,
    int? chatBackground,
    int? characterBubble,
    int? userBubble,
    int? chatText,
    int? dialogueText,
  })  : chatBackground = chatBackground ?? editorSurface,
        characterBubble = characterBubble ?? controlSurface,
        userBubble = userBubble ??
            blendOnto(
              accent,
              editorSurface,
              surfaceLuminanceOf(editorSurface) > 0.5 ? 0.18 : 0.28,
            ),
        chatText = chatText ?? primaryText,
        // Soft orange tertiary keeps quoted speech distinct from narration.
        dialogueText = dialogueText ?? tertiaryAccent;

  /// Accent for light presets — Feishu-like primary blue on white chrome.
  static const lightAccent = 0xFF3370FF;

  static const _lightPrimaryText = 0xFF1F2329;
  static const _lightMutedText = 0xFF646A73;
  static const _lightBorder = 0xFFDEE0E3;
  static const _lightCharacterBubble = 0xFFF5F6F7;
  static const _lightSecondaryAccent = 0xFF4E83FD;

  /// Shared chrome contrast for built-in light presets; [editorSurface] /
  /// [sidebarSurface] keep each preset's tint.
  static ThemeTokens lightPreset({
    required int editorSurface,
    required int sidebarSurface,
  }) =>
      ThemeTokens(
        editorSurface: editorSurface,
        sidebarSurface: sidebarSurface,
        controlSurface: 0xFFFFFFFF,
        border: _lightBorder,
        divider: _lightBorder,
        primaryText: _lightPrimaryText,
        mutedText: _lightMutedText,
        accent: lightAccent,
        secondaryAccent: _lightSecondaryAccent,
        cursor: _lightPrimaryText,
        chatBackground: editorSurface,
        characterBubble: _lightCharacterBubble,
      );

  static const _darkPrimaryText = 0xFFEBEBEB;
  static const _darkMutedText = 0xFFB0B0B0;

  /// Shared readability for built-in dark presets; surfaces and accents vary
  /// per preset. [primaryText] / [mutedText] may be tinted but stay brighter
  /// than legacy `#CCCCCC` / `#9D9D9D` neutral chrome.
  static ThemeTokens darkPreset({
    required int editorSurface,
    required int sidebarSurface,
    required int controlSurface,
    required int border,
    required int divider,
    required int accent,
    int secondaryAccent = defaultSecondaryAccent,
    int tertiaryAccent = defaultTertiaryAccent,
    int primaryText = _darkPrimaryText,
    int mutedText = _darkMutedText,
    int? cursor,
  }) =>
      ThemeTokens(
        editorSurface: editorSurface,
        sidebarSurface: sidebarSurface,
        controlSurface: controlSurface,
        border: border,
        divider: divider,
        primaryText: primaryText,
        mutedText: mutedText,
        accent: accent,
        secondaryAccent: secondaryAccent,
        tertiaryAccent: tertiaryAccent,
        cursor: cursor ?? primaryText,
      );

  /// Cursor / VS Code “Sync Changes” button blue.
  static const darkModernAccent = 0xFF3376CE;

  /// Second accent for section/action differentiation (teal).
  static const defaultSecondaryAccent = 0xFF1ABC9C;

  /// Third accent for section/action differentiation (soft orange).
  static const defaultTertiaryAccent = 0xFFE09A5A;

  /// Default dark pack (Dark Modern).
  static final defaults = darkPreset(
    editorSurface: 0xFF1F1F1F,
    sidebarSurface: 0xFF181818,
    controlSurface: 0xFF313131,
    border: 0xFF2B2B2B,
    divider: 0xFF2B2B2B,
    accent: darkModernAccent,
    cursor: 0xFFFFFFFF,
  );

  static final presets = <ThemePreset, ThemeTokens>{
    ThemePreset.light: lightPreset(
      editorSurface: 0xFFFFFFFF,
      sidebarSurface: 0xFFF2F5F8,
    ),
    ThemePreset.grey: lightPreset(
      editorSurface: 0xFFF8FAFC,
      sidebarSurface: 0xFFF2F5F8,
    ),
    ThemePreset.slate: lightPreset(
      editorSurface: 0xFFFAFAFA,
      sidebarSurface: 0xFFF2F5F8,
    ),
    ThemePreset.claude: lightPreset(
      editorSurface: 0xFFFCFAF7,
      sidebarSurface: 0xFFF4F0E9,
    ),
    ThemePreset.mint: lightPreset(
      editorSurface: 0xFFFBFDFC,
      sidebarSurface: 0xFFE8F3EE,
    ),
    ThemePreset.purple: lightPreset(
      editorSurface: 0xFFFCF9FF,
      sidebarSurface: 0xFFF2F0F8,
    ),
    ThemePreset.hermes: lightPreset(
      editorSurface: 0xFFF7F8FF,
      sidebarSurface: 0xFFECEDF8,
    ),
    ThemePreset.ocean: darkPreset(
      editorSurface: 0xFF161923,
      sidebarSurface: 0xFF10131B,
      controlSurface: 0xFF202531,
      border: 0xFF303847,
      divider: 0xFF1C2230,
      accent: darkModernAccent,
      primaryText: 0xFFECF0F8,
      mutedText: 0xFF9AA4B6,
      cursor: 0xFFFFFFFF,
    ),
    ThemePreset.darkModern: defaults,
    // Warm charcoal — easy on the eyes for long sessions.
    ThemePreset.graphite: darkPreset(
      editorSurface: 0xFF1B1A19,
      sidebarSurface: 0xFF131211,
      controlSurface: 0xFF2A2927,
      border: 0xFF353330,
      divider: 0xFF262422,
      accent: 0xFFC9A06B,
      secondaryAccent: 0xFF7FAE98,
      tertiaryAccent: 0xFFD4A57A,
      primaryText: 0xFFF2EEE8,
      mutedText: 0xFFAEA9A0,
    ),
    // Deep forest — cool green tint without neon punch.
    ThemePreset.forest: darkPreset(
      editorSurface: 0xFF151A17,
      sidebarSurface: 0xFF0F1311,
      controlSurface: 0xFF222A26,
      border: 0xFF2E3833,
      divider: 0xFF1A211D,
      accent: 0xFF6BAE8F,
      secondaryAccent: 0xFF5FA8B8,
      tertiaryAccent: 0xFFD2A06E,
      primaryText: 0xFFEAF2ED,
      mutedText: 0xFF9EAEA6,
    ),
    // Espresso — warm brown chrome, soft terracotta accent.
    ThemePreset.espresso: darkPreset(
      editorSurface: 0xFF1A1613,
      sidebarSurface: 0xFF120F0D,
      controlSurface: 0xFF2A241F,
      border: 0xFF3A322B,
      divider: 0xFF221C18,
      accent: 0xFFD08B6A,
      secondaryAccent: 0xFF7EAE9A,
      tertiaryAccent: 0xFFE0A070,
      primaryText: 0xFFF6EFE8,
      mutedText: 0xFFB0A49A,
    ),
    // Midnight — soft indigo, calmer than Ocean's cool blue.
    ThemePreset.midnight: darkPreset(
      editorSurface: 0xFF16151E,
      sidebarSurface: 0xFF100F16,
      controlSurface: 0xFF23222E,
      border: 0xFF323040,
      divider: 0xFF1B1A24,
      accent: 0xFF8B9FE0,
      secondaryAccent: 0xFF6FB5A8,
      tertiaryAccent: 0xFFD4A07A,
      primaryText: 0xFFEDEBF6,
      mutedText: 0xFFAAA6BE,
    ),
    // Dusk — mauve night with a dusty rose accent.
    ThemePreset.dusk: darkPreset(
      editorSurface: 0xFF1B1619,
      sidebarSurface: 0xFF131014,
      controlSurface: 0xFF2A2327,
      border: 0xFF3A3236,
      divider: 0xFF221C20,
      accent: 0xFFD49AAA,
      secondaryAccent: 0xFF7EAEA0,
      tertiaryAccent: 0xFFD4A07A,
      primaryText: 0xFFF6EEF2,
      mutedText: 0xFFB2A4AC,
    ),
    // Cursor Dark — near-black chrome from Cursor's current dark UI
    // (much deeper than Dark Modern's #1F1F1F / #313131 surfaces).
    ThemePreset.cursorDark: darkPreset(
      editorSurface: 0xFF141414,
      sidebarSurface: 0xFF101010,
      controlSurface: 0xFF232323,
      border: 0xFF2A2A2A,
      divider: 0xFF1C1C1C,
      accent: 0xFF4D9DF4,
      secondaryAccent: 0xFF6CB6FF,
      tertiaryAccent: 0xFFD4B483,
      primaryText: _darkPrimaryText,
      mutedText: 0xFF909090,
      cursor: 0xFFFFFFFF,
    ),
  };

  final int editorSurface;
  final int sidebarSurface;
  final int controlSurface;
  final int border;
  final int divider;
  final int primaryText;
  final int mutedText;
  final int accent;
  final int secondaryAccent;
  final int tertiaryAccent;
  final int cursor;
  final int chatBackground;
  final int characterBubble;
  final int userBubble;
  final int chatText;
  final int dialogueText;

  ThemePreset? get preset => ThemePreset.values
      .where((candidate) => presets[candidate] == this)
      .firstOrNull;

  /// Relative luminance of [editorSurface] in 0…1 (sRGB).
  double get surfaceLuminance => surfaceLuminanceOf(editorSurface);

  bool get isLight => surfaceLuminance > 0.5;

  static double surfaceLuminanceOf(int argb) {
    final c = argb & 0xFFFFFF;
    double linearize(int value) {
      final v = value / 255.0;
      return v <= 0.04045
          ? v / 12.92
          : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    }

    final r = linearize((c >> 16) & 0xFF);
    final g = linearize((c >> 8) & 0xFF);
    final b = linearize(c & 0xFF);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// Opaque alpha-blend of [foreground] onto [background].
  static int blendOnto(int foreground, int background, double alpha) {
    final t = alpha.clamp(0.0, 1.0);
    int channel(int shift) {
      final fg = (foreground >> shift) & 0xFF;
      final bg = (background >> shift) & 0xFF;
      return (fg * t + bg * (1 - t)).round().clamp(0, 255);
    }

    return 0xFF000000 |
        (channel(16) << 16) |
        (channel(8) << 8) |
        channel(0);
  }

  int valueOf(ThemeToken token) => switch (token) {
        ThemeToken.editorSurface => editorSurface,
        ThemeToken.sidebarSurface => sidebarSurface,
        ThemeToken.controlSurface => controlSurface,
        ThemeToken.border => border,
        ThemeToken.divider => divider,
        ThemeToken.primaryText => primaryText,
        ThemeToken.mutedText => mutedText,
        ThemeToken.accent => accent,
        ThemeToken.secondaryAccent => secondaryAccent,
        ThemeToken.tertiaryAccent => tertiaryAccent,
        ThemeToken.cursor => cursor,
        ThemeToken.chatBackground => chatBackground,
        ThemeToken.characterBubble => characterBubble,
        ThemeToken.userBubble => userBubble,
        ThemeToken.chatText => chatText,
        ThemeToken.dialogueText => dialogueText,
      };

  ThemeTokens withValue(ThemeToken token, int value) => switch (token) {
        ThemeToken.editorSurface => copyWith(editorSurface: value),
        ThemeToken.sidebarSurface => copyWith(sidebarSurface: value),
        ThemeToken.controlSurface => copyWith(controlSurface: value),
        ThemeToken.border => copyWith(border: value),
        ThemeToken.divider => copyWith(divider: value),
        ThemeToken.primaryText => copyWith(primaryText: value),
        ThemeToken.mutedText => copyWith(mutedText: value),
        ThemeToken.accent => copyWith(accent: value),
        ThemeToken.secondaryAccent => copyWith(secondaryAccent: value),
        ThemeToken.tertiaryAccent => copyWith(tertiaryAccent: value),
        ThemeToken.cursor => copyWith(cursor: value),
        ThemeToken.chatBackground => copyWith(chatBackground: value),
        ThemeToken.characterBubble => copyWith(characterBubble: value),
        ThemeToken.userBubble => copyWith(userBubble: value),
        ThemeToken.chatText => copyWith(chatText: value),
        ThemeToken.dialogueText => copyWith(dialogueText: value),
      };

  ThemeTokens copyWith({
    int? editorSurface,
    int? sidebarSurface,
    int? controlSurface,
    int? border,
    int? divider,
    int? primaryText,
    int? mutedText,
    int? accent,
    int? secondaryAccent,
    int? tertiaryAccent,
    int? cursor,
    int? chatBackground,
    int? characterBubble,
    int? userBubble,
    int? chatText,
    int? dialogueText,
  }) =>
      ThemeTokens(
        editorSurface: editorSurface ?? this.editorSurface,
        sidebarSurface: sidebarSurface ?? this.sidebarSurface,
        controlSurface: controlSurface ?? this.controlSurface,
        border: border ?? this.border,
        divider: divider ?? this.divider,
        primaryText: primaryText ?? this.primaryText,
        mutedText: mutedText ?? this.mutedText,
        accent: accent ?? this.accent,
        secondaryAccent: secondaryAccent ?? this.secondaryAccent,
        tertiaryAccent: tertiaryAccent ?? this.tertiaryAccent,
        cursor: cursor ?? this.cursor,
        chatBackground: chatBackground ?? this.chatBackground,
        characterBubble: characterBubble ?? this.characterBubble,
        userBubble: userBubble ?? this.userBubble,
        chatText: chatText ?? this.chatText,
        dialogueText: dialogueText ?? this.dialogueText,
      );

  Map<String, dynamic> toJson() => {
        'editorSurface': editorSurface,
        'sidebarSurface': sidebarSurface,
        'controlSurface': controlSurface,
        'border': border,
        'divider': divider,
        'primaryText': primaryText,
        'mutedText': mutedText,
        'accent': accent,
        'secondaryAccent': secondaryAccent,
        'tertiaryAccent': tertiaryAccent,
        'cursor': cursor,
        'chatBackground': chatBackground,
        'characterBubble': characterBubble,
        'userBubble': userBubble,
        'chatText': chatText,
        'dialogueText': dialogueText,
      };

  factory ThemeTokens.fromJson(Map<String, dynamic> json) {
    final editorSurface = json['editorSurface'] as int;
    final controlSurface = json['controlSurface'] as int;
    final primaryText = json['primaryText'] as int;
    final accent = json['accent'] as int;
    return ThemeTokens(
      editorSurface: editorSurface,
      sidebarSurface: json['sidebarSurface'] as int,
      controlSurface: controlSurface,
      border: json['border'] as int,
      divider: json['divider'] as int,
      primaryText: primaryText,
      mutedText: json['mutedText'] as int,
      accent: accent,
      secondaryAccent:
          json['secondaryAccent'] as int? ?? defaultSecondaryAccent,
      tertiaryAccent: json['tertiaryAccent'] as int? ?? defaultTertiaryAccent,
      cursor: json['cursor'] as int,
      chatBackground: json['chatBackground'] as int?,
      characterBubble: json['characterBubble'] as int?,
      userBubble: json['userBubble'] as int?,
      chatText: json['chatText'] as int?,
      dialogueText: json['dialogueText'] as int?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ThemeTokens &&
      editorSurface == other.editorSurface &&
      sidebarSurface == other.sidebarSurface &&
      controlSurface == other.controlSurface &&
      border == other.border &&
      divider == other.divider &&
      primaryText == other.primaryText &&
      mutedText == other.mutedText &&
      accent == other.accent &&
      secondaryAccent == other.secondaryAccent &&
      tertiaryAccent == other.tertiaryAccent &&
      cursor == other.cursor &&
      chatBackground == other.chatBackground &&
      characterBubble == other.characterBubble &&
      userBubble == other.userBubble &&
      chatText == other.chatText &&
      dialogueText == other.dialogueText;

  @override
  int get hashCode => Object.hash(
        editorSurface,
        sidebarSurface,
        controlSurface,
        border,
        divider,
        primaryText,
        mutedText,
        accent,
        secondaryAccent,
        tertiaryAccent,
        cursor,
        chatBackground,
        characterBubble,
        userBubble,
        chatText,
        dialogueText,
      );
}
