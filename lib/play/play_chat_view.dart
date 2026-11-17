import 'package:anoworld/domain/models/main_story.dart';
import 'package:anoworld/foundation/theme/app_chat_chrome.dart';
import 'package:anoworld/foundation/theme/app_chat_colors.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_button.dart';
import 'package:anoworld/foundation/widgets/app_chat_bubble.dart';
import 'package:anoworld/foundation/widgets/app_chat_composer.dart';
import 'package:anoworld/foundation/widgets/app_shaped_avatar.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:anoworld/play/play_chat_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// NativeTavern-like chat stage for play (bubbles + floating composer).
class PlayChatView extends StatefulWidget {
  const PlayChatView({
    super.key,
    required this.messages,
    required this.choices,
    required this.isGenerating,
    required this.isEnded,
    required this.title,
    required this.onSend,
    required this.onChoose,
    required this.onRestart,
    this.onStop,
  });

  final List<PlayChatMessage> messages;
  final List<Choice> choices;
  final bool isGenerating;
  final bool isEnded;
  final String title;
  final ValueChanged<String> onSend;
  final ValueChanged<Choice> onChoose;
  final VoidCallback onRestart;
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
        widget.choices.length != oldWidget.choices.length) {
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

  void _scrollToEnd() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _handleSend() {
    final text = _controller.text;
    _controller.clear();
    widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    final chat = AppChatColors.of(context);
    final empty = widget.messages.isEmpty && !widget.isGenerating;

    return ColoredBox(
      color: chat.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.clamp(0.0, AppChatChrome.contentMaxWidth);
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
                              8 + _bottomChrome,
                            ),
                            itemCount: widget.messages.length +
                                (widget.isGenerating ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index >= widget.messages.length) {
                                return const AppChatBubble(
                                  text: '',
                                  isUser: false,
                                  avatarLabel: null,
                                  isTyping: true,
                                );
                              }
                              final msg = widget.messages[index];
                              return AppChatBubble(
                                text: msg.text,
                                isUser: msg.isUser,
                                avatarLabel: msg.avatarLabel,
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
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.isEnded) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const AppText(
                                    '本段结束',
                                    role: AppTextRole.subtitle,
                                  ),
                                  const SizedBox(height: AppTheme.spaceSm),
                                  AppButton(
                                    label: '重新开始',
                                    onPressed: widget.onRestart,
                                    expanded: true,
                                  ),
                                ],
                              ),
                            ),
                          ] else if (widget.choices.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (final choice in widget.choices)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: AppTheme.spaceSm,
                                      ),
                                      child: AppButton(
                                        label: choice.text,
                                        onPressed: widget.isGenerating
                                            ? null
                                            : () => widget.onChoose(choice),
                                        variant: AppButtonVariant.secondary,
                                        expanded: true,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                          SafeArea(
                            top: false,
                            child: AppChatComposer(
                              controller: _controller,
                              isGenerating: widget.isGenerating,
                              enabled: !widget.isEnded,
                              onSend: _handleSend,
                              onStop: widget.onStop,
                              leading: const [
                                AppChatComposerIconButton(
                                  icon: Icons.tune_rounded,
                                  tooltip: '更多',
                                  onPressed: null,
                                ),
                              ],
                            ),
                          ),
                        ],
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
                Icons.auto_stories_outlined,
                size: 40,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            AppText(
              title,
              role: AppTextRole.subtitle,
              maxLines: 2,
            ),
            const SizedBox(height: AppTheme.spaceSm),
            const AppText('开始对话', role: AppTextRole.caption),
          ],
        ),
      ),
    );
  }
}
