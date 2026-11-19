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
    setState(() => _open = true);
    AppLog.instance.info('创作助手展开', tag: 'create.assistant');
    await _bloom.forward();
  }

  Future<void> _closeBloom() async {
    if (!_open && _bloom.value == 0) return;
    AppLog.instance.info('创作助手收起', tag: 'create.assistant');
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
    if (!visible && !_showBloom) {
      // Keep State alive; paint nothing and pass all hits through.
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
      // A sheet / dialog sits above this overlay entry, so stay out of the
      // way: keep the panel mounted (draft + pending awaits survive) but stop
      // painting and hit-testing until the popup closes.
      offstage: widget.controller.modalOpen,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          if (_showBloom) ...[
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
                child: const CreateAssistantPanel(),
              ),
            ),
          ],
          if (showCollapsedButton)
            Positioned(
              right: anchorRight,
              bottom: anchorBottom,
              child: RepaintBoundary(
                child: AppBottomNavIconCapsule(
                  icon: Icons.auto_awesome_outlined,
                  selectedIcon: Icons.auto_awesome,
                  tooltip: '创作助手',
                  onPressed: _openBloom,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
