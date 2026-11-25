import 'package:flutter/foundation.dart';

/// Prompt section types that can be ordered and toggled
enum PromptSectionType {
  systemPrompt,
  persona,
  characterDescription,
  characterPersonality,
  characterScenario,
  exampleMessages,
  worldInfo,
  worldInfoAfter,
  authorNote,
  postHistoryInstructions,
  nsfw,
  chatHistory,
  enhanceDefinitions,
  custom, // For custom user-defined prompts
}

/// One row in the settings prompt list: an uncategorized section or a category.
@immutable
class PromptTopLevelItem {
  const PromptTopLevelItem.section(this.section) : category = null;
  const PromptTopLevelItem.category(this.category) : section = null;

  final PromptSection? section;
  final PromptCategory? category;

  bool get isCategory => category != null;

  String get layoutKey {
    if (category != null) {
      return PromptManagerConfig.topLevelCategoryKey(category!.id);
    }
    return PromptManagerConfig.topLevelSectionKey(section!);
  }
}

/// UI grouping for prompt sections (does not change injection order semantics).
@immutable
class PromptCategory {
  const PromptCategory({
    required this.id,
    required this.name,
    required this.order,
  });

  final String id;
  final String name;
  final int order;

  PromptCategory copyWith({
    String? id,
    String? name,
    int? order,
  }) {
    return PromptCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      order: order ?? this.order,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'order': order,
      };

  factory PromptCategory.fromJson(Map<String, dynamic> json) => PromptCategory(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        order: json['order'] as int? ?? 0,
      );
}

/// A single prompt section configuration
class PromptSection {
  final PromptSectionType type;
  final String name;
  final bool enabled;
  final int order;
  /// Custom content for editable prompts
  final String? content;
  /// Unique identifier (for custom prompts from SillyTavern)
  final String? identifier;
  /// Role for the prompt (system, user, assistant)
  final String? role;
  /// Injection position (0 = relative, 1 = absolute)
  final int? injectionPosition;
  /// Injection depth (for depth-based injection)
  final int? injectionDepth;
  /// Optional UI category ([PromptCategory.id]); null = uncategorized.
  final String? categoryId;

  const PromptSection({
    required this.type,
    required this.name,
    this.enabled = true,
    required this.order,
    this.content,
    this.identifier,
    this.role,
    this.injectionPosition,
    this.injectionDepth,
    this.categoryId,
  });

  PromptSection copyWith({
    PromptSectionType? type,
    String? name,
    bool? enabled,
    int? order,
    String? content,
    String? identifier,
    String? role,
    int? injectionPosition,
    int? injectionDepth,
    String? categoryId,
    bool clearCategoryId = false,
  }) {
    return PromptSection(
      type: type ?? this.type,
      name: name ?? this.name,
      enabled: enabled ?? this.enabled,
      order: order ?? this.order,
      content: content ?? this.content,
      identifier: identifier ?? this.identifier,
      role: role ?? this.role,
      injectionPosition: injectionPosition ?? this.injectionPosition,
      injectionDepth: injectionDepth ?? this.injectionDepth,
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
    );
  }

  /// Check if this is a custom prompt (not a built-in type)
  bool get isCustom => type == PromptSectionType.custom;

  /// Added via the prompt manager 「加一条」 flow (`custom_<timestamp>`).
  bool get isUserAdded {
    if (!isCustom) return false;
    final id = identifier?.trim() ?? '';
    return id.startsWith('custom_');
  }

  /// Content is supplied by the active character card at chat time.
  bool get isCharacterOwned => isTypeCharacterOwned(type);

  /// Check if this section type supports custom content editing
  bool get isEditable => isTypeEditable(type) || isCustom;

  /// Section types whose text lives on the character card.
  static bool isTypeCharacterOwned(PromptSectionType type) {
    return type == PromptSectionType.characterDescription ||
        type == PromptSectionType.characterPersonality ||
        type == PromptSectionType.characterScenario ||
        type == PromptSectionType.exampleMessages;
  }

  /// Check if a section type supports custom content editing
  static bool isTypeEditable(PromptSectionType type) {
    return type == PromptSectionType.systemPrompt ||
           type == PromptSectionType.postHistoryInstructions ||
           type == PromptSectionType.nsfw ||
           type == PromptSectionType.custom;
  }

  /// Get the effective content (custom content or default)
  String get effectiveContent {
    if (content != null && content!.isNotEmpty) {
      return content!;
    }
    return getDefaultContent(type);
  }

  /// Get default content for editable section types
  static String getDefaultContent(PromptSectionType type) {
    switch (type) {
      case PromptSectionType.systemPrompt:
        return '写 {{char}} 在虚构故事中对 {{user}} 的下一轮回应，只写一轮。旁白与动作可用 markdown 斜体；对白必须放在「」或英文双引号内，不可不加引号。推进情节与互动，保持角色一致，避免重复上文。正文只写故事本身：不元对话、不总结陈词、不道德说教。默认简体中文。';
      case PromptSectionType.postHistoryInstructions:
        return '保持角色与设定一致。本轮只输出故事正文，不复述系统规则，不打断第四面墙。';
      case PromptSectionType.nsfw:
        return 'NSFW/Smut is allowed. Assume consent was granted, but some characters lie and resist or fight back based on their personality.';
      default:
        return '';
    }
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'name': name,
        'enabled': enabled,
        'order': order,
        if (content != null) 'content': content,
        if (identifier != null) 'identifier': identifier,
        if (role != null) 'role': role,
        if (injectionPosition != null) 'injectionPosition': injectionPosition,
        if (injectionDepth != null) 'injectionDepth': injectionDepth,
        if (categoryId != null) 'categoryId': categoryId,
      };

