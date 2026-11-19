import 'package:anoworld/app/l10n/app_strings_zh.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/domain/settings/appearance_settings.dart';
import 'package:anoworld/foundation/ai/st_prompt_manager.dart';
import 'package:anoworld/foundation/l10n/app_localizations.dart';
import 'package:anoworld/foundation/logging/app_log_level.dart';
import 'package:anoworld/foundation/theme/theme_tokens.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Product UI copy contract.
///
/// Every user-facing string lives here (not in widgets) so a new language only
/// needs one more implementation file; see [AppStringsSetup].
///
/// Not for: AI prompt text, seed library content, or log messages — those are
/// data/behaviour, not chrome.
abstract class AppStrings extends AppLocalizations {
  const AppStrings();

  /// Category names inside prompts / joins.
  String get listSeparator;

  // Shape shared across list/detail screens.

  /// Row title for a row whose keyword is blank.
  String get unnamed;

  /// Description placeholder.
  String get noDescription;

  /// Prefix marking an untouched built-in row.
  String get builtInTag;

  /// Prefix marking an edited built-in row.
  String get builtInEditedTag;

  /// Count subtitle; zero reads as "still empty".
  String countLabel(int count);

  /// Whole-library or per-category counts.
  String get uncategorized;

  // Plot-element library (玩法 → 剧情元素库).

  String get plotElementsLibraryTitle;
  String get tabAll;
  String get tabCategorized;
  String get tabPacks;
  String get addOne;
  String get newCategory;
  String get newPack;
  String get libraryEmptyMessage;
  String get libraryEmptyDetail;
  String get packsEmptyMessage;
  String get packsEmptyDetail;
  String get restoreAllBuiltIns;
  String get restoreAllBuiltInsHint;
  String get restoreAllConfirmTitle;
  String get restoreAllConfirmDetail;
  String get restoreAllConfirmLabel;
  String get renameCategory;
  String get newCategoryTitle;
  String get categoryEmptyMessage;
  String get categoryEmptyDetail;

  /// Empty category page opened from the story picker.
  String get categoryEmptyPickDetail;
  String get categoryNameHint;

  // Element packs.

  String get renamePack;
  String get deletePack;
  String get deletePackTitle;
  String get deletePackEmptyDetail;

  /// Delete confirmation when the pack still holds elements.
  String packDeleteDetail(int count);

  String get packEmptyLibraryDetail;
  String get packMissing;
  String get packTitleFallback;
  String get packNameHint;

  /// "n 条 · keyword、keyword…"
  String packSummary(int count, String preview);

  /// "已选 m / n 条"
  String packAppliedCount(int applied, int total);

  String packOverlapTitle(String packName);

  /// Explains applying a pack over existing selections.
  String packApplyImpact(PackApplyPlanText plan);

  String packRemoveTitle(String packName);

  /// Explains turning a pack off.
  String packRemoveImpact(PackRemovePlanText plan);

  String get applyAnyway;
  String get uncheck;

  // Story-side picker.

  String get plotElementsTitle;
  String get manageLibrary;
  String get openStoryFailed;
  String get libraryEmptyPickDetail;
  String get goManageLibrary;
  String get packsEmptyPickDetail;
  String selectedCount(int count);

  // Element editor.

  String get newElementTitle;
  String get editElementTitle;
  String get keywordLabel;
  String get keywordHint;
  String get categoryLabel;
  String get descriptionLabel;
  String get descriptionHint;
  String maxChars(int count);
  String get generateDescription;
  String get generating;
  String get generateFailed;
  String get restoreDefault;
  String get deleteElementTitle;
  String get deleteElementBuiltInDetail;
  String get deleteElementCustomDetail;

  // Home navigation.

  String get tabSessions;
  String get tabStories;
  String get tabPlayModes;
  String get tabMe;
  String get settingsTitle;
  String folderCount(int count);
  String storyCount(int count);
  String get emptyFolder;
  String get addAction;
  String get importAction;
  String get plotElementsHubHint;
  String get aiPresetTitle;
  String get aiPresetHubHint;
  String get noPersonaYet;

