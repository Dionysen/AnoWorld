import 'package:anoworld/foundation/widgets/app_bottom_nav_icon_capsule.dart';
import 'package:anoworld/home/create_assistant_bloom_shell.dart';
import 'package:anoworld/home/create_assistant_panel.dart';
import 'package:flutter/material.dart';

/// Story-flow chrome: assistant blooms from the bottom-right anchor.
class CreateAssistantHost extends StatefulWidget {
  const CreateAssistantHost({super.key, required this.child});

  final Widget child;

  @override
  State<CreateAssistantHost> createState() => CreateAssistantHostState();
}

class CreateAssistantHostState extends State<CreateAssistantHost>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 520);

  late final AnimationController _bloom = AnimationController(
    vsync: this,
    duration: _duration,
  );

  bool _open = false;

  bool get _showBloom => _open || _bloom.isAnimating;

  Future<void> _openBloom() async {
    if (_open) return;
    setState(() => _open = true);
    await _bloom.forward();
  }

  Future<void> _closeBloom() async {
    if (!_open && _bloom.value == 0) return;
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

  @override
  void dispose() {
    _bloom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final anchorBottom = AppBottomChromeMetrics.assistantButtonBottom(context);
    final anchorRight = AppBottomChromeMetrics.assistantButtonRight;
    final showCollapsedButton = !_showBloom;

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        widget.child,
        if (_showBloom) ...[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeBloom,
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
            child: AppBottomNavIconCapsule(
              icon: Icons.auto_awesome_outlined,
              selectedIcon: Icons.auto_awesome,
              tooltip: '创作助手',
              onPressed: () {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _openBloom();
                });
              },
            ),
          ),
      ],
    );
  }
}
