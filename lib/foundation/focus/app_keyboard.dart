import 'package:flutter/material.dart';

/// Soft-keyboard helpers aligned with NativeTavern: only [unfocus], never
/// force [TextInput.hide]/show (that races the IME under Android).
abstract final class AppKeyboard {
  /// Drops text focus so the platform can hide the IME on its own.
  static void dismiss() {
    FocusManager.instance.primaryFocus?.unfocus();
  }
}
