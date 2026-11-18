import 'package:anoworld/foundation/widgets/app_nav_shell.dart';
import 'package:flutter/material.dart';

enum HomeTab { sessions, stories, playModes, me }

const List<AppNavItem> homeNavItems = [
  AppNavItem(
    id: 'sessions',
    label: '会话',
    icon: Icons.forum_outlined,
    selectedIcon: Icons.forum,
  ),
  AppNavItem(
    id: 'stories',
    label: '故事',
    icon: Icons.menu_book_outlined,
    selectedIcon: Icons.menu_book,
  ),
  AppNavItem(
    id: 'play_modes',
    label: '玩法',
    icon: Icons.extension_outlined,
    selectedIcon: Icons.extension,
  ),
  AppNavItem(
    id: 'me',
    label: '我',
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
  ),
];

extension HomeTabNav on HomeTab {
  int get tabIndex => HomeTab.values.indexOf(this);

  static HomeTab fromIndex(int index) {
    if (index < 0 || index >= HomeTab.values.length) {
      return HomeTab.sessions;
    }
    return HomeTab.values[index];
  }
}