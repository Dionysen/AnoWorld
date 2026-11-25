import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../frame/immersive_frame.dart';
import '../l10n/app_localizations.dart';
import '../layout/pane_detail_scope.dart';
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
/// With [overlayTitle], the software title is transparent and stacked on [body]
/// (and [body] paints up under the window chrome) so a hero can run edge-to-edge
/// while back / title / actions stay in the software title layer.
///
/// Embedded in a master-detail detail pane ([PaneDetailScope]): chrome band and
/// back button are dropped — the host shell already owns the window chrome and
/// the list beside the pane is the way back.
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.body,
    this.titleWidget,
    this.actions = const [],
    this.onBack,
    this.showTitle = true,
    this.overlayTitle = false,
    this.overlayTitleFill,
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

  /// When true (and [showTitle]), draw the software title as a transparent
  /// overlay on [body] instead of a solid band that pushes [body] down.
  ///
  /// [body] is also extended upward under the window/status chrome so a hero
  /// cover can paint to the window top. Controls stay in the software title
  /// row — never in the window chrome.
  final bool overlayTitle;

  /// Optional fill behind the overlay software title (e.g. surface fading in
  /// as a hero collapses). Ignored unless [overlayTitle] is true.
  final Color? overlayTitleFill;

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
    // Inside a split detail pane the shell already consumed the chrome band and
    // the safe-area insets. The pane's bottom route is the selected item, and
    // the list beside it replaces the back button; pages pushed on top of it
    // inside the column still need their own way back.
    final inDetailPane = PaneDetailScope.isActive(context);
    final paneRoot =
        inDetailPane && (ModalRoute.of(context)?.isFirst ?? true);
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
              final chromeHeight = inDetailPane
                  ? 0.0
                  : math.min(metrics.barHeight, constraints.maxHeight);
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
              final useOverlayTitle = overlayTitle && showSoftwareTitle;
              final showBack =
                  showSoftwareTitle &&
                  onBack != null &&
                  !paneRoot &&
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

              Widget titleBar = SizedBox(
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
              );
              if (useOverlayTitle && overlayTitleFill != null) {
                titleBar = ColoredBox(color: overlayTitleFill!, child: titleBar);
              }

              final bodyPad = inDetailPane
                  ? EdgeInsets.zero
                  : EdgeInsets.only(
                      left: media.padding.left,
                      right: media.padding.right,
                    );
              // Bottom inset stays in MediaQuery so floating chrome
              // (capsule nav) can overlay while scroll bodies pad themselves.
              final paddedBody = Padding(padding: bodyPad, child: body);

              return Column(
                children: [
                  if (chromeHeight > 0)
                    // Transparent when a backdrop is given, or when the body
                    // paints under chrome via [overlayTitle].
                    ColoredBox(
                      color: backdrop == null && !useOverlayTitle
                          ? barColor
                          : Colors.transparent,
                      child: SizedBox(
                        height: chromeHeight,
                        width: double.infinity,
                      ),
                    ),
                  if (showSoftwareTitle && !useOverlayTitle)
                    ColoredBox(color: barColor, child: titleBar),
                  Expanded(
                    child: useOverlayTitle
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              // Extend under the window chrome so a hero cover
                              // can reach the window top / status bar.
                              Positioned(
                                top: -chromeHeight,
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: paddedBody,
                              ),
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                child: titleBar,
                              ),
                            ],
                          )
                        : paddedBody,
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
