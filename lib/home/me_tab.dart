import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/foundation/layout/app_layout.dart';
import 'package:anoworld/foundation/persona/user_persona.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_detail_pane.dart';
import 'package:anoworld/foundation/widgets/app_disclosure_icon.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_master_detail.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_page_gutter.dart';
import 'package:anoworld/foundation/widgets/app_page_route.dart';
import 'package:anoworld/foundation/widgets/app_person_avatar.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/home/home_tab_back.dart';
import 'package:anoworld/settings/persona_delete.dart';
import 'package:anoworld/settings/persona_editor_page.dart';
import 'package:anoworld/settings/persona_labels.dart';
import 'package:anoworld/settings/persona_settings_page.dart';
import 'package:anoworld/settings/settings_display_labels.dart';
import 'package:anoworld/settings/settings_section_view.dart';
import 'package:anoworld/settings/settings_sections.dart';
import 'package:flutter/material.dart';

/// Profile tab: the settings hub.
///
/// Identities and every settings section are listed flat in one column; each
/// opens the same page a narrow window pushes — pushed on narrow windows, in
/// the detail column on wide ones.
class MeTab extends StatefulWidget {
  const MeTab({super.key, this.onChromeChanged});

  /// Home chrome (back handling / assistant) may need a rebuild.
  final VoidCallback? onChromeChanged;

  @override
  State<MeTab> createState() => MeTabState();
}

class MeTabState extends State<MeTab> implements HomeTabBack {
  /// Page shown in the wide-window detail column; null shows the empty hint.
  _MePane? _pane;

  /// Stack of the detail column (the page, then whatever it opens).
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

  /// An identity deleted elsewhere drops out of the pane instead of lingering.
  _MePane? _resolvedPane(List<UserPersona> personae) {
    final pane = _pane;
    if (pane is _PersonaPane && !personae.any((p) => p.id == pane.id)) {
      return null;
    }
    return pane;
  }

  @override
  bool get canGoBack => _detailPane.canPop || _pane != null;

  @override
  bool handleSystemBack() {
    if (_detailPane.pop()) return true;
    if (_pane == null) return false;
    setState(() => _pane = null);
    return true;
  }

  void _select(_MePane pane) {
    setState(() => _pane = pane);
    widget.onChromeChanged?.call();
  }

  Future<void> _addPersona(BuildContext context) {
    return pushAppSlide(context, const PersonaEditorPage());
  }

  /// Wide windows preview in the detail column; narrow ones push the page.
  void _openPersona(
    BuildContext context,
    UserPersona persona, {
    required bool split,
  }) {
    if (split) {
      _select(_PersonaPane(persona.id));
      return;
    }
    pushAppSlide(context, const PersonaSettingsPage());
  }

  Future<void> _openSection(
    BuildContext context,
    SettingsSection section, {
    required bool split,
  }) async {
    if (split) {
      _select(_SettingsPane(section));
      return;
    }
    await pushAppSlide(context, SettingsSectionView(section: section));
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
            final pane = _resolvedPane(personae);
            return AppMasterDetail(
              primary: _masterPane(
                context,
                personae: personae,
                activeId: controller.activePersona?.id,
                pane: pane,
                split: split,
              ),
              detail: _detailFor(pane),
              emptyLabel: strings.selectMeHint,
              paneWidth: AppScope.paneWidthOf(context),
              detailController: _detailPane,
            );
          },
        );
      },
    );
  }

  Widget? _detailFor(_MePane? pane) => switch (pane) {
    null => null,
    _PersonaPane(:final id) => PersonaSettingsPage(
      key: ValueKey<String>('persona-pane-$id'),
    ),
    _SettingsPane(:final section) => SettingsSectionView(
      key: ValueKey<String>('settings-pane-${section.id}'),
      section: section,
    ),
  };

  Widget _masterPane(
    BuildContext context, {
    required List<UserPersona> personae,
    required String? activeId,
    required _MePane? pane,
    required bool split,
  }) {
    final strings = context.strings;
    return AppPageBody.list(
      children: [
        AppSectionHeader(strings.personaTitle, gutter: true),
        if (personae.isEmpty)
          AppPageGutter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
              child: AppText(strings.noPersonaYet, role: AppTextRole.caption),
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
                  selected: pane is _PersonaPane && pane.id == persona.id,
                  trailing: split ? null : const AppForwardIcon(),
                  onTap: () => _openPersona(context, persona, split: split),
                  onLongPress: persona.isDefault
                      ? null
                      : () => confirmAndDeletePersona(context, persona),
                ),
            ],
          ),
        const SizedBox(height: AppTheme.spaceSm),
        AppPageGutter(
          child: AppButton(
            label: strings.addPersona,
            variant: AppButtonVariant.secondary,
            expanded: true,
            onPressed: () => _addPersona(context),
          ),
        ),
        const SizedBox(height: AppTheme.spaceLg),
        AppSectionHeader(strings.settingsTitle, gutter: true),
        AppListTileStack(
          tiles: [
            for (final section in SettingsSection.values)
              AppListTile(
                title: settingsSectionLabel(strings, section),
                icon: section.icon,
                selected: pane is _SettingsPane && pane.section == section,
                trailing: split ? null : const AppForwardIcon(),
                onTap: () => _openSection(context, section, split: split),
              ),
          ],
        ),
      ],
    );
  }
}

/// What the 「我」detail column shows; the flat list drives it.
sealed class _MePane {
  const _MePane();
}

final class _PersonaPane extends _MePane {
  const _PersonaPane(this.id);

  final String id;
}

final class _SettingsPane extends _MePane {
  const _SettingsPane(this.section);

  final SettingsSection section;
}
