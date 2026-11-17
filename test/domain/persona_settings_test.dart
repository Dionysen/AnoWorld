import 'package:anoworld/data/settings/memory_settings_repository.dart';
import 'package:anoworld/domain/settings/persona_settings.dart';
import 'package:anoworld/foundation/persona/user_persona.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ensureDefault seeds builtin persona', () {
    final settings = const PersonaSettings().ensureDefault();
    expect(settings.personas, hasLength(1));
    expect(settings.personas.first.isDefault, isTrue);
    expect(settings.activePersona, isNotNull);
  });

  test('memory repository round-trips personas', () async {
    final repo = MemorySettingsRepository();
    final custom = UserPersona(
      id: 'p1',
      name: '旅人',
      description: '独行',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    final settings = PersonaSettings(
      personas: [UserPersona.builtinDefault(), custom],
      activePersonaId: 'p1',
    );
    await repo.savePersonas(settings);
    final loaded = await repo.loadPersonas();
    expect(loaded.activePersona?.name, '旅人');
  });
}