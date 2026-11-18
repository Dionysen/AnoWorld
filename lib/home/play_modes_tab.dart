import 'package:anoworld/foundation/widgets/app_empty_state.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_page_gutter.dart';
import 'package:flutter/material.dart';

/// Play-style hub placeholder (third home tab).
class PlayModesTab extends StatelessWidget {
  const PlayModesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppPageBody.list(
      children: [
        AppPageGutter(
          child: AppEmptyState(
            message: '玩法还在整理',
            detail: '以后会在这里挑视觉小说、聊天等开场方式',
          ),
        ),
      ],
    );
  }
}