  // Stories (故事) tab.

  String get browseRoot;
  String get searchStoriesHint;
  String get untitledStory;
  String get storyOptions;
  String get moveToFolder;
  String get displayMode;
  String get avatarShape;
  String get viewModeDetailedList;
  String get viewModeSimpleList;
  String get viewModeGrid;
  String get viewModeCompactGrid;
  String get avatarCircle;
  String get avatarSquare;
  String get avatarRectangle;
  String get noMatchingStories;
  String createFailed(Object error);
  String sampleWriteFailed(Object error);
  String importedStory(String title);
  String importFailed(Object error);
  String get pickStoryFolderTitle;
  String get nameLabel;
  String get folderNameHint;
  String get newFolder;
  String get renameFolder;
  String createFolderFailed(Object error);
  String renameFolderFailed(Object error);
  String deleteFolderFailed(Object error);
  String dissolveFolderFailed(Object error);
  String moveFailed(Object error);
  String deleteFolderTitle(String name);
  String get deleteFolderDetail;
  String dissolveFolderTitle(String name);
  String get dissolveFolderDetail;
  String get dissolve;
  String deleteItemsTitle(int count);
  String get deleteItemsDetail;
  String get moveToTitle;
  String get allStories;
  String get deleteStoryTitle;
  String get deleteStoryDetail;
  String updatedOn(String date);
  String get openAction;
  String get renameAction;
  String get dissolveFolderAction;
  String get deleteFolderAction;
  String get playStory;
  String get viewStory;
  String get editStory;
  String get deleteStory;
  String cannotStart(Object error);
  String get newBlankStory;
  String get pasteStory;
  String get stagedPrompts;
  String get importCard;
  String get importStoryPack;
  String get trySampleStory;

  // Story hub.

  String get changeCover;
  String get cannotChangeCover;
  String coverFailed(Object error);
  String get coverSection;
  String get chooseImage;
  String get unnamedEntry;
  String get unnamedCast;
  String get tagAlwaysOn;
  String get tagOnDemand;
  String get tagProtagonist;
  String get tagExampleLines;
  String get mainSummaryTitle;
  String get tagSummary;
  String get noMainStations;
  String mainStops(int stops, int edges);
  String get continueCreating;
  String get startPlaying;
  String get createHubUntitled;
  String createHubTitle(String name);
  String get worldBookTitle;
  String get castTitle;
  String get mainTitle;
  String get worldBookEmpty;
  String get castEmpty;
  String get plotElementsEmpty;
  String worldBookSize(int entries, int alwaysOn, int tokens);
  String castSize(int members, int tokens);
  String mainSize(int nodes, int tokens);
  String plotElementsSize(int selected, int tokens);

  // Play.

  String get howToPlay;
  String get visualNovelModeHint;
  String get chatModeHint;
  String get chatSettingsTitle;
  String get readingSection;
  String get readingSectionHint;
  String get lineHeight;
  String get paragraphSpacing;
  String get bubblesSection;
  String get bubbleRadius;
  String get showReasoning;
  String get showReasoningHint;
  String get avatarsSection;
  String get characterAvatar;
  String get characterAvatarHint;
  String get myAvatar;
  String get myAvatarHint;
  String get avatarAboveBubble;
  String get avatarAboveBubbleHint;
  String get backgroundSection;
  String get chatBackground;
  String get backgroundPickerHint;
  String get backgroundThemeDefault;
  String get backgroundThemeDefaultHint;
  String get backgroundSolid;
  String get backgroundGradient;
  String get gradientSection;
  String get userLabelFallback;
  String get castLabelFallback;
  String get narrator;
  String get progressLoaded;
  String get statusWriting;
  String get statusTurnFailed;
  String get statusRestarted;
  String get statusSafeExit;
  String get fallbackBeatText;
  String gotoNode(String name);
  String get regenerateReply;
  String get segmentEnded;
  String get restart;
  String get generatingSegment;
  String get generateThisSegment;
  String get continueAction;
  String get historyBack;
  String get historyForward;
  String get historyFastForward;
  String get vnDirectionSection;
  String get vnDirectionHint;
  String get vnMinLinesLabel;
  String vnMinLinesValue(int lines);
  String get scenePlaceholder;
  String get noBackgroundImage;
  String backgroundLabel(String id);
  String get choosePlease;
  String get segmentNotWritten;
  String castWithSlot(String name, String slot);
  String get backToBottom;
  String get chooseModel;
  String get chooseModelHint;
  String get backAction;
  String get replyChoices;
  String get refreshChoices;
  String get startChat;

