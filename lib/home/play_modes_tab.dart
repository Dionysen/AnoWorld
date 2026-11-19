import 'package:anoworld/foundation/widgets/app_disclosure_icon.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/home/story_assistant_navigation.dart';
import 'package:anoworld/play/plot_elements_library_page.dart';
import 'package:flutter/material.dart';

/// Play-style hub: global libraries and modes (third home tab).
class PlayModesTab extends StatelessWidget {
  const PlayModesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPageBody.list(
      children: [
        const AppSectionHeader(
          '素材库',
          subtitle: '给故事勾着用，不绑某一个故事',
          gutter: true,
        ),
        AppListTileStack(
          tiles: [
            AppListTile(
              title: '剧情元素',
              subtitle: '全局库，给故事勾着用',
              icon: Icons.auto_awesome_outlined,
              trailing: const AppForwardIcon(),
              onTap: () => pushStoryRoute<void>(
                context,
                const PlotElementsLibraryPage(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
