import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../frame/immersive_frame.dart';
import '../layout/app_layout.dart';
import '../theme/app_shapes.dart';
import '../theme/app_theme.dart';
import '../theme/app_ui_tokens.dart';
import 'app_press_scale.dart';

class AppNavItem {
  const AppNavItem({
    required this.id,
    required this.label,
    required this.icon,
    this.selectedIcon,
  });

  final String id;
  final String label;
  final IconData icon;
  final IconData? selectedIcon;
}

/// Extra capsule beside the main bottom nav (not a destination tab).
class AppBottomNavExtraCapsule {
  const AppBottomNavExtraCapsule({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selectedIcon,
    this.enabled = true,
    this.selected = false,
  });

  final IconData icon;
  final IconData? selectedIcon;
  final String label;

  /// When null or [enabled] is false, the control is greyed out.
  final VoidCallback? onPressed;
  final bool enabled;

  /// Toggle / panel-open highlight (independent of main destinations).
  final bool selected;
}

/// Adaptive app chrome: bottom bar (compact) or left rail + optional secondary
/// list pane (expanded / three-pane).
class AppNavShell extends StatelessWidget {
  const AppNavShell({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    this.secondary,
    this.secondaryWidth = AppLayout.secondaryPaneWidth,
    this.railTopInset,
    this.forceCompact = false,
    this.bottomNavExtra,
    this.bottomPanel,
    this.onBottomPanelBarrierTap,
  });

  final List<AppNavItem> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;

  /// Layer-2 pane (e.g. settings section list). Shown beside the rail when
  /// [AppLayout.useThreePane] is true; ignored in compact mode.
  final Widget? secondary;
  final double secondaryWidth;

  /// Top padding for the side rail. `null` uses the immersive title-band
  /// height (root chrome). Nested pages under [AppPage] should pass `0`.
  final double? railTopInset;

  /// When true, always use the floating capsule bottom nav (e.g. graph
  /// 画布/卡片 switch). Ignores width breakpoint / side rail.
  final bool forceCompact;

  /// Optional second capsule to the right of the main bar (compact mode only).
  final AppBottomNavExtraCapsule? bottomNavExtra;

  /// Optional panel docked above the bottom nav (compact mode only).
  /// Typically an [AppDockedPanel]; sits under the capsules in z-order.
  final Widget? bottomPanel;

  /// When [bottomPanel] is shown, a full-screen transparent barrier sits above
  /// [body] (under the panel and bottom nav). Taps are absorbed so the body
  /// does not receive them; [onBottomPanelBarrierTap] runs on tap (e.g. dismiss).
  final VoidCallback? onBottomPanelBarrierTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final mode = forceCompact
            ? AppChromeMode.compact
            : chromeModeForWidth(width);
        final threePane = AppLayout.useThreePane(
          shellWidth: width,
          hasSecondary: secondary != null,
        );

        if (mode.isCompact) {
          // Overlay the capsule so margins stay transparent over [body].
          final media = MediaQuery.of(context);
          const barClearance = AppLayout.bottomNavHeight +
              AppLayout.bottomNavBottomInset +
              AppTheme.spaceSm;
          return Stack(
            fit: StackFit.expand,
            children: [
              MediaQuery(
                data: media.copyWith(
                  padding: media.padding.copyWith(
                    bottom: media.padding.bottom + barClearance,
                  ),
                ),
                child: body,
              ),
              if (bottomPanel != null) ...[
                Positioned.fill(
                  child: GestureDetector(
                    key: const ValueKey('app_nav_bottom_panel_barrier'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onBottomPanelBarrierTap?.call(),
                  ),
                ),
                Positioned(
                  left: AppTheme.sheetInset,
                  right: AppTheme.sheetInset,
                  bottom: barClearance,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: bottomPanel,
                  ),
                ),
              ],
              Align(
                alignment: Alignment.bottomCenter,
                child: _BottomNav(
                  destinations: destinations,
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onDestinationSelected,
                  extra: bottomNavExtra,
                ),
              ),
            ],
          );
        }

        final metrics = ImmersiveScope.metricsOf(context);
        final topInset = railTopInset ?? metrics.barHeight;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SideRail(
              destinations: destinations,
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              topInset: topInset,
              extra: bottomNavExtra,
            ),
            VerticalDivider(
              width: AppLayout.paneDividerWidth,
              thickness: AppLayout.paneDividerWidth,
              color: theme.dividerColor,
            ),
            if (threePane && secondary != null) ...[
              SizedBox(
                width: secondaryWidth,
                child: secondary,
              ),
              VerticalDivider(
                width: AppLayout.paneDividerWidth,
                thickness: AppLayout.paneDividerWidth,
                color: theme.dividerColor,
              ),
            ],
            Expanded(child: body),
          ],
        );
      },
    );
  }
}

/// Vertical section list for the secondary (layer-2) pane.
class AppNavSectionList extends StatelessWidget {
  const AppNavSectionList({
    super.key,
    required this.title,
    required this.items,
    required this.selectedId,
    required this.onSelected,
    this.topInset = 0,
  });

