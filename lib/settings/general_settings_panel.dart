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
    if (!kDebugMode) {
      return const AppPageGutter(
        child: AppSectionHeader(
          '通用',
          subtitle: '这里还没有可改的选项',
        ),
      );
    }

    return AppPageGutter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSectionHeader('通用'),
          AppListTile(
            title: '高级',
            subtitle: '诊断日志等开发选项',
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