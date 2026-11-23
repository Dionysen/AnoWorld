import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/foundation/layout/app_layout.dart';
import 'package:anoworld/foundation/persona/user_persona.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_detail_pane.dart';
import 'package:anoworld/foundation/widgets/app_disclosure_icon.dart';
import 'package:anoworld/foundation/widgets/app_icon_button.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_master_detail.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_page_gutter.dart';
import 'package:anoworld/foundation/widgets/app_page_route.dart';
import 'package:anoworld/foundation/widgets/app_person_avatar.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/home/home_tab_back.dart';
import 'package:anoworld/settings/persona_delete.dart';
import 'package:anoworld/settings/persona_editor_page.dart';
import 'package:anoworld/settings/persona_labels.dart';
import 'package:anoworld/settings/persona_settings_page.dart';
import 'package:anoworld/settings/settings_page.dart';
import 'package:flutter/material.dart';

/// Profile tab: player identities plus the entry to settings.
///
/// Wide windows show identities in the list column and the selected one in the
/// detail pane; narrow ones push the identity hub instead.
class MeTab extends StatefulWidget {
  const MeTab({super.key, this.onChromeChanged});

  /// Home chrome (back handling / assistant) may need a rebuild.
  final VoidCallback? onChromeChanged;

  @override
  State<MeTab> createState() => MeTabState();
}

class MeTabState extends State<MeTab> implements HomeTabBack {
  /// Identity shown in the wide-window detail pane; null shows the empty hint.
  String? _selectedPersonaId;

  /// Stack of the detail column (identity page, then its editor).
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

  String? _findId(List<UserPersona> personae) {
    final id = _selectedPersonaId;
    if (id == null) return null;
    for (final persona in personae) {
      if (persona.id == id) return id;
    }
    return null;
  }

  @override
  bool get canGoBack => _detailPane.canPop || _selectedPersonaId != null;

  @override
  bool handleSystemBack() {
    if (_detailPane.pop()) return true;
    if (_selectedPersonaId == null) return false;
    setState(() => _selectedPersonaId = null);
    return true;
  }

  Future<void> _openSettings(BuildContext context) {
    return pushAppSlide(context, const SettingsPage());
  }

  Future<void> _addPersona(BuildContext context) async {
    await pushAppSlide(context, const PersonaEditorPage());
  }

  /// Wide windows select in the detail pane; narrow ones push the identity hub.
  void _openPersona(
    BuildContext context,
    UserPersona persona, {
    required bool split,
  }) {
    if (split) {
      setState(() => _selectedPersonaId = persona.id);
      widget.onChromeChanged?.call();
      return;
    }
    pushAppSlide(context, const PersonaSettingsPage());
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.settingsOf(context);
    final strings = context.strings;
    return LayoutBuilder(
      builder: (context, constraints) {
        final split = AppLayout.useMasterDetail(constraints.maxWidth);
        return ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final personae = controller.personas.personas;
            final selectedId = _findId(personae);
            return AppMasterDetail(
              primary: _masterPane(
                context,
                personae: personae,
                activeId: controller.activePersona?.id,
                selectedId: selectedId,
                split: split,
              ),
              // Same page a narrow window pushes when an identity is tapped:
              // the identity hub, with its editor opening on top in place.
              detail: selectedId == null
                  ? null
                  : PersonaSettingsPage(
                      key: ValueKey<String>('persona-pane-$selectedId'),
                    ),
              emptyLabel: strings.selectPersonaHint,
              paneWidth: AppScope.paneWidthOf(context),
              detailController: _detailPane,
            );
          },
        );
      },
    );
  }

  Widget _masterPane(
    BuildContext context, {
    required List<UserPersona> personae,
    required String? activeId,
    required String? selectedId,
    required bool split,
  }) {
    final strings = context.strings;
    return AppPageBody.list(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pagePadding,
            0,
            AppTheme.pagePadding,
            AppTheme.spaceXs,
          ),
          child: Align(
            alignment: Alignment.centerRight,
            child: AppIconButton(
              icon: Icons.settings_outlined,
              tooltip: strings.settingsTitle,
              onPressed: () => _openSettings(context),
            ),
          ),
        ),
        if (personae.isEmpty)
          AppPageGutter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppTheme.spaceSm,
              ),
              child: AppText(
                strings.noPersonaYet,
                role: AppTextRole.caption,
              ),
            ),
          )
        else
          AppListTileStack(
            tiles: [
              for (final persona in personae)
                AppListTile(
                  title: persona.name,
                  subtitle: personaSubtitle(strings, persona, activeId),
                  leading: AppPersonAvatar(
                    size: 40,
                    semanticLabel: persona.name,
                  ),
                  selected: persona.id == selectedId,
                  trailing: split ? null : const AppForwardIcon(),
                  onTap: () => _openPersona(context, persona, split: split),
                  onLongPress: persona.isDefault
                      ? null
                      : () => confirmAndDeletePersona(context, persona),
                ),
            ],
          ),
        const SizedBox(height: AppTheme.spaceMd),
        AppPageGutter(
          child: AppButton(
            label: strings.addPersona,
            variant: AppButtonVariant.secondary,
            expanded: true,
            onPressed: () => _addPersona(context),
          ),
        ),
      ],
    );
  }
}
