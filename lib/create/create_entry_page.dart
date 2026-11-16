import 'package:anoworld/foundation/widgets/app_empty_state.dart';
import 'package:anoworld/foundation/widgets/app_page.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:flutter/widgets.dart';

enum CreateEntryKind { characterCard, novel, stagedPrompts }

extension CreateEntryKindLabels on CreateEntryKind {
  String get title => switch (this) {
        CreateEntryKind.characterCard => '导入角色卡',
        CreateEntryKind.novel => '粘贴故事',
        CreateEntryKind.stagedPrompts => '分阶段提示词',
      };

  String get blurb => switch (this) {
        CreateEntryKind.characterCard =>
          '选择酒馆角色卡，确认摘取内容后生成短开场。',
        CreateEntryKind.novel => '贴一段剧情，拆成能玩的设定、角色与情节。',
        CreateEntryKind.stagedPrompts =>
          '按世界 → 人物 → 走向逐步写一两句，走到走向即可开玩。',
      };
}

/// Placeholder for one of the three UX creation paths.
class CreateEntryPage extends StatelessWidget {
  const CreateEntryPage({super.key, required this.kind});

  final CreateEntryKind kind;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: kind.title,
      onBack: () => Navigator.of(context).maybePop(),
      body: AppPageBody(
        children: [
          AppSectionHeader('创作入口'),
          AppText(kind.blurb, role: AppTextRole.body),
          const AppEmptyState(
            message: '这条创作路径马上就好',
            detail: '现在可以先打开已有作品，或新建一个空白作品。',
          ),
        ],
      ),
    );
  }
}
