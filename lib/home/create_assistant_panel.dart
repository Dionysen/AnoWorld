import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/foundation/logging/app_log.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_chat_composer.dart';
import 'package:anoworld/foundation/widgets/app_docked_panel.dart';
import 'package:anoworld/foundation/widgets/app_empty_state.dart';
import 'package:anoworld/foundation/widgets/app_list_tile.dart';
import 'package:anoworld/foundation/widgets/app_page_gutter.dart';
import 'package:anoworld/foundation/widgets/app_select_field.dart';
import 'package:anoworld/foundation/widgets/app_sheet.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:flutter/material.dart';

/// Docked create-assistant shell (P1：占位对话，后续接 CreateAgentRunner).
class CreateAssistantPanel extends StatefulWidget {
  const CreateAssistantPanel({
    super.key,
    required this.onDismiss,
  });

  final VoidCallback onDismiss;

  @override
  State<CreateAssistantPanel> createState() => CreateAssistantPanelState();
}

class CreateAssistantPanelState extends State<CreateAssistantPanel> {
  final _composer = TextEditingController();
  final _panelKey = GlobalKey<AppDockedPanelState>();

  String? _projectId;
  String _projectTitle = '';
  final List<_AssistantLine> _lines = [];
  bool _loadingStories = false;

  Future<void> dismiss() => _panelKey.currentState?.dismiss() ?? Future.value();

  Future<void> _pickStory() async {
    setState(() => _loadingStories = true);
    try {
      final repo = AppScope.projectsOf(context);
      final list = await repo.listProjects();
      if (!mounted) return;
      setState(() => _loadingStories = false);
      if (list.isEmpty) {
        await showAppSheet<void>(
          context: context,
          builder: (ctx) => const Padding(
            padding: EdgeInsets.all(AppTheme.pagePadding),
            child: AppEmptyState(message: '还没有故事，先去故事页新建'),
          ),
        );
        return;
      }
      final picked = await showAppSheet<String>(
        context: context,
        size: AppSheetSize.half,
        builder: (sheetCtx) => AppPageGutter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppText('选择故事', role: AppTextRole.subtitle),
              const SizedBox(height: AppTheme.spaceSm),
              for (final p in list)
                AppListTile(
                  title: p.title,
                  onTap: () => Navigator.of(sheetCtx).pop(p.id),
                ),
            ],
          ),
        ),
      );
      if (picked == null || !mounted) return;
      final summary = list.firstWhere((p) => p.id == picked);
      setState(() {
        _projectId = summary.id;
        _projectTitle = summary.title;
      });
      AppLog.instance.info('创作助手选中故事：${summary.title}', tag: 'create.assistant');
    } catch (error, stack) {
      if (!mounted) return;
      setState(() => _loadingStories = false);
      AppLog.instance.error(
        '加载故事列表失败',
        tag: 'create.assistant',
        error: error,
        stackTrace: stack,
      );
    }
  }

  void _send() {
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    _composer.clear();
    setState(() {
      _lines.add(_AssistantLine(role: _LineRole.user, text: text));
      _lines.add(
        const _AssistantLine(
          role: _LineRole.assistant,
          text: '创作助手还在接入，暂时无法代写。你可以先在故事页里改设定与角色',
        ),
      );
    });
    AppLog.instance.info(
      '创作助手消息（${_projectId ?? '未选故事'}）',
      tag: 'create.assistant',
    );
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storyLabel =
        _projectTitle.trim().isEmpty ? '未选择' : _projectTitle.trim();

    return AppDockedPanel(
      key: _panelKey,
      heightFactor: 0.58,
      onDismiss: widget.onDismiss,
      header: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.pagePadding,
          0,
          AppTheme.pagePadding,
          AppTheme.spaceSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppText('创作助手', role: AppTextRole.subtitle),
            const SizedBox(height: AppTheme.spaceXs),
            const AppText(
              '选一个故事，再在这里说你想改什么',
              role: AppTextRole.caption,
            ),
            const SizedBox(height: AppTheme.spaceSm),
            AppSelectField(
              label: '当前故事',
              value: storyLabel,
              hint: '点选故事',
              onTap: _loadingStories ? null : _pickStory,
            ),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _lines.isEmpty
                ? const Center(
                    child: AppEmptyState(
                      message: '说说想补哪段设定或角色',
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.pagePadding,
                      vertical: AppTheme.spaceSm,
                    ),
                    itemCount: _lines.length,
                    itemBuilder: (context, index) {
                      final line = _lines[index];
                      final isUser = line.role == _LineRole.user;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
                        child: Align(
                          alignment: isUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.sizeOf(context).width * 0.82,
                            ),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: isUser
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                    : Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMd,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(AppTheme.spaceSm),
                                child: AppText(
                                  line.text,
                                  role: AppTextRole.body,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          AppChatComposer(
            controller: _composer,
            hintText: '想创作或整理什么…',
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

enum _LineRole { user, assistant }

class _AssistantLine {
  const _AssistantLine({required this.role, required this.text});

  final _LineRole role;
  final String text;
}