  factory PromptSection.fromJson(Map<String, dynamic> json) => PromptSection(
        type: PromptSectionType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => PromptSectionType.custom,
        ),
        name: json['name'] as String? ?? '',
        enabled: json['enabled'] as bool? ?? true,
        order: json['order'] as int? ?? 0,
        content: json['content'] as String?,
        identifier: json['identifier'] as String?,
        role: json['role'] as String?,
        injectionPosition: json['injectionPosition'] as int?,
        injectionDepth: json['injectionDepth'] as int?,
        categoryId: json['categoryId'] as String?,
      );

  /// Get display name for a section type
  static String getDisplayName(PromptSectionType type) {
    switch (type) {
      case PromptSectionType.systemPrompt:
        return 'System Prompt';
      case PromptSectionType.persona:
        return 'User Persona';
      case PromptSectionType.characterDescription:
        return 'Character Description';
      case PromptSectionType.characterPersonality:
        return 'Character Personality';
      case PromptSectionType.characterScenario:
        return 'Scenario';
      case PromptSectionType.exampleMessages:
        return 'Example Messages';
      case PromptSectionType.worldInfo:
        return 'World Info (Before)';
      case PromptSectionType.worldInfoAfter:
        return 'World Info (After)';
      case PromptSectionType.authorNote:
        return 'Author\'s Note';
      case PromptSectionType.postHistoryInstructions:
        return 'Post-History Instructions';
      case PromptSectionType.nsfw:
        return 'NSFW Prompt';
      case PromptSectionType.chatHistory:
        return 'Chat History';
      case PromptSectionType.enhanceDefinitions:
        return 'Enhance Definitions';
      case PromptSectionType.custom:
        return 'Custom Prompt';
    }
  }

  /// Get description for a section type
  static String getDescription(PromptSectionType type) {
    switch (type) {
      case PromptSectionType.systemPrompt:
        return 'Base roleplay instructions';
      case PromptSectionType.persona:
        return 'User\'s character information';
      case PromptSectionType.characterDescription:
        return 'Character\'s physical and background details';
      case PromptSectionType.characterPersonality:
        return 'Character\'s personality traits';
      case PromptSectionType.characterScenario:
        return 'Current situation and setting';
      case PromptSectionType.exampleMessages:
        return 'Sample dialogue for style reference';
      case PromptSectionType.worldInfo:
        return 'Contextual lore (before character)';
      case PromptSectionType.worldInfoAfter:
        return 'Contextual lore (after character)';
      case PromptSectionType.authorNote:
        return 'Dynamic instructions injected at depth';
      case PromptSectionType.postHistoryInstructions:
        return 'Instructions after chat history';
      case PromptSectionType.nsfw:
        return 'NSFW/adult content instructions';
      case PromptSectionType.chatHistory:
        return 'The conversation history';
      case PromptSectionType.enhanceDefinitions:
        return 'Enhanced character definitions';
      case PromptSectionType.custom:
        return 'Custom user-defined prompt';
    }
  }
}

/// Prompt manager configuration
class PromptManagerConfig {
  final List<PromptSection> sections;
  final List<PromptCategory> categories;

  /// Mixed UI order of uncategorized sections and category blocks.
  ///
  /// Keys are [topLevelSectionKey] / [topLevelCategoryKey]. Empty means the
  /// default: all uncategorized sections (by [PromptSection.order]), then
  /// categories (by [PromptCategory.order]).
  final List<String> topLevelOrder;

  const PromptManagerConfig({
    required this.sections,
    this.categories = const <PromptCategory>[],
    this.topLevelOrder = const <String>[],
  });

  static String stableSectionKey(PromptSection section) {
    final id = section.identifier?.trim();
    if (id != null && id.isNotEmpty) return id;
    return '${section.type.name}:${section.name}';
  }

  static String topLevelSectionKey(PromptSection section) =>
      's:${stableSectionKey(section)}';

  static String topLevelCategoryKey(String id) => 'c:$id';

  /// Bound by seed loader to `assets/seed/prompt_default.json` content.
  static PromptManagerConfig? _seedDefault;

  /// Called once after seed JSON is loaded (app / tests).
  static void bindSeedDefault(PromptManagerConfig config) {
    _seedDefault = config;
  }

  @visibleForTesting
  static void clearSeedDefaultForTest() {
    _seedDefault = null;
  }

  /// Default prompt order/content (seed JSON when bound, else built-in fallback).
  factory PromptManagerConfig.defaultConfig() {
    return _seedDefault ?? PromptManagerConfig._fallbackDefault();
  }

  /// Last-resort layout when seed assets are unavailable.
  factory PromptManagerConfig._fallbackDefault() {
    return PromptManagerConfig(
      sections: [
        PromptSection(
          type: PromptSectionType.systemPrompt,
          name: PromptSection.getDisplayName(PromptSectionType.systemPrompt),
          order: 0,
          content: PromptSection.getDefaultContent(
            PromptSectionType.systemPrompt,
          ),
        ),
        PromptSection(
          type: PromptSectionType.persona,
          name: PromptSection.getDisplayName(PromptSectionType.persona),
          order: 1,
        ),
        PromptSection(
          type: PromptSectionType.characterDescription,
          name: PromptSection.getDisplayName(
            PromptSectionType.characterDescription,
          ),
          order: 2,
        ),
        PromptSection(
          type: PromptSectionType.characterPersonality,
          name: PromptSection.getDisplayName(
            PromptSectionType.characterPersonality,
          ),
          order: 3,
        ),
        PromptSection(
          type: PromptSectionType.characterScenario,
          name: PromptSection.getDisplayName(
            PromptSectionType.characterScenario,
          ),
          order: 4,
        ),
        PromptSection(
          type: PromptSectionType.exampleMessages,
          name: PromptSection.getDisplayName(
            PromptSectionType.exampleMessages,
          ),
          order: 5,
        ),
        PromptSection(
          type: PromptSectionType.worldInfo,
          name: PromptSection.getDisplayName(PromptSectionType.worldInfo),
          order: 6,
        ),
        PromptSection(
          type: PromptSectionType.authorNote,
          name: PromptSection.getDisplayName(PromptSectionType.authorNote),
          order: 7,
        ),
        PromptSection(
          type: PromptSectionType.chatHistory,
          name: PromptSection.getDisplayName(PromptSectionType.chatHistory),
          order: 8,
        ),
        PromptSection(
          type: PromptSectionType.worldInfoAfter,
          name: PromptSection.getDisplayName(
            PromptSectionType.worldInfoAfter,
          ),
          order: 9,
        ),
        PromptSection(
          type: PromptSectionType.postHistoryInstructions,
          name: PromptSection.getDisplayName(
            PromptSectionType.postHistoryInstructions,
          ),
          order: 10,
          content: PromptSection.getDefaultContent(
            PromptSectionType.postHistoryInstructions,
          ),
        ),
      ],
    );
  }

