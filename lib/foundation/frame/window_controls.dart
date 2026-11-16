import 'package:flutter/material.dart';

abstract final class WindowControlMetrics {
  static const double buttonWidth = 46;
  static const double stripWidth = buttonWidth * 3;
}

class WindowControls extends StatelessWidget {
  const WindowControls({
    super.key,
    required this.maximized,
    required this.height,
    required this.onMinimize,
    required this.onMaximize,
    required this.onClose,
  });

  final bool maximized;
  final double height;
  final VoidCallback onMinimize;
  final VoidCallback onMaximize;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    return Material(
      type: MaterialType.transparency,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _WindowControlButton(
            icon: Icons.remove,
            label: 'Minimize',
            color: color,
            height: height,
            onPressed: onMinimize,
          ),
          _WindowControlButton(
            icon: maximized ? Icons.filter_none : Icons.crop_square,
            label: maximized ? 'Restore' : 'Maximize',
            color: color,
            height: height,
            onPressed: onMaximize,
          ),
          _WindowControlButton(
            icon: Icons.close,
            label: 'Close',
            color: color,
            height: height,
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

class _WindowControlButton extends StatelessWidget {
  const _WindowControlButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.height,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final double height;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: WindowControlMetrics.buttonWidth,
        height: height,
        child: InkWell(
          onTap: onPressed,
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}