  final String title;
  final List<AppNavItem> items;
  final String selectedId;
  final ValueChanged<String> onSelected;
  final double topInset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: topInset),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spaceMd,
              AppTheme.spaceSm,
              AppTheme.spaceMd,
              AppTheme.spaceSm,
            ),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceSm,
                vertical: AppTheme.spaceXs,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final selected = item.id == selectedId;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spaceXs),
                  child: Material(
                    color: selected
                        ? theme.colorScheme.primary.withValues(alpha: 0.18)
                        : Colors.transparent,
                    shape: AppUiTokens.of(context).shape(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => onSelected(item.id),
                      customBorder: AppUiTokens.of(context).shape(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spaceMd,
                          vertical: AppTheme.spaceSm,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selected
                                  ? (item.selectedIcon ?? item.icon)
                                  : item.icon,
                              size: 18,
                              color: selected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: AppTheme.spaceSm),
                            Expanded(
                              child: Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: selected
                                      ? theme.colorScheme.onSurface
                                      : theme.colorScheme.onSurfaceVariant,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SideRail extends StatelessWidget {
  const _SideRail({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.topInset,
    this.extra,
  });

  final List<AppNavItem> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final double topInset;
  final AppBottomNavExtraCapsule? extra;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: AppLayout.railWidth,
      child: ColoredBox(
        color: theme.colorScheme.surface,
        child: Column(
          children: [
            SizedBox(height: topInset),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  vertical: AppTheme.spaceSm,
                ),
                itemCount: destinations.length,
                itemBuilder: (context, index) {
                  final item = destinations[index];
                  final selected = index == selectedIndex;
                  return _RailButton(
                    item: item,
                    selected: selected,
                    onTap: () => onDestinationSelected(index),
                  );
                },
              ),
            ),
            if (extra != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
                child: _RailButton(
                  item: AppNavItem(
                    id: 'extra',
                    label: extra!.label,
                    icon: extra!.icon,
                    selectedIcon: extra!.selectedIcon,
                  ),
                  selected: extra!.selected,
                  onTap: extra!.enabled ? extra!.onPressed : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AppNavItem item;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onTap != null;
    final color = !enabled
        ? theme.disabledColor
        : selected
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceXs,
        vertical: AppTheme.spaceXs,
      ),
      child: AppPressScale(
        enabled: enabled,
        child: Material(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.14)
              : Colors.transparent,
          shape: AppUiTokens.of(context).shape(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            customBorder: AppUiTokens.of(context).shape(),
            child: SizedBox(
              height: 64,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    selected ? (item.selectedIcon ?? item.icon) : item.icon,
                    size: 22,
                    color: color,
                  ),
                  const SizedBox(height: AppTheme.spaceXs),
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: color,
                      fontSize: 11,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.extra,
  });

  final List<AppNavItem> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final AppBottomNavExtraCapsule? extra;

  @override
  Widget build(BuildContext context) {
    // viewPadding: ignore body MediaQuery padding inflation from the shell.
    final bottom = MediaQuery.viewPaddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppLayout.bottomNavHorizontalInset,
        AppTheme.spaceSm,
        AppLayout.bottomNavHorizontalInset,
        bottom + AppLayout.bottomNavBottomInset,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: _BottomNavCapsule(
              child: Row(
                children: [
                  for (var i = 0; i < destinations.length; i++)
                    Expanded(
                      child: _BottomNavButton(
                        item: destinations[i],
                        selected: i == selectedIndex,
                        onTap: () => onDestinationSelected(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (extra != null) ...[
            const SizedBox(width: AppTheme.spaceSm),
            _BottomNavCapsule(
              width: 80,
              child: _BottomNavButton(
                item: AppNavItem(
                  id: 'extra',
                  label: extra!.label,
                  icon: extra!.icon,
                  selectedIcon: extra!.selectedIcon,
                ),
                selected: extra!.selected,
                enabled: extra!.enabled,
                onTap: extra!.enabled ? extra!.onPressed : null,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BottomNavCapsule extends StatelessWidget {
  const _BottomNavCapsule({required this.child, this.width});

  final Widget child;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const height = AppLayout.bottomNavHeight;
    final radius = height / 2;
    final isDark = theme.brightness == Brightness.dark;
    final capsule = AppShapes.continuous(
      radius: radius,
      side: BorderSide(
        color: theme.colorScheme.outline.withValues(alpha: isDark ? 0.45 : 0.35),
      ),
    );
    final glassFill = theme.colorScheme.surfaceContainerHighest.withValues(
      alpha: isDark ? 0.32 : 0.48,
    );

    final inner = SizedBox(
      height: height,
      width: width,
      child: child,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: capsule),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: AppLayout.bottomNavBlurSigma,
            sigmaY: AppLayout.bottomNavBlurSigma,
          ),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: glassFill,
              shape: capsule,
            ),
            child: Material(type: MaterialType.transparency, child: inner),
          ),
        ),
      ),
    );
  }
}

class _BottomNavButton extends StatelessWidget {
  const _BottomNavButton({
    required this.item,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final AppNavItem item;
  final bool selected;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = enabled && onTap != null;
    final color = !active
        ? theme.colorScheme.onSurface.withValues(alpha: 0.35)
        : selected
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant;
    final pill = AppShapes.continuous(radius: AppLayout.bottomNavHeight / 2);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceXs,
        vertical: AppTheme.spaceXs,
      ),
      child: AppPressScale(
        enabled: active,
        child: Material(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.14)
              : Colors.transparent,
          shape: pill,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: active ? onTap : null,
            customBorder: pill,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  active && selected
                      ? (item.selectedIcon ?? item.icon)
                      : item.icon,
                  size: 22,
                  color: color,
                ),
                const SizedBox(height: 2),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: color,
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