  // Story editors (设定 / 角色 / 情节走向 / 导入角色卡 / 分阶段提示词).

  String get titleLabel;
  String get bodyLabel;
  String get undoAction;
  String get redoAction;

  String get createEntrySection;
  String get createEntryBlurbCard;
  String get createEntryBlurbNovel;
  String get createEntryBlurbStaged;
  String get createEntryComingSoon;
  String get createEntryComingSoonDetail;

  String get worldBookNoKeywords;
  String worldBookKeywords(String keywords);
  String get worldBookEntriesSection;
  String get worldBookSelectEntries;
  String worldBookSelectedCount(int count);
  String get worldBookSelectAll;
  String get worldBookDeselectAll;
  String get worldBookAddEntry;
  String get worldBookOpenFailed;
  String get worldBookSectionHint;
  String get worldBookEmptyDetail;
  String get worldBookUnnamedEntry;
  String get worldBookNewEntry;
  String get worldBookEditEntry;
  String get worldBookTitleHint;
  String get worldBookBodyHint;
  String get worldBookAlwaysOn;
  String get worldBookAlwaysOnHint;
  String get worldBookKeywordsHint;
  String get worldBookDeleteOneTitle;
  String worldBookDeleteManyTitle(int count);
  String get worldBookDeleteDetail;

  String get castAddMember;
  String get castAddOne;
  String get castOpenFailed;
  String get castSection;
  String get castSectionHint;
  String get castEmptyDetail;
  String get castNoSummary;
  String castProtagonist(String summary);
  String get castNewMember;
  String get castEditMember;
  String get castNameLabel;
  String get castSummaryLabel;
  String get castPersonalityLabel;
  String get castSpeechLabel;
  String get castExamplesLabel;
  String get castExamplesHint;
  String get castProtagonistLabel;
  String get castProtagonistHint;
  String get castDeleteMember;
  String get castUnnamedMember;

  String get mainGraphCanvas;
  String get mainGraphCard;
  String get mainGraphOverview;
  String get mainGraphMenuSection;
  String get mainGraphShowGrid;
  String get mainGraphShowGridHint;
  String get mainGraphInputPort;
  String get mainGraphBranchLabel;
  String get mainGraphContinueLabel;
  String get mainGraphNewNodeTitle;
  String get mainGraphNewNodeSynopsis;
  String get mainGraphDeleteNodeTitle;
  String mainGraphDeleteNodeDetail(String title);
  String get mainGraphDeleteNodeDetailEmpty;
  String get nodeKindOpening;
  String get nodeKindScene;
  String get nodeKindTurning;
  String get nodeKindEnding;
  String get mainGraphNodeSheetTitle;
  String get mainGraphNodeGoalLabel;
  String get mainGraphNodeKindLabel;
  String get mainGraphOutgoingLabel;
  String get mainGraphNoOutgoing;
  String mainGraphLeadsTo(String title);
  String get mainGraphDeleteNodeAction;
  String get mainGraphEdgeSheetTitle;
  String get mainGraphEdgeDetailLabel;
  String get mainGraphEdgeDetailHint;
  String get mainGraphEdgeWriting;
  String get mainGraphExpandWithAi;
  String get mainGraphDeleteEdge;
  String get mainGraphExpandFailed;
  String get mainGraphConnectTip;
  String get mainGraphOverviewTitle;
  String get mainGraphOverviewHint;
  String get mainGraphOpenFailed;
  String get noStory;

