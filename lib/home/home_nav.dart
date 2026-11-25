import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/foundation/widgets/app_nav_shell.dart';
import 'package:flutter/material.dart';

enum HomeTab { sessions, stories, me }

/// Home destinations with labels in the current language.
List<AppNavItem> homeNavItems(AppStrings strings) => [
  AppNavItem(
    id: 'sessions',
    label: strings.tabSessions,
    icon: Icons.forum_outlined,
    selectedIcon: Icons.forum,
  ),
  AppNavItem(
    id: 'stories',
    label: strings.tabStories,
    icon: Icons.menu_book_outlined,
    selectedIcon: Icons.menu_book,
  ),
  AppNavItem(
    id: 'me',
    label: strings.tabMe,
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
