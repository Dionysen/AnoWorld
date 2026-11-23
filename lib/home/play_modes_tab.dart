import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/foundation/layout/app_layout.dart';
import 'package:anoworld/foundation/widgets/app_detail_pane.dart';
import 'package:anoworld/foundation/widgets/app_disclosure_icon.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_master_detail.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_page_route.dart';
import 'package:anoworld/home/home_tab_back.dart';
import 'package:anoworld/home/story_assistant_navigation.dart';
import 'package:anoworld/play/plot_elements_library_page.dart';
import 'package:anoworld/settings/ai_preset_page.dart';
import 'package:flutter/material.dart';

enum _PlayEntry { plotElements, aiPreset }

/// Play-style hub: global libraries and modes (third home tab).
///
/// Wide windows open the selected entry inside the detail pane; narrow ones
/// push the full page.
class PlayModesTab extends StatefulWidget {
  const PlayModesTab({super.key, this.onChromeChanged});

  /// Home chrome (back handling / assistant) may need a rebuild.
  final VoidCallback? onChromeChanged;

  @override
  State<PlayModesTab> createState() => PlayModesTabState();
}

class PlayModesTabState extends State<PlayModesTab> implements HomeTabBack {
  /// Entry shown in the wide-window detail pane; null shows the empty hint.
  _PlayEntry? _selected;

  /// Stack of the detail column (library page, then whatever it opens).
  final _detailPane = AppDetailPaneController();

  @override
  void initState() {
    super.initState();
    _detailPane.addListener(_onDetailPaneChanged);
  }

  @override
  void dispose() {
    _detailPane
      ..removeListener(_onDetailPaneChanged)
      ..dispose();
    super.dispose();
  }

  /// The pane opened / closed a page, so the shell's back state changed.
  void _onDetailPaneChanged() {
    if (!mounted) return;
    setState(() {});
    widget.onChromeChanged?.call();
  }

  @override
  bool get canGoBack => _detailPane.canPop || _selected != null;

  @override
  bool handleSystemBack() {
    if (_detailPane.pop()) return true;
    if (_selected == null) return false;
    setState(() => _selected = null);
    return true;
  }

  Future<void> _open(
    BuildContext context,
    _PlayEntry entry, {
    required bool split,
  }) async {
    if (split) {
      setState(() => _selected = entry);
      widget.onChromeChanged?.call();
      return;
    }
    switch (entry) {
      case _PlayEntry.plotElements:
        await pushStoryRoute<void>(context, const PlotElementsLibraryPage());
      case _PlayEntry.aiPreset:
        await pushAppSlide(context, const AiPresetPage());
    }
  }

  @override
  Widget build(BuildContext context) {
    final paneWidth = AppScope.paneWidthOf(context);
    final selected = _selected;
    return LayoutBuilder(
      builder: (context, constraints) {
        final split = AppLayout.useMasterDetail(constraints.maxWidth);
        return AppMasterDetail(
          primary: _masterPane(context, split: split),
          detail: selected == null ? null : _detail(selected),
          emptyLabel: context.strings.selectPlayModeHint,
          paneWidth: paneWidth,
          detailController: _detailPane,
        );
      },
    );
  }

  Widget _masterPane(BuildContext context, {required bool split}) {
    final strings = context.strings;
    final selected = _selected;
    return AppPageBody.list(
      children: [
        AppListTileStack(
          tiles: [
            AppListTile(
              title: strings.plotElementsTitle,
              subtitle: strings.plotElementsHubHint,
              icon: Icons.theater_comedy_outlined,
              trailing: split ? null : const AppForwardIcon(),
              selected: selected == _PlayEntry.plotElements,
              onTap: () => _open(context, _PlayEntry.plotElements, split: split),
            ),
            AppListTile(
              title: strings.aiPresetTitle,
              subtitle: strings.aiPresetHubHint,
              icon: Icons.auto_awesome_outlined,
              trailing: split ? null : const AppForwardIcon(),
              selected: selected == _PlayEntry.aiPreset,
              onTap: () => _open(context, _PlayEntry.aiPreset, split: split),
            ),
          ],
        ),
      ],
    );
  }

  Widget _detail(_PlayEntry entry) => switch (entry) {
    _PlayEntry.plotElements => const PlotElementsLibraryPage(
      key: ValueKey<String>('play-detail-plot-elements'),
    ),
    _PlayEntry.aiPreset => const AiPresetPage(
      key: ValueKey<String>('play-detail-ai-preset'),
    ),
  };
}