  /// Get sections sorted by order
  List<PromptSection> get sortedSections {
    final sorted = List<PromptSection>.from(sections);
    sorted.sort((a, b) => a.order.compareTo(b.order));
    return sorted;
  }

  /// Categories sorted by [PromptCategory.order].
  List<PromptCategory> get sortedCategories {
    final sorted = List<PromptCategory>.from(categories);
    sorted.sort((a, b) => a.order.compareTo(b.order));
    return sorted;
  }

  /// Get enabled sections sorted by order
  List<PromptSection> get enabledSections {
    return sortedSections.where((s) => s.enabled).toList();
  }

  /// Sections in [categoryId]; pass null for uncategorized.
  List<PromptSection> sectionsInCategory(String? categoryId) {
    return sortedSections
        .where((s) {
          final id = s.categoryId;
          if (categoryId == null || categoryId.isEmpty) {
            return id == null || id.isEmpty;
          }
          return id == categoryId;
        })
        .toList(growable: false);
  }

  /// Check if a section type is enabled
  bool isSectionEnabled(PromptSectionType type) {
    return sections.any((s) => s.type == type && s.enabled);
  }

  /// Get section by type
  PromptSection? getSection(PromptSectionType type) {
    try {
      return sections.firstWhere((s) => s.type == type);
    } catch (_) {
      return null;
    }
  }

