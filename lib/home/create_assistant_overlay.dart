import 'package:anoworld/home/create_assistant_controller.dart';
import 'package:anoworld/home/create_assistant_host.dart';
import 'package:flutter/material.dart';

/// Inserts [CreateAssistantHost] into the root [Overlay] and keeps it on top.
class CreateAssistantOverlayScope extends StatefulWidget {
  const CreateAssistantOverlayScope({
    super.key,
    required this.controller,
    required this.child,
  });

  final CreateAssistantController controller;
  final Widget child;

  @override
  State<CreateAssistantOverlayScope> createState() =>
      CreateAssistantOverlayScopeState();
}

class CreateAssistantOverlayScopeState extends State<CreateAssistantOverlayScope> {
  OverlayEntry? _entry;
  final GlobalKey _hostKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureEntry());
  }

  @override
  void dispose() {
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  OverlayState? get _overlay {
    if (!mounted) return null;
    return Overlay.maybeOf(context, rootOverlay: true);
  }

  void _ensureEntry() {
    if (!mounted || _entry != null) return;
    final overlay = _overlay;
    if (overlay == null) return;
    _entry = OverlayEntry(
      builder: (context) => CreateAssistantHost(
        key: _hostKey,
        controller: widget.controller,
      ),
    );
    overlay.insert(_entry!);
  }

  /// Call after navigator push/pop so the FAB stays above the new route.
  void bringToFront() {
    final entry = _entry;
    final overlay = _overlay;
    if (overlay == null) return;
    if (entry == null) {
      _ensureEntry();
      return;
    }
    entry.remove();
    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
