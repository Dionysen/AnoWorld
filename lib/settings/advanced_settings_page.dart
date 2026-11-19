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
    return AppPage(
      title: '高级',
      onBack: () => Navigator.of(context).maybePop(),
      body: AppPageGutter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppSectionHeader(
              '诊断',
              subtitle: '供开发排查，正式版不显示本页',
            ),
            ListenableBuilder(
              listenable: AppLog.instance,
              builder: (context, _) {
                final n = AppLog.instance.length;
                return AppListTile(
                  title: '诊断日志',
                  subtitle: n > 0 ? '共 $n 条' : '暂无记录',
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