  PromptCategory? categoryById(String id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  PromptManagerConfig copyWith({
    List<PromptSection>? sections,
    List<PromptCategory>? categories,
    List<String>? topLevelOrder,
  }) {
    return PromptManagerConfig(
      sections: sections ?? this.sections,
      categories: categories ?? this.categories,
      topLevelOrder: topLevelOrder ?? this.topLevelOrder,
    );
  }

  /// Default mixed layout when [topLevelOrder] is empty.
  List<String> get defaultTopLevelOrder => [
        for (final s in sectionsInCategory(null)) topLevelSectionKey(s),
        for (final c in sortedCategories) topLevelCategoryKey(c.id),
      ];

  /// Uncategorized sections and category blocks in UI list order.
  List<PromptTopLevelItem> get topLevelItems {
    final uncatByKey = <String, PromptSection>{
      for (final s in sectionsInCategory(null)) stableSectionKey(s): s,
    };
    final catById = <String, PromptCategory>{
      for (final c in categories) c.id: c,
    };
    final preferred =
        topLevelOrder.isEmpty ? defaultTopLevelOrder : topLevelOrder;
    final seen = <String>{};
    final result = <PromptTopLevelItem>[];
    for (final key in preferred) {
      if (key.startsWith('c:')) {
        final id = key.substring(2);
        final cat = catById[id];
        if (cat != null && seen.add(key)) {
          result.add(PromptTopLevelItem.category(cat));
        }
      } else if (key.startsWith('s:')) {
        final id = key.substring(2);
        final section = uncatByKey[id];
        if (section != null && seen.add(key)) {
          result.add(PromptTopLevelItem.section(section));
        }
      }
    }
    for (final s in sectionsInCategory(null)) {
      final key = topLevelSectionKey(s);
      if (seen.add(key)) result.add(PromptTopLevelItem.section(s));
    }
    for (final c in sortedCategories) {
      final key = topLevelCategoryKey(c.id);
      if (seen.add(key)) result.add(PromptTopLevelItem.category(c));
    }
    return result;
  }

  /// Update a section
  PromptManagerConfig updateSection(PromptSection updatedSection) {
    final newSections = sections.map((s) {
      if (s.type == updatedSection.type) {
        return updatedSection;
      }
      return s;
    }).toList();
    return copyWith(sections: newSections);
  }

  /// Toggle a section's enabled state
  PromptManagerConfig toggleSection(PromptSectionType type) {
    final newSections = sections.map((s) {
      if (s.type == type) {
        return s.copyWith(enabled: !s.enabled);
      }
      return s;
    }).toList();
    return copyWith(sections: newSections);
  }

  /// Reorder sections
  PromptManagerConfig reorder(int oldIndex, int newIndex) {
    final sorted = sortedSections;
    final item = sorted.removeAt(oldIndex);
    sorted.insert(newIndex, item);
    
    // Update order values
    final newSections = <PromptSection>[];
    for (var i = 0; i < sorted.length; i++) {
      newSections.add(sorted[i].copyWith(order: i));
    }
    return copyWith(sections: newSections);
  }

  /// Put built-in sections back into the default order.
  ///
  /// Custom prompts and section types unknown to the default config keep their
  /// current slots — only the built-in entries swap places.
  PromptManagerConfig restoreDefaultOrder() {
    final defaults = PromptManagerConfig.defaultConfig().sortedSections;
    final rank = <PromptSectionType, int>{
      for (var i = 0; i < defaults.length; i++) defaults[i].type: i,
    };
    final sorted = sortedSections;
    final slots = <int>[];
    final builtIns = <PromptSection>[];
    for (var i = 0; i < sorted.length; i++) {
      final section = sorted[i];
      if (section.isCustom || !rank.containsKey(section.type)) continue;
      slots.add(i);
      builtIns.add(section);
    }
    if (slots.length < 2) return this;
    builtIns.sort((a, b) => rank[a.type]!.compareTo(rank[b.type]!));
    final reordered = List<PromptSection>.from(sorted);
    for (var i = 0; i < slots.length; i++) {
      reordered[slots[i]] = builtIns[i];
    }
    return copyWith(
      sections: [
        for (var i = 0; i < reordered.length; i++)
          reordered[i].copyWith(order: i),
      ],
    );
  }

  Map<String, dynamic> toJson() => {
        'sections': sections.map((s) => s.toJson()).toList(),
        if (categories.isNotEmpty)
          'categories': categories.map((c) => c.toJson()).toList(),
        if (topLevelOrder.isNotEmpty) 'topLevelOrder': topLevelOrder,
      };

  factory PromptManagerConfig.fromJson(Map<String, dynamic> json) {
    final sectionsJson = json['sections'] as List<dynamic>?;
    if (sectionsJson == null || sectionsJson.isEmpty) {
      return PromptManagerConfig.defaultConfig();
    }
    final categoriesJson = json['categories'] as List<dynamic>?;
    final topRaw = json['topLevelOrder'] as List<dynamic>?;
    return PromptManagerConfig(
      sections: sectionsJson
          .map((s) => PromptSection.fromJson(s as Map<String, dynamic>))
          .toList(),
      categories: categoriesJson == null
          ? const <PromptCategory>[]
          : categoriesJson
              .map((c) => PromptCategory.fromJson(c as Map<String, dynamic>))
              .where((c) => c.id.isNotEmpty)
              .toList(growable: false),
      topLevelOrder: topRaw == null
          ? const <String>[]
          : [
              for (final e in topRaw)
                if (e is String && e.isNotEmpty) e,
            ],
    );
  }

  /// Merge AnoWorld export extras (`_anoworld`) onto a flat ST-imported config.
  PromptManagerConfig withAnoWorldMeta(Map<String, dynamic>? anoworld) {
    if (anoworld == null || anoworld.isEmpty) return this;
    final catsRaw = anoworld['promptCategories'] as List<dynamic>?;
    final byIdent = anoworld['promptCategoryById'];
    final topRaw = anoworld['topLevelOrder'] as List<dynamic>?;
    final cats = catsRaw == null
        ? categories
        : catsRaw
            .map((c) => PromptCategory.fromJson(c as Map<String, dynamic>))
            .where((c) => c.id.isNotEmpty)
            .toList(growable: false);
    final top = topRaw == null
        ? topLevelOrder
        : [
            for (final e in topRaw)
              if (e is String && e.isNotEmpty) e,
          ];
    if (byIdent is! Map) {
      return copyWith(categories: cats, topLevelOrder: top);
    }
    final map = <String, String>{
      for (final e in byIdent.entries)
        if (e.key is String && e.value is String && (e.value as String).isNotEmpty)
          e.key as String: e.value as String,
    };
    if (map.isEmpty) return copyWith(categories: cats, topLevelOrder: top);
    return copyWith(
      categories: cats,
      topLevelOrder: top,
      sections: [
        for (final s in sections)
          () {
            final key = s.identifier;
            if (key == null || key.isEmpty || !map.containsKey(key)) return s;
            return s.copyWith(categoryId: map[key]);
          }(),
      ],
    );
  }

  /// Parse from SillyTavern preset format
  /// SillyTavern uses prompts array for custom prompts and prompt_order for ordering
  factory PromptManagerConfig.fromSillyTavernJson(Map<String, dynamic> json) {
    // Map SillyTavern identifiers to our section types
    final identifierMap = <String, PromptSectionType>{
      'main': PromptSectionType.systemPrompt,
      'personaDescription': PromptSectionType.persona,
      'charDescription': PromptSectionType.characterDescription,
      'charPersonality': PromptSectionType.characterPersonality,
      'scenario': PromptSectionType.characterScenario,
      'dialogueExamples': PromptSectionType.exampleMessages,
      'worldInfoBefore': PromptSectionType.worldInfo,
      'worldInfoAfter': PromptSectionType.worldInfoAfter,
      'authorNote': PromptSectionType.authorNote,
      'jailbreak': PromptSectionType.postHistoryInstructions,
      'nsfw': PromptSectionType.nsfw,
      'chatHistory': PromptSectionType.chatHistory,
      'enhanceDefinitions': PromptSectionType.enhanceDefinitions,
    };

    // Parse custom prompts from the prompts array
    final promptsArray = json['prompts'] as List<dynamic>?;
    final customPrompts = <String, PromptSection>{};
    
    if (promptsArray != null) {
      for (final prompt in promptsArray) {
        if (prompt is Map<String, dynamic>) {
          final identifier = prompt['identifier'] as String?;
          final name = prompt['name'] as String? ?? 'Custom Prompt';
          final content = prompt['content'] as String? ?? '';
          final role = prompt['role'] as String? ?? 'system';
          final injectionPosition = prompt['injection_position'] as int?;
          final injectionDepth = prompt['injection_depth'] as int?;
          
          if (identifier != null) {
            // Check if this is a known identifier or a custom one
            final type = identifierMap[identifier] ?? PromptSectionType.custom;
            customPrompts[identifier] = PromptSection(
              type: type,
              name: name,
              enabled: true,
              order: 0, // Will be set later based on prompt_order
              content: content,
              identifier: identifier,
              role: role,
              injectionPosition: injectionPosition,
              injectionDepth: injectionDepth,
            );
          }
        }
      }
    }

    // Get prompt_order - prefer character_id 100001 (custom) over 100000 (default)
    final promptOrder = json['prompt_order'] as List<dynamic>?;
    List<dynamic>? orderList;
    
    if (promptOrder != null) {
      // First try to find character_id 100001 (custom order with all prompts)
      for (final entry in promptOrder) {
        if (entry is Map<String, dynamic>) {
          final charId = entry['character_id'];
          if (charId == 100001 && entry['order'] != null) {
            orderList = entry['order'] as List<dynamic>;
            break;
          }
        }
      }
      // Fall back to character_id 100000 (default order)
      if (orderList == null) {
        for (final entry in promptOrder) {
          if (entry is Map<String, dynamic> && entry['order'] != null) {
            orderList = entry['order'] as List<dynamic>;
            break;
          }
        }
      }
    }

    // Build sections from SillyTavern order (or prompts array when order missing)
    final sections = <PromptSection>[];
    final seenIdentifiers = <String>{};
    var order = 0;

    if (orderList != null) {
      for (final item in orderList) {
        if (item is Map<String, dynamic>) {
          final identifier = item['identifier'] as String?;
          final enabled = item['enabled'] as bool? ?? true;

          if (identifier == null || seenIdentifiers.contains(identifier)) {
            continue;
          }
          seenIdentifiers.add(identifier);

          // Check if we have a custom prompt with this identifier
          if (customPrompts.containsKey(identifier)) {
            final customPrompt = customPrompts[identifier]!;
            sections.add(customPrompt.copyWith(
              enabled: enabled,
              order: order++,
            ));
          } else if (identifierMap.containsKey(identifier)) {
            // It's a known built-in type
            final type = identifierMap[identifier]!;
            sections.add(PromptSection(
              type: type,
              name: PromptSection.getDisplayName(type),
              enabled: enabled,
              order: order++,
              identifier: identifier,
            ));
          } else {
            // Custom prompt not in the prompts array (UUID identifier)
            sections.add(PromptSection(
              type: PromptSectionType.custom,
              name: 'Custom Prompt',
              enabled: enabled,
              order: order++,
              identifier: identifier,
              content: '',
            ));
          }
        }
      }
    } else if (customPrompts.isNotEmpty) {
      for (final entry in customPrompts.entries) {
        seenIdentifiers.add(entry.key);
        sections.add(entry.value.copyWith(order: order++));
      }
    } else {
      return PromptManagerConfig.defaultConfig();
    }

    // Add any custom prompts that weren't in the order list
    for (final entry in customPrompts.entries) {
      if (!seenIdentifiers.contains(entry.key)) {
        sections.add(entry.value.copyWith(order: order++));
      }
    }

    // Add any missing built-in section types with default values (disabled)
    // Order: worldInfo before chat, chatHistory, worldInfoAfter after chat
    final builtInTypes = [
      PromptSectionType.systemPrompt,
      PromptSectionType.persona,
      PromptSectionType.characterDescription,
      PromptSectionType.characterPersonality,
      PromptSectionType.characterScenario,
      PromptSectionType.exampleMessages,
      PromptSectionType.worldInfo,
      PromptSectionType.authorNote,
      PromptSectionType.chatHistory,
      PromptSectionType.worldInfoAfter,
      PromptSectionType.postHistoryInstructions,
    ];
    
    for (final type in builtInTypes) {
      final hasType = sections.any((s) => s.type == type && !s.isCustom);
      if (!hasType) {
        sections.add(PromptSection(
          type: type,
          name: PromptSection.getDisplayName(type),
          enabled: false,
          order: order++,
        ));
      }
    }

    return PromptManagerConfig(sections: sections);
  }

  /// Toggle a section's enabled state by index (for custom prompts)
  PromptManagerConfig toggleSectionByIndex(int index) {
    final sorted = sortedSections;
    if (index < 0 || index >= sorted.length) return this;
    
    final section = sorted[index];
    final newSections = sections.map((s) {
      if (s.identifier == section.identifier && s.type == section.type && s.name == section.name) {
        return s.copyWith(enabled: !s.enabled);
      }
      return s;
    }).toList();
    return copyWith(sections: newSections);
  }

  /// Update a section by index
  PromptManagerConfig updateSectionByIndex(int index, PromptSection updatedSection) {
    final sorted = sortedSections;
    if (index < 0 || index >= sorted.length) return this;
    
    final oldSection = sorted[index];
    final newSections = sections.map((s) {
      if (s.identifier == oldSection.identifier && s.type == oldSection.type && s.name == oldSection.name) {
        return updatedSection;
      }
      return s;
    }).toList();
    return copyWith(sections: newSections);
  }

  bool _sameSection(PromptSection a, PromptSection b) {
    return a.identifier == b.identifier &&
        a.type == b.type &&
        a.name == b.name &&
        a.order == b.order;
  }

  /// Create or replace a category by id.
  PromptManagerConfig upsertCategory({
    required String id,
    required String name,
    int? order,
  }) {
    final trimmedId = id.trim();
    final trimmedName = name.trim();
    if (trimmedId.isEmpty || trimmedName.isEmpty) return this;
    final existing = categories.where((c) => c.id == trimmedId).toList();
    if (existing.isEmpty) {
      final nextOrder = order ??
          (categories.isEmpty
              ? 0
              : categories.map((c) => c.order).reduce((a, b) => a > b ? a : b) +
                  1);
      return copyWith(
        categories: [
          ...categories,
          PromptCategory(id: trimmedId, name: trimmedName, order: nextOrder),
        ],
      )._ensureTopLevelKey(topLevelCategoryKey(trimmedId));
    }
    return copyWith(
      categories: [
        for (final c in categories)
          if (c.id == trimmedId)
            c.copyWith(name: trimmedName, order: order ?? c.order)
          else
            c,
      ],
    );
  }

  PromptManagerConfig renameCategory(String id, String name) {
    return upsertCategory(id: id, name: name);
  }

  /// Remove a category and clear [PromptSection.categoryId] on its members.
  PromptManagerConfig deleteCategory(String id) {
    if (!categories.any((c) => c.id == id)) return this;
    return copyWith(
      categories: [for (final c in categories) if (c.id != id) c],
      sections: [
        for (final s in sections)
          if (s.categoryId == id) s.copyWith(clearCategoryId: true) else s,
      ],
    )._removeTopLevelKey(topLevelCategoryKey(id));
  }

  /// Assign [categoryId] to the section at sorted [index] (null clears).
  PromptManagerConfig setSectionCategory(int index, String? categoryId) {
    final sorted = sortedSections;
    if (index < 0 || index >= sorted.length) return this;
    final target = sorted[index];
    final nextId = categoryId?.trim();
    final cleared = nextId == null || nextId.isEmpty;
    if (!cleared && !categories.any((c) => c.id == nextId)) return this;
    final layoutKey = topLevelSectionKey(target);
    var next = copyWith(
      sections: [
        for (final s in sections)
          if (_sameSection(s, target))
            cleared
                ? s.copyWith(clearCategoryId: true)
                : s.copyWith(categoryId: nextId)
          else
            s,
      ],
    );
    if (cleared) {
      next = next._ensureTopLevelKey(layoutKey);
    } else {
      next = next._removeTopLevelKey(layoutKey);
    }
    return next;
  }

  /// Reorder categories by [sortedCategories] indices; rewrites [PromptCategory.order].
  PromptManagerConfig reorderCategories(int oldIndex, int newIndex) {
    final sorted = sortedCategories;
    if (oldIndex < 0 ||
        oldIndex >= sorted.length ||
        newIndex < 0 ||
        newIndex >= sorted.length ||
        oldIndex == newIndex) {
      return this;
    }
    final next = List<PromptCategory>.from(sorted);
    final item = next.removeAt(oldIndex);
    next.insert(newIndex, item);
    return copyWith(
      categories: [
        for (var i = 0; i < next.length; i++) next[i].copyWith(order: i),
      ],
    );
  }

  /// Reorder mixed top-level rows (uncategorized sections + category blocks).
  PromptManagerConfig reorderTopLevel(int oldIndex, int newIndex) {
    final items = List<PromptTopLevelItem>.from(topLevelItems);
    if (oldIndex < 0 ||
        oldIndex >= items.length ||
        newIndex < 0 ||
        newIndex >= items.length ||
        oldIndex == newIndex) {
      return this;
    }
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    final keys = [for (final e in items) e.layoutKey];
    return copyWith(topLevelOrder: keys)._syncUncategorizedOrderFromTopLevel();
  }

  /// Keep uncategorized [PromptSection.order] aligned with [topLevelItems].
  PromptManagerConfig _syncUncategorizedOrderFromTopLevel() {
    final desired = <PromptSection>[
      for (final item in topLevelItems)
        if (item.section != null) item.section!,
    ];
    final sorted = List<PromptSection>.from(sortedSections);
    final slots = <int>[];
    for (var i = 0; i < sorted.length; i++) {
      final id = sorted[i].categoryId;
      if (id == null || id.isEmpty) slots.add(i);
    }
    if (slots.length != desired.length) return this;
    final rebuilt = List<PromptSection>.from(sorted);
    for (var i = 0; i < slots.length; i++) {
      rebuilt[slots[i]] = desired[i];
    }
    return _reindexed(rebuilt);
  }

  PromptManagerConfig _ensureTopLevelKey(String key, {int? insertAt}) {
    final keys = List<String>.from(
      topLevelOrder.isEmpty ? defaultTopLevelOrder : topLevelOrder,
    );
    if (keys.contains(key)) return copyWith(topLevelOrder: keys);
    if (insertAt == null || insertAt < 0 || insertAt > keys.length) {
      keys.add(key);
    } else {
      keys.insert(insertAt, key);
    }
    return copyWith(topLevelOrder: keys);
  }

  PromptManagerConfig _removeTopLevelKey(String key) {
    if (topLevelOrder.isEmpty) return this;
    final keys = [for (final k in topLevelOrder) if (k != key) k];
    if (keys.length == topLevelOrder.length) return this;
    return copyWith(topLevelOrder: keys);
  }

  /// Move a section into [categoryId] (null = uncategorized) and place it after
  /// the last member of that group in global order.
  PromptManagerConfig moveSectionToCategory(
    int sortedIndex,
    String? categoryId,
  ) {
    final sorted = List<PromptSection>.from(sortedSections);
    if (sortedIndex < 0 || sortedIndex >= sorted.length) return this;
    final nextId = categoryId?.trim();
    final cleared = nextId == null || nextId.isEmpty;
    if (!cleared && !categories.any((c) => c.id == nextId)) return this;

    var target = sorted.removeAt(sortedIndex);
    final layoutKey = topLevelSectionKey(target);
    target = cleared
        ? target.copyWith(clearCategoryId: true)
        : target.copyWith(categoryId: nextId);

    var insertAt = sorted.length;
    for (var i = sorted.length - 1; i >= 0; i--) {
      final id = sorted[i].categoryId;
      final uncategorized = id == null || id.isEmpty;
      final match = cleared ? uncategorized : id == nextId;
      if (match) {
        insertAt = i + 1;
        break;
      }
    }
    sorted.insert(insertAt, target);
    var next = _reindexed(sorted);
    if (cleared) {
      next = next._ensureTopLevelKey(layoutKey);
    } else {
      next = next._removeTopLevelKey(layoutKey);
    }
    return next;
  }

  /// Reorder members of one category (or uncategorized when [categoryId] is null).
  PromptManagerConfig reorderInCategory(
    String? categoryId,
    int oldIndex,
    int newIndex,
  ) {
    final sorted = sortedSections;
    final slots = <int>[];
    for (var i = 0; i < sorted.length; i++) {
      final id = sorted[i].categoryId;
      final uncategorized = id == null || id.isEmpty;
      final match = categoryId == null || categoryId.isEmpty
          ? uncategorized
          : id == categoryId;
      if (match) slots.add(i);
    }
    if (oldIndex < 0 ||
        oldIndex >= slots.length ||
        newIndex < 0 ||
        newIndex >= slots.length ||
        oldIndex == newIndex) {
      return this;
    }
    final members = [for (final i in slots) sorted[i]];
    final item = members.removeAt(oldIndex);
    members.insert(newIndex, item);
    final rebuilt = List<PromptSection>.from(sorted);
    for (var i = 0; i < slots.length; i++) {
      rebuilt[slots[i]] = members[i];
    }
    return _reindexed(rebuilt);
  }

  /// Append a custom prompt section (caller supplies a unique identifier).
  PromptManagerConfig addCustomSection({
    required String name,
    required String identifier,
    String content = '',
    String role = 'system',
    bool enabled = true,
    String? categoryId,
  }) {
    final nextOrder = sections.isEmpty
        ? 0
        : sections.map((s) => s.order).reduce((a, b) => a > b ? a : b) + 1;
    final cat = categoryId?.trim();
    final section = PromptSection(
      type: PromptSectionType.custom,
      name: name,
      enabled: enabled,
      order: nextOrder,
      content: content,
      identifier: identifier,
      role: role,
      categoryId: (cat == null || cat.isEmpty) ? null : cat,
    );
    var next = copyWith(sections: [...sections, section]);
    if (cat == null || cat.isEmpty) {
      next = next._ensureTopLevelKey(topLevelSectionKey(section));
    }
    return next;
  }

  /// Remove a section by sorted index. Only custom sections can be removed.
  PromptManagerConfig removeSectionAt(int index) {
    final sorted = sortedSections;
    if (index < 0 || index >= sorted.length) return this;
    final target = sorted[index];
    if (!target.isCustom) return this;

    final remaining = <PromptSection>[];
    for (final s in sorted) {
      if (_sameSection(s, target)) continue;
      remaining.add(s);
    }
    return _reindexed(remaining)
        ._removeTopLevelKey(topLevelSectionKey(target));
  }

  /// Remove custom sections by identifier. Built-in sections are never touched.
  PromptManagerConfig removeCustomSections(Iterable<String> identifiers) {
    final ids = identifiers.toSet();
    if (ids.isEmpty) return this;
    final sorted = sortedSections;
    final removedKeys = <String>[
      for (final s in sorted)
        if (s.isCustom && ids.contains(s.identifier)) topLevelSectionKey(s),
    ];
    final remaining = sorted
        .where((s) => !(s.isCustom && ids.contains(s.identifier)))
        .toList(growable: false);
    if (remaining.length == sorted.length) return this;
    var next = _reindexed(remaining);
    for (final key in removedKeys) {
      next = next._removeTopLevelKey(key);
    }
    return next;
  }

  PromptManagerConfig _reindexed(List<PromptSection> remaining) {
    return copyWith(
      sections: [
        for (var i = 0; i < remaining.length; i++)
          remaining[i].copyWith(order: i),
      ],
    );
  }

  /// Duplicate a section at sorted index into a new custom entry.
  PromptManagerConfig duplicateSectionAt(
    int index, {
    required String newIdentifier,
    String copySuffix = ' copy',
  }) {
    final sorted = sortedSections;
    if (index < 0 || index >= sorted.length) return this;
    final source = sorted[index];

    final duplicate = PromptSection(
      type: PromptSectionType.custom,
      name: '${source.name}$copySuffix',
      enabled: source.enabled,
      order: source.order + 1,
      content: source.content ?? source.effectiveContent,
      identifier: newIdentifier,
      role: source.role ?? 'system',
      injectionPosition: source.injectionPosition,
      injectionDepth: source.injectionDepth,
      categoryId: source.categoryId,
    );

    final rebuilt = <PromptSection>[];
    for (var i = 0; i < sorted.length; i++) {
      final s = sorted[i];
      if (i <= index) {
        rebuilt.add(s.copyWith(order: rebuilt.length));
      }
      if (i == index) {
        rebuilt.add(duplicate.copyWith(order: rebuilt.length));
      }
      if (i > index) {
        rebuilt.add(s.copyWith(order: rebuilt.length));
      }
    }
    return copyWith(sections: rebuilt);
  }
}

/// A named preset for prompt manager configuration
class PromptManagerPreset {
  final String id;
  final String name;
  final String? description;
  final PromptManagerConfig config;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isBuiltIn;

