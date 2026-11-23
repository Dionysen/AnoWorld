import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../frame/immersive_frame.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'app_circle_button.dart';
import 'app_text.dart';

/// Page shell. Business screens compose this instead of a scaffold or app bar.
///
/// Layout (top → bottom):
/// 1. **Window / status chrome** — same fill as the page background. Desktop:
///    empty drag band for traffic lights / window buttons (**no** app widgets
///    or text). Mobile: status-bar inset only.
/// 2. **Software title bar** (when [showTitle]) — back, title, [actions].
/// 3. [body]
///
/// Home hubs pass [showTitle] false and put search / toolbars in [body].
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.body,
    this.titleWidget,
    this.actions = const [],
    this.onBack,
    this.showTitle = true,
    this.background,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
  });

  final String title;

  /// When set, replaces the plain [title] text (e.g. slide/fade switcher).
  final Widget? titleWidget;
  final Widget body;

  /// Trailing controls in the software title bar (same row as the title).
  final List<Widget> actions;
  final VoidCallback? onBack;

  /// When false, keeps window/status chrome but hides the software title bar
  /// (e.g. home tabs put search + toolbar in [body]).
  final bool showTitle;

  /// Full-bleed backdrop painted behind the window/status chrome and [body].
  ///
  /// When set, the chrome band turns transparent so the backdrop runs up into
  /// the desktop title band / mobile status area (immersive stage). Chrome
  /// height, window buttons and [body] bounds stay exactly as before.
  final Widget? background;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  /// Insert [AppTheme.spaceSm] between action widgets.
  ///
  /// Existing bare [SizedBox] spacers in [actions] are dropped so callers can
  /// list controls without hand-spacing.
  static List<Widget> spacedActions(List<Widget> actions) {
    final items = actions.where((w) => w is! SizedBox).toList(growable: false);
    if (items.length <= 1) return items;
    final out = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) out.add(const SizedBox(width: AppTheme.spaceSm));
      out.add(items[i]);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final metrics = ImmersiveScope.metricsOf(context);
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final barColor =
        theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface;
    final backdrop = background;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation:
          floatingActionButtonLocation ??
              FloatingActionButtonLocation.endFloat,
      body: Stack(
        fit: StackFit.expand,
        children: [
          ?backdrop,
          LayoutBuilder(
            builder: (context, constraints) {
              // Window/status chrome only — never place app title / back /
              // actions here (desktop custom title bar is background + OS
              // controls).
              final chromeHeight = math.min(
                metrics.barHeight,
                constraints.maxHeight,
              );
              final belowChrome = math.max(
                0.0,
                constraints.maxHeight - chromeHeight,
              );
              final titleBarHeight = math.min(
                AppTheme.pageTitleBarHeight,
                belowChrome,
              );
              final showSoftwareTitle =
                  showTitle &&
                  titleBarHeight >= 28 &&
                  constraints.maxWidth >= 72;
              final showBack =
                  showSoftwareTitle &&
                  onBack != null &&
                  constraints.maxWidth >= 72;
              final showTitleText =
                  showSoftwareTitle &&
                  constraints.maxWidth >= (showBack ? 96 : 48);
              final showActions =
                  showSoftwareTitle &&
                  actions.isNotEmpty &&
                  constraints.maxWidth >= 120;

              final titleLeftPad = showBack
                  ? AppTheme.titleChromePadding
                  : AppTheme.pagePadding;
              final titleRightPad = showActions
                  ? AppTheme.titleChromePadding
                  : AppTheme.pagePadding;

              return Column(
                children: [
                  if (chromeHeight > 0)
                    // Transparent when a backdrop is given: the image runs up
                    // into the title band / status bar, layout is untouched.
                    ColoredBox(
                      color: backdrop == null ? barColor : Colors.transparent,
                      child: SizedBox(
                        height: chromeHeight,
                        width: double.infinity,
                      ),
                    ),
                  if (showSoftwareTitle)
                    ColoredBox(
                      color: barColor,
                      child: SizedBox(
                        height: titleBarHeight,
                        width: double.infinity,
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: titleLeftPad,
                            right: titleRightPad,
                          ),
                          child: Row(
                            children: [
                              if (showBack)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    right: AppTheme.spaceSm,
                                  ),
                                  child: AppCircleButton(
                                    icon: Icons.arrow_back,
                                    tooltip: context.ui.back,
                                    onPressed: onBack,
                                    size: 32,
                                    iconSize: 18,
                                  ),
                                ),
                              if (showTitleText)
                                Expanded(
                                  child:
                                      titleWidget ??
                                      AppText(
                                        title,
                                        role: AppTextRole.subtitle,
                                        maxLines: 1,
                                      ),
                                )
                              else
                                const Spacer(),
                              if (showActions) ...spacedActions(actions),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      // Bottom inset stays in MediaQuery so floating chrome
                      // (capsule nav) can overlay while scroll bodies pad
                      // themselves.
                      padding: EdgeInsets.only(
                        left: media.padding.left,
                        right: media.padding.right,
                      ),
                      child: body,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Standard padded scrollable page body.
class AppPageBody extends StatelessWidget {
  /// Vertical-only inset so [AppListTile] / [AppSlider] rows span content width.
  static const EdgeInsets listPadding =
      EdgeInsets.symmetric(vertical: AppTheme.pagePadding);

  const AppPageBody({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.all(AppTheme.pagePadding),
  });

  /// Flat list/settings body: same as [AppPageBody] with [listPadding].
  const AppPageBody.list({
    super.key,
    required this.children,
  }) : padding = listPadding;

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final mediaBottom = MediaQuery.paddingOf(context).bottom;
    final keyboardBottom = MediaQuery.viewInsetsOf(context).bottom;
    return LayoutBuilder(
      builder: (context, constraints) {
        final resolved = padding.resolve(Directionality.of(context));
        return SingleChildScrollView(
          padding: resolved.copyWith(
            bottom: resolved.bottom + mediaBottom + keyboardBottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        );
      },
    );
  }
}

/// Lazily built flat list body for long collections.
///
/// Same padding as [AppPageBody.list], but rows are laid out on demand so a
/// large library does not pay a full build/layout pass on every tab switch.
/// [header] widgets are still built eagerly (they sit at the top).
class AppPageLazyList extends StatelessWidget {
  const AppPageLazyList({
    super.key,
    this.header = const <Widget>[],
    required this.itemCount,
    required this.itemBuilder,
    this.padding = AppPageBody.listPadding,
  });

  final List<Widget> header;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final mediaBottom = MediaQuery.paddingOf(context).bottom;
    final keyboardBottom = MediaQuery.viewInsetsOf(context).bottom;
    final resolved = padding.resolve(Directionality.of(context));
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: resolved.copyWith(
            bottom: resolved.bottom + mediaBottom + keyboardBottom,
          ),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index < header.length) return header[index];
                return itemBuilder(context, index - header.length);
              },
              childCount: header.length + itemCount,
            ),
          ),
        ),
      ],
    );
  }
}
