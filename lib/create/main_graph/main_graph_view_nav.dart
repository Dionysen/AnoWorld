import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/foundation/widgets/app_nav_shell.dart';
import 'package:flutter/material.dart';

/// Bottom destinations for canvas vs card (focus) camera on [MainGraphPage].
List<AppNavItem> mainGraphViewNavItems(AppStrings strings) => [
  AppNavItem(
    id: 'canvas',
    label: strings.mainGraphCanvas,
    icon: Icons.account_tree_outlined,
    selectedIcon: Icons.account_tree,
  ),
  AppNavItem(
    id: 'card',
    label: strings.mainGraphCard,
    icon: Icons.crop_portrait_outlined,
    selectedIcon: Icons.crop_portrait,
  ),
];