  const PromptManagerPreset({
    required this.id,
    required this.name,
    this.description,
    required this.config,
    required this.createdAt,
    required this.updatedAt,
    this.isBuiltIn = false,
  });

  PromptManagerPreset copyWith({
    String? id,
    String? name,
    String? description,
    PromptManagerConfig? config,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isBuiltIn,
  }) {
    return PromptManagerPreset(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      config: config ?? this.config,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    );
  }

  /// Export format for sharing (compatible with SillyTavern style)
  Map<String, dynamic> toExportJson() => {
        'name': name,
        'description': description,
        'version': 1,
        'format': 'native_tavern_prompt_preset',
        'sections': config.sections.map((s) => s.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  /// Full JSON for storage
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'config': config.toJson(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'isBuiltIn': isBuiltIn,
      };

  factory PromptManagerPreset.fromJson(Map<String, dynamic> json) {
    return PromptManagerPreset(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      config: PromptManagerConfig.fromJson(json['config'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
    );
  }

  /// Import from export format (NT sections or SillyTavern prompts/prompt_order)
  factory PromptManagerPreset.fromExportJson(Map<String, dynamic> json, String id) {
    final PromptManagerConfig config;
    if (json.containsKey('prompts') || json.containsKey('prompt_order')) {
      config = PromptManagerConfig.fromSillyTavernJson(json);
    } else {
      final sectionsJson = json['sections'] as List<dynamic>?;
      config = sectionsJson != null && sectionsJson.isNotEmpty
          ? PromptManagerConfig(
              sections: sectionsJson
                  .map((s) => PromptSection.fromJson(s as Map<String, dynamic>))
                  .toList(),
            )
          : PromptManagerConfig.defaultConfig();
    }

    return PromptManagerPreset(
      id: id,
      name: json['name'] as String? ??
          json['preset_name'] as String? ??
          'Imported Preset',
      description: json['description'] as String?,
      config: config,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: DateTime.now(),
      isBuiltIn: false,
    );
  }
}

/// Built-in presets
class BuiltInPromptPresets {
  static final defaultPreset = PromptManagerPreset(
    id: 'default',
    name: 'Default',
    description: 'Standard prompt ordering',
    config: PromptManagerConfig.defaultConfig(),
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 1),
    isBuiltIn: true,
  );

  static final characterFocused = PromptManagerPreset(
    id: 'character_focused',
    name: 'Character Focused',
    description: 'Prioritizes character information',
    config: PromptManagerConfig(
      sections: [
        const PromptSection(
          type: PromptSectionType.characterDescription,
          name: 'Character Description',
          order: 0,
        ),
        const PromptSection(
          type: PromptSectionType.characterPersonality,
          name: 'Character Personality',
          order: 1,
        ),
        const PromptSection(
          type: PromptSectionType.characterScenario,
          name: 'Scenario',
          order: 2,
        ),
        const PromptSection(
          type: PromptSectionType.systemPrompt,
          name: 'System Prompt',
          order: 3,
        ),
        const PromptSection(
          type: PromptSectionType.persona,
          name: 'User Persona',
          order: 4,
        ),
        const PromptSection(
          type: PromptSectionType.worldInfo,
          name: 'World Info / Lorebook',
          order: 5,
        ),
        const PromptSection(
          type: PromptSectionType.exampleMessages,
          name: 'Example Messages',
          order: 6,
        ),
        const PromptSection(
          type: PromptSectionType.authorNote,
          name: "Author's Note",
          order: 7,
        ),
        const PromptSection(
          type: PromptSectionType.postHistoryInstructions,
          name: 'Post-History Instructions',
          order: 8,
        ),
      ],
    ),
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 1),
    isBuiltIn: true,
  );

  static final worldInfoFirst = PromptManagerPreset(
    id: 'world_info_first',
    name: 'World Info First',
    description: 'Prioritizes world building and lore',
    config: PromptManagerConfig(
      sections: [
        const PromptSection(
          type: PromptSectionType.worldInfo,
          name: 'World Info / Lorebook',
          order: 0,
        ),
        const PromptSection(
          type: PromptSectionType.systemPrompt,
          name: 'System Prompt',
          order: 1,
        ),
        const PromptSection(
          type: PromptSectionType.characterDescription,
          name: 'Character Description',
          order: 2,
        ),
        const PromptSection(
          type: PromptSectionType.characterPersonality,
          name: 'Character Personality',
          order: 3,
        ),
        const PromptSection(
          type: PromptSectionType.characterScenario,
          name: 'Scenario',
          order: 4,
        ),
        const PromptSection(
          type: PromptSectionType.persona,
          name: 'User Persona',
          order: 5,
        ),
        const PromptSection(
          type: PromptSectionType.exampleMessages,
          name: 'Example Messages',
          order: 6,
        ),
        const PromptSection(
          type: PromptSectionType.authorNote,
          name: "Author's Note",
          order: 7,
        ),
        const PromptSection(
          type: PromptSectionType.postHistoryInstructions,
          name: 'Post-History Instructions',
          order: 8,
        ),
      ],
    ),
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 1),
    isBuiltIn: true,
  );

  static final minimal = PromptManagerPreset(
    id: 'minimal',
    name: 'Minimal',
    description: 'Only essential prompts enabled',
    config: PromptManagerConfig(
      sections: [
        const PromptSection(
          type: PromptSectionType.systemPrompt,
          name: 'System Prompt',
          order: 0,
          enabled: true,
        ),
        const PromptSection(
          type: PromptSectionType.characterDescription,
          name: 'Character Description',
          order: 1,
          enabled: true,
        ),
        const PromptSection(
          type: PromptSectionType.characterPersonality,
          name: 'Character Personality',
          order: 2,
          enabled: false,
        ),
        const PromptSection(
          type: PromptSectionType.characterScenario,
          name: 'Scenario',
          order: 3,
          enabled: false,
        ),
        const PromptSection(
          type: PromptSectionType.persona,
          name: 'User Persona',
          order: 4,
          enabled: false,
        ),
        const PromptSection(
          type: PromptSectionType.worldInfo,
          name: 'World Info / Lorebook',
          order: 5,
          enabled: false,
        ),
        const PromptSection(
          type: PromptSectionType.exampleMessages,
          name: 'Example Messages',
          order: 6,
          enabled: false,
        ),
        const PromptSection(
          type: PromptSectionType.authorNote,
          name: "Author's Note",
          order: 7,
          enabled: false,
        ),
        const PromptSection(
          type: PromptSectionType.postHistoryInstructions,
          name: 'Post-History Instructions',
          order: 8,
          enabled: false,
        ),
      ],
    ),
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 1),
    isBuiltIn: true,
  );

  static final List<PromptManagerPreset> all = [
    defaultPreset,
    characterFocused,
    worldInfoFirst,
    minimal,
  ];
}