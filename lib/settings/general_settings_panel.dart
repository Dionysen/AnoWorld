import 'package:anoworld/foundation/widgets/app_empty_state.dart';
import 'package:anoworld/foundation/widgets/app_page_gutter.dart';
import 'package:flutter/material.dart';

/// General settings section (placeholder until more global prefs land).
class GeneralSettingsPanel extends StatelessWidget {
  const GeneralSettingsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppPageGutter(
      child: AppEmptyState(
        message: '这里还没有可改的选项',
      ),
    );
  }
}