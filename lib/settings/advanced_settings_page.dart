import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/foundation/logging/app_log.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_page_gutter.dart';
import 'package:anoworld/foundation/widgets/app_page_route.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/settings/app_log_viewer_page.dart';
import 'package:flutter/material.dart';

/// Debug-only settings (not shown in release builds).
class AdvancedSettingsPage extends StatelessWidget {
  const AdvancedSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return AppPage(
      title: strings.advancedTitle,
      onBack: () => Navigator.of(context).maybePop(),
      body: AppPageGutter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSectionHeader(
              strings.diagnosticsSection,
              subtitle: strings.diagnosticsHint,
            ),
            ListenableBuilder(
              listenable: AppLog.instance,
              builder: (context, _) {
                final n = AppLog.instance.length;
                return AppListTile(
                  title: strings.diagnosticsLogTitle,
                  subtitle: n > 0 ? strings.logCount(n) : strings.logNone,
                  icon: Icons.article_outlined,
                  onTap: () {
                    pushAppSlide(context, const AppLogViewerPage());
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
