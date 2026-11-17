/// Portable user persona (SillyTavern User Persona subset).
class UserPersona {
  const UserPersona({
    required this.id,
    required this.name,
    this.description = '',
    this.isDefault = false,
    this.systemPromptOverride,
    this.postHistoryInstructions,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String description;
  final bool isDefault;
  final String? systemPromptOverride;
  final String? postHistoryInstructions;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory UserPersona.builtinDefault({DateTime? now}) {
    final stamp = now ?? DateTime.now().toUtc();
    return UserPersona(
      id: 'default',
      name: 'User',
      description: '',
      isDefault: true,
      createdAt: stamp,
      updatedAt: stamp,
    );
  }

  UserPersona copyWith({
    String? id,
    String? name,
    String? description,
    bool? isDefault,
    String? systemPromptOverride,
    String? postHistoryInstructions,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearSystemPromptOverride = false,
    bool clearPostHistoryInstructions = false,
  }) {
    return UserPersona(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isDefault: isDefault ?? this.isDefault,
      systemPromptOverride: clearSystemPromptOverride
          ? null
          : (systemPromptOverride ?? this.systemPromptOverride),
      postHistoryInstructions: clearPostHistoryInstructions
          ? null
          : (postHistoryInstructions ?? this.postHistoryInstructions),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'description': description,
        'isDefault': isDefault,
        if (systemPromptOverride != null)
          'systemPromptOverride': systemPromptOverride,
        if (postHistoryInstructions != null)
          'postHistoryInstructions': postHistoryInstructions,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory UserPersona.fromJson(Map<String, dynamic> json) {
    return UserPersona(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'User',
      description: json['description'] as String? ?? '',
      isDefault: json['isDefault'] as bool? ?? false,
      systemPromptOverride: json['systemPromptOverride'] as String?,
      postHistoryInstructions: json['postHistoryInstructions'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}