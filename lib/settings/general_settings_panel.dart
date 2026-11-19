import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_page_gutter.dart';
import 'package:anoworld/foundation/widgets/app_page_route.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/settings/advanced_settings_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// General settings section.
class GeneralSettingsPanel extends StatelessWidget {
  const GeneralSettingsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    if (!kDebugMode) {
      return AppPageGutter(
        child: AppSectionHeader(
          strings.settingsSectionGeneral,
          subtitle: strings.settingsNothingToChange,
        ),
      );
    }

    return AppPageGutter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSectionHeader(strings.settingsSectionGeneral),
          AppListTile(
            title: strings.advancedTitle,
            subtitle: strings.advancedHint,
            icon: Icons.construction_outlined,
            onTap: () {
              pushAppSlide(context, const AdvancedSettingsPage());
            },
          ),
        ],
      ),
    );
  }
}
