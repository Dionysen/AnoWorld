import 'package:flutter/widgets.dart';

/// Base contract for translated UI copy.
///
/// Apps subclass this with their own product copy; foundation widgets only read
/// the generic chrome words declared here, so this layer stays free of product
/// wording and can be lifted into another project as-is.
abstract class AppLocalizations {
  const AppLocalizations();

  /// Locale served by this translation, e.g. `Locale('zh')`.
  Locale get locale;

  /// Name of the language written in the language itself (for a picker).
  String get languageLabel;

  /// Whether this translation can serve [other].
  bool matches(Locale other) => other.languageCode == locale.languageCode;

  // Chrome shared by foundation widgets.

  String get cancel;
  String get save;
  String get delete;
  String get more;
  String get loading;
  String get retry;
  String get keepEditing;
  String get discard;
  String get discardEditsTitle;
  String get discardEditsDetail;
}

/// English chrome used when no app translation is registered (bare widgets in
/// isolation, e.g. a foundation test without the app delegate).
class DefaultAppLocalizations extends AppLocalizations {
  const DefaultAppLocalizations();

  static const DefaultAppLocalizations instance = DefaultAppLocalizations();

  @override
  Locale get locale => const Locale('en');

  @override
  String get languageLabel => 'English';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get more => 'More';

  @override
  String get loading => 'Loading…';

  @override
  String get retry => 'Retry';

  @override
  String get keepEditing => 'Keep editing';

  @override
  String get discard => 'Discard';

  @override
  String get discardEditsTitle => 'Discard changes?';

  @override
  String get discardEditsDetail => 'Unsaved edits will be lost';
}

/// Registers [T] translations with Flutter's localization system.
///
/// [translations] is the list of supported languages; [fallback] serves any
/// locale that no translation matches, so there is never a missing-copy crash.
class AppLocalizationsDelegate<T extends AppLocalizations>
    extends LocalizationsDelegate<T> {
  const AppLocalizationsDelegate({
    required this.translations,
    required this.fallback,
  });

  final List<T> translations;
  final T fallback;

  /// Best translation for [locale]; [fallback] when nothing matches.
  T resolve(Locale? locale) {
    if (locale == null) return fallback;
    for (final translation in translations) {
      if (translation.matches(locale)) return translation;
    }
    return fallback;
  }

  @override
  bool isSupported(Locale locale) =>
      translations.any((translation) => translation.matches(locale));

  @override
  Future<T> load(Locale locale) async => resolve(locale);

  @override
  bool shouldReload(covariant LocalizationsDelegate<T> old) => false;
}

/// Generic chrome words; foundation widgets read these, never product copy.
extension AppLocalizationsContext on BuildContext {
  AppLocalizations get ui =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      DefaultAppLocalizations.instance;
}
