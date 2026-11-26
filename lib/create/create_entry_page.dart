import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/create/character_card_import_page.dart';
import 'package:anoworld/create/novel_import_page.dart';
import 'package:anoworld/create/staged_create_page.dart';
import 'package:flutter/widgets.dart';

enum CreateEntryKind { characterCard, novel, stagedPrompts }

extension CreateEntryKindLabels on CreateEntryKind {
  String title(AppStrings strings) => switch (this) {
    CreateEntryKind.characterCard => strings.importCard,
    CreateEntryKind.novel => strings.pasteStory,
    CreateEntryKind.stagedPrompts => strings.stagedPrompts,
  };

  String blurb(AppStrings strings) => switch (this) {
    CreateEntryKind.characterCard => strings.createEntryBlurbCard,
    CreateEntryKind.novel => strings.createEntryBlurbNovel,
    CreateEntryKind.stagedPrompts => strings.createEntryBlurbStaged,
  };
}

/// Entry for one of the three UX creation paths.
class CreateEntryPage extends StatelessWidget {
  const CreateEntryPage({super.key, required this.kind});

  final CreateEntryKind kind;

  @override
  Widget build(BuildContext context) {
    return switch (kind) {
      CreateEntryKind.stagedPrompts => const StagedCreatePage(),
      CreateEntryKind.characterCard => const CharacterCardImportPage(),
      CreateEntryKind.novel => const NovelImportPage(),
    };
  }
}