  String get cardImportSection;
  String get cardImportSectionHint;
  String get cardPickCards;
  String get cardRepick;
  String get cardPickHint;
  String get cardReading;
  String get cardEmptyTitle;
  String get cardEmptyDetail;
  String get cardStoryNameLabel;
  String get cardTidySection;
  String get cardTidyHint;
  String get cardSanitize;
  String get cardOrganize;
  String get cardCastSection;
  String get cardCastSectionHint;
  String get cardWorldBookSection;
  String get cardWorldBookSectionHint;
  String get cardNoWorldBookEntries;
  String get cardAiNoteSection;
  String get cardAiNoteHint;
  String get cardWrite;
  String get cardWriteHint;
  String get cardOrganizePreviewTitle;
  String get cardOrganizePreviewHint;
  String get cardApply;
  String cardReadCount(int count);
  String get cardSanitizeNoChange;
  String cardSanitizeChanged(int count);
  String get cardOrganizeNoChange;
  String cardOrganizeApplied(int count);
  String get cardNeedOneCast;
  String get cardReadUnavailable;
  String cardReadFailed(Object error);
  String cardWriteFailed(Object error);
  String cardOrganizeFailed(Object error);
  String cardCannotRead(String file);
  String cardUnsupportedFormat(String extension);

  String get stagedWorld;
  String get stagedCast;
  String get stagedMain;
  String get stagedWorldHint;
  String get stagedCastHint;
  String get stagedMainHint;
  String get stagedWorldPrompt;
  String get stagedCastPrompt;
  String get stagedMainPrompt;
  String get stagedNeedPrompt;
  String get stagedNeedService;
  String get stagedGenerating;
  String get stagedNeedWorldFirst;
  String get stagedNeedWorldAndCast;
  String get stagedNeedWorldDone;
  String get stagedNeedCastDone;
  String get stagedNeedMainDone;
  String get stagedGenerateFailed;
  String createStoryFailed(Object error);
  String get stagedBooting;
  String get stagedGenerate;
  String get stagedRegenerate;
  String get stagedGeneratingShort;
  String get stagedPreviewLabel;
  String get stagedPlay;
  String get stagedNext;

  // Create assistant.

  String get assistantTitle;
  String get currentStory;
  String get notSelected;
  String get pickStoryTitle;
  String get pickStoryHint;
  String get noStoriesYet;
  String get assistantEmptyHint;
  String get assistantComposerHint;
  String get assistantPending;
  String get assistantNeedsStory;
  String get assistantNeedsService;
  String get assistantFailedRetry;
  String get assistantFailedLater;
  String get assistantNoSave;
  String get assistantGraphSaved;
  String get proposalLead;
  String stopCount(int count);
  String branchCount(int count);

  // Generated plot confirmation.

  String get generatedPlotTitle;
  String get replaceGraph;
  String get writeGraph;
  String get skipWrite;
  String replaceStops(int count);
  String replaceStopsWithBeats(int count, int beats);

  // Saves (会话) tab.
  String get resumePlay;
  String get openStory;
  String get deleteSave;
  String get deleteSavesTitle;
  String get deleteSaveTitle;
  String get deleteSaveDetail;
  String get searchSavesHint;
  String get exitSelection;
  String selectAll(bool allSelected);
  String get multiSelect;
  String get noSavesMessage;
  String get noSavesDetail;
  String get noMatchMessage;
  String get noMatchDetail;
  String get goStories;
  String get kindChat;
  String get kindVisualNovel;
  String lastPlayed(String kind, String relative);
  String get justNow;
  String minutesAgo(int minutes);
  String hoursAgo(int hours);
  String daysAgo(int days);
  String loadFailed(Object error);
  String cannotResume(Object error);

  // Settings shell.

  String get settingsSectionGeneral;
  String get settingsSectionAppearance;
  String get settingsSectionAi;
  String get settingsSectionAbout;
  String get settingsNothingToChange;
  String get advancedTitle;
  String get advancedHint;
  String get diagnosticsSection;
  String get diagnosticsHint;
  String get diagnosticsLogTitle;
  String get logsEmpty;
  String get clearAction;
  String logCount(int count);
  String get logNone;
  String get copiedToast;

