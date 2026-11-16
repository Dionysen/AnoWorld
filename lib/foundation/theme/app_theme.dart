import 'package:flutter/material.dart';

/// Theme entry. Visual decisions are added here as pages need them.
abstract final class AppTheme {
  static ThemeData get data => ThemeData(useMaterial3: true);
}
