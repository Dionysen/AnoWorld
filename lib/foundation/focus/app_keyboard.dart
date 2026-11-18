import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Soft-keyboard helpers (dismiss on blur, tap-outside).
abstract final class AppKeyboard {
  static void dismiss() {
    final current = FocusManager.instance.primaryFocus;
    if (current != null && current.hasFocus) {
      current.unfocus();
    }
    _hideIme();
  }

  static void hideImeIfNoTextFocus() {
    if (!isTextInputFocused) {
      _hideIme();
    }
  }

  /// True when an editable text field currently has primary focus.
  ///
  /// [FocusNode.context.widget] is usually a [Focus], not [EditableText], so
  /// we walk for [RenderEditable] instead of comparing widget types.
  static bool get isTextInputFocused {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null || !focus.hasFocus) return false;
    final ctx = focus.context;
    if (ctx == null) return false;
    if (ctx.widget is EditableText) return true;
    if (ctx.findAncestorWidgetOfExactType<EditableText>() != null) {
      return true;
    }
    return ctx.findAncestorRenderObjectOfType<RenderEditable>() != null;
  }

  static void showImeIfTextFocused() {
    if (isTextInputFocused) {
      _showIme();
    }
  }

  static void _hideIme() {
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  }

  static void _showIme() {
    SystemChannels.textInput.invokeMethod<void>('TextInput.show');
  }
}

/// Keeps the soft keyboard in sync with text focus: hide when nothing editable
/// is focused; ensure show when an [EditableText] gains focus (needed under
/// Android `adjustNothing`).
class AppKeyboardScope extends StatefulWidget {
  const AppKeyboardScope({super.key, required this.child});

  final Widget child;

  @override
  State<AppKeyboardScope> createState() => _AppKeyboardScopeState();
}

class _AppKeyboardScopeState extends State<AppKeyboardScope> {
  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (AppKeyboard.isTextInputFocused) {
        AppKeyboard.showImeIfTextFocused();
      } else {
        AppKeyboard.hideImeIfNoTextFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
