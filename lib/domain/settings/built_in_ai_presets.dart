import 'package:anoworld/domain/settings/seed_catalog.dart';
import 'package:anoworld/foundation/ai/st_ai_preset.dart';

/// Built-in AI presets (from `assets/seed/ai_presets.json`).
abstract final class BuiltInAIPresets {
  static AIPreset get defaultPreset => SeedCatalog.defaultPreset;

  static List<AIPreset> get all => SeedCatalog.presets;

  static AIPreset? byId(String id) => SeedCatalog.presetsById[id];

  static bool containsId(String id) => SeedCatalog.presetsById.containsKey(id);
}
