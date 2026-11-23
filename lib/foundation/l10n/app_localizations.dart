import 'package:flutter/foundation.dart' show SynchronousFuture;
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

  /// Generic verbs and placeholders the reusable widgets show on their own.
  String get back;
  String get done;
  String get confirm;
  String get search;
  String get searchFonts;
  String get clear;
  String get copy;
  String get edit;
  String get expand;
  String get collapse;
  String get remove;
  String get add;
  String get send;
  String get stop;
  String get inputMessage;
  String get thinking;
  String get emptyContent;
  String get unnamed;
  String get notSet;
  String get notFilled;
  String get currentBadge;
  String get colorTitle;
  String get entry;

  /// Joins names inside one line, e.g. tag lists.
  String get listSeparator;
  String copiedEntry(String label);
  String moreEntries(int count);

  // Media viewer chrome.

  String get closePreview;
  String get zoomHint;

  // Graph view chrome.

  String get tidyLayout;
  String get addStation;
  String get graphEmpty;

  // Font library chrome.

  String get fontSystemDefault;
  String get fontImported;
  String get fontImportDone;
  String get fontImportFailed;
  String get fontRemoved;
  String get fontRemoveFailed;
  String get fontPickFile;
  String get fontLoading;
  String get fontDeleteTitle;
  String fontDeleteDetail(String family);
  String get fontRemoveAction;
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

  @override
  String get back => 'Back';

  @override
  String get done => 'Done';

  @override
  String get confirm => 'OK';

  @override
  String get search => 'Search';

  @override
  String get searchFonts => 'Search fonts';

  @override
  String get clear => 'Clear';

  @override
  String get copy => 'Copy';

  @override
  String get edit => 'Edit';

  @override
  String get expand => 'Expand';

  @override
  String get collapse => 'Collapse';

  @override
  String get remove => 'Remove';

  @override
  String get add => 'Add';

  @override
  String get send => 'Send';

  @override
  String get stop => 'Stop';

  @override
  String get inputMessage => 'Type a message';

  @override
  String get thinking => 'Thinking';

  @override
  String get emptyContent => 'Nothing here yet';

  @override
  String get unnamed => 'Untitled';

  @override
  String get notSet => 'Not set';

  @override
  String get notFilled => 'Not filled';

  @override
  String get currentBadge => 'Current';

  @override
  String get colorTitle => 'Color';

  @override
  String get entry => 'Entry';

  @override
  String get listSeparator => ', ';

  @override
  String copiedEntry(String label) => 'Copied: $label';

  @override
  String moreEntries(int count) => '$count more';

  @override
  String get closePreview => 'Close preview';

  @override
  String get zoomHint => 'Double-tap to zoom; tap to close';

  @override
  String get tidyLayout => 'Tidy layout';

  @override
  String get addStation => 'Add stop';

  @override
  String get graphEmpty => 'No stops yet';

  @override
  String get fontSystemDefault => 'System default';

  @override
  String get fontImported => 'Imported';

  @override
  String get fontImportDone => 'Font added to the app library';

  @override
  String get fontImportFailed => 'Cannot import this font file';

  @override
  String get fontRemoved => 'Font removed from the app library';

  @override
  String get fontRemoveFailed => 'Cannot remove this font';

  @override
  String get fontPickFile => 'Choose font file…';

  @override
  String get fontLoading => 'Loading fonts…';

  @override
  String get fontDeleteTitle => 'Delete font?';

  @override
  String fontDeleteDetail(String family) =>
      'Remove 「$family」 from the app library to free space?';

  @override
  String get fontRemoveAction => 'Remove from library';
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
  Future<T> load(Locale locale) => SynchronousFuture<T>(resolve(locale));

  @override
  bool shouldReload(covariant LocalizationsDelegate<T> old) => false;
}

/// Generic chrome words; foundation widgets read these, never product copy.
extension AppLocalizationsContext on BuildContext {
  AppLocalizations get ui =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      DefaultAppLocalizations.instance;
}
