import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/create/character_card_import_page.dart';
import 'package:anoworld/create/staged_create_page.dart';
import 'package:anoworld/foundation/widgets/app_empty_state.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
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
    if (kind == CreateEntryKind.stagedPrompts) {
      return const StagedCreatePage();
    }
    if (kind == CreateEntryKind.characterCard) {
      return const CharacterCardImportPage();
    }

    final strings = context.strings;
    return AppPage(
      title: kind.title(strings),
      onBack: () => Navigator.of(context).maybePop(),
      body: AppPageBody(
        children: [
          AppSectionHeader(strings.createEntrySection),
          AppText(kind.blurb(strings), role: AppTextRole.body),
          AppEmptyState(
            message: strings.createEntryComingSoon,
            detail: strings.createEntryComingSoonDetail,
          ),
        ],
      ),
    );
  }
}
