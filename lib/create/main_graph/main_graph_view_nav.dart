import 'package:anoworld/foundation/widgets/app_nav_shell.dart';
import 'package:flutter/material.dart';

/// Bottom destinations for canvas vs card (focus) camera on [MainGraphPage].
const List<AppNavItem> mainGraphViewNavItems = [
  AppNavItem(
    id: 'canvas',
    label: '画布',
    icon: Icons.account_tree_outlined,
    selectedIcon: Icons.account_tree,
  ),
  AppNavItem(
    id: 'card',
    label: '卡片',
    icon: Icons.crop_portrait_outlined,
    selectedIcon: Icons.crop_portrait,
  ),
];
