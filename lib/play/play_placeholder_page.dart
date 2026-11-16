import 'package:anoworld/domain/models/project.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:flutter/widgets.dart';

/// Runtime shell placeholder until VN/chat players land.
class PlayPlaceholderPage extends StatelessWidget {
  const PlayPlaceholderPage({super.key, required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final start = project.main.nodeById(project.main.startNodeId);
    final firstBeatId =
        start == null || start.beatIds.isEmpty ? null : start.beatIds.first;
    final firstBeat =
        firstBeatId == null ? null : project.main.beatById(firstBeatId);
    final firstLine =
        firstBeat == null || firstBeat.lines.isEmpty
            ? null
            : firstBeat.lines.first;

    return AppPage(
      title: '游玩 · ${project.meta.title}',
      onBack: () => Navigator.of(context).maybePop(),
      body: AppPageBody(
        children: [
          const AppSectionHeader('开场预览'),
          AppText(
            start == null ? '缺少开场情节' : start.title,
            role: AppTextRole.subtitle,
          ),
          const SizedBox(height: AppTheme.spaceSm),
          AppText(
            firstLine?.text ?? '（尚无对白）',
            role: AppTextRole.body,
          ),
          const SizedBox(height: AppTheme.spaceLg),
          const AppText(
            '完整 VN / 聊天播放器下一阶段接入。',
            role: AppTextRole.caption,
          ),
        ],
      ),
    );
  }
}
