import 'package:anoworld/domain/models/json_map.dart';
import 'package:anoworld/foundation/persona/user_persona.dart';

class PersonaSettings {
  const PersonaSettings({
    this.personas = const <UserPersona>[],
    this.activePersonaId,
  });

  final List<UserPersona> personas;
  final String? activePersonaId;

  UserPersona? get activePersona {
    if (activePersonaId != null) {
      for (final p in personas) {
        if (p.id == activePersonaId) return p;
      }
    }
    for (final p in personas) {
      if (p.isDefault) return p;
    }
    return personas.isEmpty ? null : personas.first;
  }

  PersonaSettings ensureDefault() {
    if (personas.isNotEmpty) return this;
    return PersonaSettings(
      personas: <UserPersona>[UserPersona.builtinDefault()],
      activePersonaId: 'default',
    );
  }

  PersonaSettings copyWith({
    List<UserPersona>? personas,
    String? activePersonaId,
    bool clearActive = false,
  }) {
    return PersonaSettings(
      personas: personas ?? this.personas,
      activePersonaId:
          clearActive ? null : (activePersonaId ?? this.activePersonaId),
    );
  }

  PersonaSettings withPersonas(List<UserPersona> next) {
    var active = activePersonaId;
    if (active != null && !next.any((p) => p.id == active)) {
      active = next.where((p) => p.isDefault).map((p) => p.id).firstOrNull ??
          next.firstOrNull?.id;
    }
    return copyWith(personas: next, activePersonaId: active);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'personas': personas.map((p) => p.toJson()).toList(growable: false),
        if (activePersonaId != null) 'activePersonaId': activePersonaId,
      };

  factory PersonaSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PersonaSettings();
    final list = json.optionalList('personas');
    final personas = <UserPersona>[
      for (final item in list)
        UserPersona.fromJson(asJsonMap(item, path: 'personas[]')),
    ];
    return PersonaSettings(
      personas: personas,
      activePersonaId: json.optionalString('activePersonaId'),
    ).ensureDefault();
  }
}