  /// Label for one log severity.
  String logLevelName(AppLogLevel level);

  // About.

  String get appTagline;
  String get appDescription;
  String appVersion(String version);

  // Appearance.

  String get themeSection;
  String get themeModeLabel;
  String get themeModeHint;
  String get themeColorLabel;
  String get themeColorHint;
  String get customColorsLabel;
  String get customColorsHint;
  String get interfaceSection;
  String get fontLabel;
  String get fontHint;
  String get fontSizeLabel;
  String get cornerRadiusLabel;
  String get currentTag;
  String get inUseTag;
  String get lightSlotTag;
  String get darkSlotTag;
  String get customTag;
  String get manageAction;
  String get copyAction;
  String get saveAsTheme;
  String get restoreDefaults;
  String get saveAsThemeTitle;
  String defaultThemeName(int number);
  String get themeNameLabel;
  String copyName(String name);
  String get renameThemeTitle;
  String get deleteThemeTitle;
  String deleteThemeDetail(String name);

  /// Theme mode name (follow system / light / dark).
  String themeModeName(AppThemeModeSetting mode);

  /// Built-in color pack name.
  String themePresetName(ThemePreset preset);

  /// Editable color slot name (e.g. app background).
  String themeTokenName(ThemeToken token);

  /// One-line explanation of a color slot.
  String themeTokenHint(ThemeToken token);

  // AI channels.

  String get textChannelTitle;
  String get textChannelHint;
  String get imageChannelTitle;
  String get imageChannelHint;
  String get pickProviderTitle;
  String get pickProviderHint;
  String get currentProvider;
  String get changeAction;
  String get baseUrlLabel;
  String get baseUrlHint;
  String get baseUrlEmpty;
  String get apiKeyLabel;
  String get apiKeyHint;
  String get modelLabel;
  String get tapToChoose;
  String get probingShort;
  String get modelNotChosen;
  String get modelHintNone;
  String foundModelsShort(int count);
  String get reasoningLabel;
  String get reasoningHint;
  String get probeModels;
  String get probeModelsRunning;
  String get probeModelsHint;
  String get probeHintNeedsKey;
  String get probeHintNoKey;
  String get probeHintManual;
  String get probingModels;
  String foundModels(int count);
  String get probeFallbackModels;
  String probeFailed(Object error);

  /// Text provider name; built-ins keep their brand name.
  String textProviderName(AiTextProviderKind kind);

  /// Image provider name (never shares the text list).
  String imageProviderName(AiImageProviderKind kind);

  String reasoningEffortName(AiReasoningEffort effort);

  // AI preset.

  String get presetRowHint;
  String get pickPresetTitle;
  String get pickPresetHint;
  String get presetBuiltInGroup;
  String get presetMineGroup;
  String get presetNotChosen;
  String presetApplied(String name);

  /// Icon-button labels above the current preset row.
  String get presetNewAction;
  String get presetSaveCurrentAction;
  String get presetRenameAction;
  String get presetDeleteAction;
  String get presetImportAction;
  String get presetExportAction;

  String get presetNewName;
  String presetCreated(String name);
  String get presetRenameTitle;
  String presetRenamed(String name);
  String get presetRenameBuiltInHint;
  String presetDeleteTitle(String name);
  String get presetDeleteDetail;
  String get presetDeleteBuiltInHint;
  String get presetNoActive;
  String get presetRestoreOrderAction;
  String get presetOrderRestored;

  String get myPresetName;
  String presetSaved(String name);
  String get presetDeleted;
  String get invalidPresetFile;
  String presetImported(String name);
  String presetImportFailed(Object error);
  String get exportPresetDialog;
  String get confirmAction;
  String get samplingSection;
  String get presetPromptsSection;

