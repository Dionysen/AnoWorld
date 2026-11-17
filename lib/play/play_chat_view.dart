import 'package:anoworld/app/app_scope.dart';
import 'package:anoworld/domain/settings/chat_ui_settings.dart';
import 'package:anoworld/foundation/theme/app_chat_chrome.dart';
import 'package:anoworld/foundation/theme/app_chat_colors.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_chat_bubble.dart';
import 'package:anoworld/foundation/widgets/app_chat_composer.dart';
import 'package:anoworld/foundation/widgets/app_shaped_avatar.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/play/play_chat_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// NativeTavern-like chat: bubbles + in-list reply chips + floating composer.
class PlayChatView extends StatefulWidget {
  const PlayChatView({
    super.key,
    required this.messages,
    required this.replyChoices,
    required this.isGenerating,
    required this.title,
    required this.onSend,
    required this.onPickReply,
    required this.onPickModel,
    required this.onOpenSettings,
    this.inputLocked = false,
    this.onRefreshChoices,
    this.onStop,
  });

  final List<PlayChatMessage> messages;
  final List<String> replyChoices;
  final bool isGenerating;
  final String title;
  final ValueChanged<String> onSend;
  final ValueChanged<String> onPickReply;
  final VoidCallback onPickModel;
  final VoidCallback onOpenSettings;

  /// Blocks send / reply chips without showing the typing bubble.
  final bool inputLocked;
  final VoidCallback? onRefreshChoices;
  final VoidCallback? onStop;

  @override
  State<PlayChatView> createState() => _PlayChatViewState();
}

class _PlayChatViewState extends State<PlayChatView> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _composerKey = GlobalKey();
  double _bottomChrome = 120;
  bool _pinnedToBottom = true;
  bool _showJump = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureChrome());
  }

  @override
  void didUpdateWidget(covariant PlayChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length != oldWidget.messages.length ||
        widget.isGenerating != oldWidget.isGenerating ||
        widget.replyChoices.length != oldWidget.replyChoices.length ||
        widget.inputLocked != oldWidget.inputLocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _measureChrome();
        if (_pinnedToBottom) _scrollToEnd();
      });
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _measureChrome() {
    final box = _composerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final h = box.size.height;
    if ((h - _bottomChrome).abs() > 1) {
      setState(() => _bottomChrome = h);
      if (_pinnedToBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
      }
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    final distance = pos.maxScrollExtent - pos.pixels;
    final pinned = distance <= 160;
    final showJump = distance > 160 &&
        pos.userScrollDirection == ScrollDirection.reverse;
    if (pinned != _pinnedToBottom || showJump != _showJump) {
      setState(() {
        _pinnedToBottom = pinned;
        _showJump = showJump;
      });
    }
  }

  void _scrollToEnd({bool animate = true}) {
    if (!_scroll.hasClients) return;
    final target = _scroll.position.maxScrollExtent;
    if (animate) {
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    } else {
      _scroll.jumpTo(target);
    }
  }

  bool get _blocked => widget.isGenerating || widget.inputLocked;

  bool get _showChoices =>
      widget.replyChoices.isNotEmpty && !widget.isGenerating;

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty || _blocked) return;
    _controller.clear();
    widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.settingsOf(context);
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return _buildShell(context, settings.chatUi);
      },
    );
  }

  Widget _buildShell(BuildContext context, ChatUiSettings chatUi) {
    final chat = AppChatColors.of(context);
    final empty = widget.messages.isEmpty &&
        !widget.isGenerating &&
        !_showChoices;

    return ColoredBox(
      color: chat.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width =
              constraints.maxWidth.clamp(0.0, AppChatChrome.contentMaxWidth);
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: width.isFinite ? width : AppChatChrome.contentMaxWidth,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: empty
                        ? _EmptyChat(title: widget.title)
                        : ListView.builder(
                            controller: _scroll,
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: ClampingScrollPhysics(),
                            ),
                            padding: EdgeInsets.fromLTRB(
                              16,
                              8,
                              16,
                              12 + _bottomChrome,
                            ),
                            itemCount: widget.messages.length +
                                (widget.isGenerating || _showChoices ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index < widget.messages.length) {
                                final msg = widget.messages[index];
                                return AppChatBubble(
                                  text: msg.text,
                                  role: msg.isUser
                                      ? AppChatBubbleRole.user
                                      : AppChatBubbleRole.character,
                                  avatarLabel: msg.avatarLabel,
                                  lineHeight: chatUi.lineHeight,
                                  paragraphSpacing: chatUi.paragraphSpacing,
                                );
                              }
                              if (widget.isGenerating) {
                                return const AppChatBubble(
                                  text: '',
                                  role: AppChatBubbleRole.character,
                                  isTyping: true,
                                  showAvatar: false,
                                );
                              }
                              return _ReplyChoicesBlock(
                                choices: widget.replyChoices,
                                blocked: _blocked,
                                onPick: widget.onPickReply,
                                onRefresh: widget.onRefreshChoices,
                              );
                            },
                          ),
                  ),
                  if (_showJump && !empty)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: _bottomChrome + 12,
                      child: Center(
                        child: Material(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          shape: const StadiumBorder(),
                          elevation: 2,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _pinnedToBottom = true;
                                _showJump = false;
                              });
                              _scrollToEnd();
                            },
                            customBorder: const StadiumBorder(),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              child: AppText('回到底部', role: AppTextRole.caption),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: KeyedSubtree(
                      key: _composerKey,
                      child: SafeArea(
                        top: false,
                        child: AppChatComposer(
                          controller: _controller,
                          isGenerating: widget.isGenerating,
                          enabled: !widget.inputLocked,
                          onSend: _handleSend,
                          onStop: widget.onStop,
                          leading: [
                            AppChatComposerIconButton(
                              icon: Icons.smart_toy_outlined,
                              tooltip: '选择模型',
                              onPressed: widget.onPickModel,
                            ),
                            AppChatComposerIconButton(
                              icon: Icons.settings_outlined,
                              tooltip: '聊天设置',
                              onPressed: widget.onOpenSettings,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ReplyChoicesBlock extends StatelessWidget {
  const _ReplyChoicesBlock({
    required this.choices,
    required this.blocked,
    required this.onPick,
    this.onRefresh,
  });

  final List<String> choices;
  final bool blocked;
  final ValueChanged<String> onPick;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.spaceSm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: AppText('回复选项', role: AppTextRole.caption),
              ),
              if (onRefresh != null)
                AppChatComposerIconButton(
                  icon: Icons.refresh_rounded,
                  tooltip: '换一批',
                  onPressed: blocked ? null : onRefresh,
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSm),
          for (var i = 0; i < choices.length; i++) ...[
            AppChatChrome.tappableMenuChip(
              context,
              onTap: blocked ? null : () => onPick(choices[i]),
              child: Text(
                choices[i],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: scheme.onSurface,
                ),
              ),
            ),
            if (i != choices.length - 1)
              const SizedBox(height: AppTheme.spaceSm),
          ],
        ],
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppShapedAvatar(
              width: 100,
              height: 100,
              backgroundColor: scheme.primary.withValues(alpha: 0.18),
              child: Icon(
                Icons.chat_bubble_outline,
                size: 40,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            AppText(title, role: AppTextRole.subtitle, maxLines: 2),
            const SizedBox(height: AppTheme.spaceSm),
            const AppText('开始对话', role: AppTextRole.caption),
          ],
        ),
      ),
    );
  }
}
