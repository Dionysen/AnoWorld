import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/foundation/focus/app_keyboard.dart';
import 'package:anoworld/foundation/logging/app_log.dart';
import 'package:anoworld/foundation/widgets/app_bottom_nav_icon_capsule.dart';
import 'package:anoworld/home/create_assistant_bloom_shell.dart';
import 'package:anoworld/home/create_assistant_controller.dart';
import 'package:anoworld/home/create_assistant_panel.dart';
import 'package:flutter/material.dart';

/// Top-layer create-assistant chrome (FAB + bloom). Does not wrap page content.
///
/// Stays mounted under [MaterialApp.builder]; [CreateAssistantController.visible]
/// only toggles hit-testing / painting so the button never remounts on pushes.
class CreateAssistantHost extends StatefulWidget {
  const CreateAssistantHost({
    super.key,
    required this.controller,
  });

  final CreateAssistantController controller;

  @override
  State<CreateAssistantHost> createState() => CreateAssistantHostState();
}

class CreateAssistantHostState extends State<CreateAssistantHost>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 150);

  late final AnimationController _bloom = AnimationController(
    vsync: this,
    duration: _duration,
  );

  /// Set once the panel has been revealed. From then on the bloom (and the
  /// panel's in-flight turn) stays in the tree, hidden via [Offstage], so
  /// collapsing or leaving the story pages never cancels generation.
  bool _everOpened = false;
  bool _open = false;

  bool get _showBloom => _open || _bloom.isAnimating;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onVisibilityChanged);
  }

  @override
  void didUpdateWidget(covariant CreateAssistantHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onVisibilityChanged);
      widget.controller.addListener(_onVisibilityChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onVisibilityChanged);
    _bloom.dispose();
    super.dispose();
  }

  void _onVisibilityChanged() {
    if (!widget.controller.visible && _open) {
      _closeBloom();
    }
    if (mounted) setState(() {});
  }

  Future<void> _openBloom() async {
    if (_open || !widget.controller.visible) return;
    _everOpened = true;
    setState(() => _open = true);
    AppLog.instance.info('创作助手展开', tag: 'create.assistant');
    await _bloom.forward();
  }

  Future<void> _closeBloom() async {
    if (!_open && _bloom.value == 0) return;
    AppLog.instance.info('创作助手收起', tag: 'create.assistant');
    // The panel stays mounted (a running turn must finish), so drop focus by
    // hand or the IME would keep the closed composer lifted.
    AppKeyboard.dismiss();
    await _bloom.reverse();
    if (!mounted) return;
    setState(() => _open = false);
  }

  void _toggleAnchor() {
    if (_open) {
      _closeBloom();
    } else {
      _openBloom();
    }
  }

  void _dismissFromOutside() {
    if (!_open) return;
    AppLog.instance.info('创作助手点外侧收起', tag: 'create.assistant');
    _closeBloom();
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.controller.visible;
    if (!visible && !_everOpened) {
      // Nothing has been composed yet: keep State alive, paint nothing.
      return const SizedBox.shrink();
    }
    final keyboardPin = _showBloom
        ? 0.0
        : AppBottomChromeMetrics.keyboardPinOffset(context);
    final anchorBottom =
        AppBottomChromeMetrics.assistantButtonBottom(context) - keyboardPin;
    final anchorRight = AppBottomChromeMetrics.assistantButtonRight;
    final showCollapsedButton = visible && !_showBloom;

    return Offstage(
      // A sheet / dialog sits above this overlay entry, or the assistant is
      // parked on another section: keep the bloom mounted (draft + pending
      // awaits survive) but stop painting and hit-testing.
      offstage: !visible || widget.controller.modalOpen,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          // Hidden bloom stays in the tree so a running turn never aborts.
          if (_everOpened)
            Offstage(
              offstage: !_showBloom,
              child: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.none,
                children: [
                  // Always in the child list: swapping the list length would
                  // re-slot the bloom below and remount the panel.
                  Positioned.fill(
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (_) => _dismissFromOutside(),
                    ),
                  ),
                  Positioned(
                    right: anchorRight,
                    bottom: anchorBottom,
                    child: CreateAssistantBloomShell(
                      progress: _bloom,
                      onTapAnchor: _toggleAnchor,
                      child: CreateAssistantPanel(
                        controller: widget.controller,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (showCollapsedButton)
            Positioned(
              right: anchorRight,
              bottom: anchorBottom,
              child: RepaintBoundary(
                child: AppBottomNavIconCapsule(
                  icon: Icons.auto_awesome_outlined,
                  selectedIcon: Icons.auto_awesome,
                  tooltip: context.strings.assistantTitle,
                  onPressed: _openBloom,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
