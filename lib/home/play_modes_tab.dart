import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/foundation/widgets/app_disclosure_icon.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_page_route.dart';
import 'package:anoworld/home/story_assistant_navigation.dart';
import 'package:anoworld/play/plot_elements_library_page.dart';
import 'package:anoworld/settings/ai_preset_page.dart';
import 'package:flutter/material.dart';

/// Play-style hub: global libraries and modes (third home tab).
class PlayModesTab extends StatelessWidget {
  const PlayModesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return AppPageBody.list(
      children: [
        AppListTileStack(
          tiles: [
            AppListTile(
              title: strings.plotElementsTitle,
              subtitle: strings.plotElementsHubHint,
              icon: Icons.theater_comedy_outlined,
              trailing: const AppForwardIcon(),
              onTap: () => pushStoryRoute<void>(
                context,
                const PlotElementsLibraryPage(),
              ),
            ),
            AppListTile(
              title: strings.aiPresetTitle,
              subtitle: strings.aiPresetHubHint,
              icon: Icons.auto_awesome_outlined,
              trailing: const AppForwardIcon(),
              onTap: () => pushAppSlide(context, const AiPresetPage()),
            ),
          ],
        ),
      ],
    );
  }
}
