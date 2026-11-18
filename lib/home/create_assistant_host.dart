import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/widgets/app_bottom_nav_icon_capsule.dart';
import 'package:anoworld/home/create_assistant_panel.dart';
import 'package:flutter/material.dart';

/// Story-flow chrome: assistant anchored on the bottom-nav seam (absolute).
class CreateAssistantHost extends StatefulWidget {
  const CreateAssistantHost({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<CreateAssistantHost> createState() => CreateAssistantHostState();
}

class CreateAssistantHostState extends State<CreateAssistantHost> {
  final _panelKey = GlobalKey<CreateAssistantPanelState>();
  bool _open = false;

  void _toggle() {
    if (_open) {
      _panelKey.currentState?.dismiss();
      return;
    }
    setState(() => _open = true);
  }

  void _onDismissed() {
    if (!_open) return;
    setState(() => _open = false);
  }

  void _close() => _panelKey.currentState?.dismiss();

  @override
  Widget build(BuildContext context) {
    final panel = _open
        ? CreateAssistantPanel(
            key: _panelKey,
            onDismiss: _onDismissed,
          )
        : null;

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        widget.child,
        if (_open) ...[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
            ),
          ),
          Positioned(
            left: AppTheme.sheetInset,
            right: AppTheme.sheetInset,
            bottom: AppBottomChromeMetrics.dockedPanelBottom(context),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: panel,
            ),
          ),
        ],
        Positioned(
          right: AppBottomChromeMetrics.assistantButtonRight,
          bottom: AppBottomChromeMetrics.assistantButtonBottom(context),
          child: AppBottomNavIconCapsule(
            icon: Icons.auto_awesome_outlined,
            selectedIcon: Icons.auto_awesome,
            selected: _open,
            tooltip: '创作助手',
            onPressed: _toggle,
          ),
        ),
      ],
    );
  }
}