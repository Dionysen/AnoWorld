import 'package:anoworld/foundation/widgets/app_nav_shell.dart';
import 'package:flutter/material.dart';

enum HomeTab { saves, works }

const List<AppNavItem> homeNavItems = [
  AppNavItem(
    id: 'saves',
    label: '存档',
    icon: Icons.history_outlined,
    selectedIcon: Icons.history,
  ),
  AppNavItem(
    id: 'works',
    label: '故事',
    icon: Icons.menu_book_outlined,
    selectedIcon: Icons.menu_book,
  ),
];

extension HomeTabNav on HomeTab {
  int get tabIndex => HomeTab.values.indexOf(this);

  static HomeTab fromIndex(int index) {
    if (index < 0 || index >= HomeTab.values.length) return HomeTab.saves;
    return HomeTab.values[index];
  }
}