  String get presetDefaultName;
  String get presetCreativeName;
  String get presetPreciseName;
  String get presetDeterministicName;
  String get presetLongformName;
  String get presetMirostatName;
  String get presetDefaultHint;
  String get presetCreativeHint;
  String get presetPreciseHint;
  String get presetDeterministicHint;
  String get presetLongformHint;
  String get presetMirostatHint;

  // Sampling.

  String get maxOutputLabel;
  String get contextLengthLabel;
  String get temperatureLabel;
  String get streamOutput;
  String get streamOutputHint;
  String get advancedSampling;
  String get advancedSamplingHint;
  String get advancedSamplingTitle;
  String get repetitionPenalty;
  String get penaltyRange;
  String get frequencyPenalty;
  String get presencePenalty;
  String get mirostatMode;
  String get randomSeed;
  String get randomSeedHint;
  String get stopSequences;
  String get stopSequencesHint;
  String get notSet;

  // Prompt sections.

  String get promptSectionsTitle;
  String get promptOrderSection;
  String get promptOrderHint;
  String get contentLabel;
  String get tapToEdit;
  String get tapToView;
  String get filledByCast;
  String get filledByCastReadOnly;
  String get filledByPersona;
  String get filledByWorldBook;
  String get filledByHistory;
  String get emptyAuthorNote;
  String get filledAutomatically;

  /// Display name of a prompt section type.
  String promptSectionName(PromptSectionType type);

  // Player persona.

  String get personaTitle;
  String get addPersona;
  String get personasEmpty;
  String get personasEmptyHint;
  String get personaInUse;
  String personaInUseWith(String summary);
  String deletePersonaTitle(String name);
  String get deletePersonaHint;
  String get editPersona;
  String get personaNameLabel;
  String get personaAboutLabel;
  String get personaAboutHint;
  String get personaSystemLabel;
  String get personaSystemHint;
  String get personaPostLabel;
  String get personaPostHint;
  String get savingDots;
  String get deletingDots;
}

/// Language-agnostic description of a pack apply overlap, so each language can
/// phrase it its own way.
class PackApplyPlanText {
  const PackApplyPlanText({
    required this.addedCount,
    required this.manualSharedCount,
    required this.overlappedCount,
    required this.overlapNames,
  });

  final int addedCount;
  final int manualSharedCount;
  final int overlappedCount;
  final List<String> overlapNames;
}

/// Language-agnostic description of turning a pack off.
class PackRemovePlanText {
  const PackRemovePlanText({
    required this.removedCount,
    required this.keptCount,
    required this.keptByNames,
  });

  final int removedCount;
  final int keptCount;
  final List<String> keptByNames;
}

/// Registers the app's translations with Flutter.
abstract final class AppStringsSetup {
  static const AppStrings fallback = AppStringsZh();

  /// Every supported language; add a new implementation here to ship it.
  static const List<AppStrings> translations = <AppStrings>[fallback];

  static const List<AppLocalizations> _asBase = <AppLocalizations>[fallback];

  static List<Locale> get supportedLocales => <Locale>[
    for (final translation in translations) translation.locale,
  ];

  static Locale resolveLocale(Locale? requested, Iterable<Locale> supported) {
    if (requested == null) return fallback.locale;
    for (final translation in translations) {
      if (translation.matches(requested)) return translation.locale;
    }
    return fallback.locale;
  }

  /// Pass to `MaterialApp.localizationsDelegates`.
  static List<LocalizationsDelegate<dynamic>> get delegates =>
      <LocalizationsDelegate<dynamic>>[
        const AppLocalizationsDelegate<AppStrings>(
          translations: translations,
          fallback: fallback,
        ),
        // Same instances, registered under the base type so foundation widgets
        // can read chrome words without depending on product copy.
        const AppLocalizationsDelegate<AppLocalizations>(
          translations: _asBase,
          fallback: fallback,
        ),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ];
}

extension AppStringsContext on BuildContext {
  /// Translated product copy; falls back to Chinese when nothing is registered
  /// (e.g. a widget pumped without the app's delegates).
  AppStrings get strings =>
      Localizations.of<AppStrings>(this, AppStrings) ?? AppStringsSetup.fallback;
}
