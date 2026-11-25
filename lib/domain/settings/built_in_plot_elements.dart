import 'package:anoworld/domain/models/plot_element.dart';
import 'package:anoworld/domain/models/plot_element_category.dart';
import 'package:anoworld/domain/settings/seed_catalog.dart';

/// Built-in library categories (from `assets/seed/plot_elements.json`).
abstract final class BuiltInPlotElementCategories {
  static const dailyId = 'pe_cat_daily';
  static const affectionId = 'pe_cat_affection';
  static const conflictId = 'pe_cat_conflict';
  static const crisisId = 'pe_cat_crisis';
  static const mysteryId = 'pe_cat_mystery';
  static const psycheId = 'pe_cat_psyche';
  static const uncannyId = 'pe_cat_uncanny';

  static List<PlotElementCategory> get all => SeedCatalog.categories;

  static Map<String, PlotElementCategory> get byId => SeedCatalog.categoriesById;

  static bool containsId(String id) => byId.containsKey(id);

  static PlotElementCategory get daily => byId[dailyId]!;
  static PlotElementCategory get affection => byId[affectionId]!;
  static PlotElementCategory get conflict => byId[conflictId]!;
  static PlotElementCategory get crisis => byId[crisisId]!;
  static PlotElementCategory get mystery => byId[mysteryId]!;
  static PlotElementCategory get psyche => byId[psycheId]!;
  static PlotElementCategory get uncanny => byId[uncannyId]!;
}

/// Factory seed list for the global plot-element catalog
/// (from `assets/seed/plot_elements.json`).
abstract final class BuiltInPlotElements {
  static List<PlotElement> get all => SeedCatalog.elements;

  static Map<String, PlotElement> get byId => SeedCatalog.elementsById;

  static bool containsId(String id) => byId.containsKey(id);
}
