import 'package:flutter/material.dart';

import 'app_segmented.dart';
import 'app_underline_tabs.dart';

/// Pins [AppUnderlineTabs] above a [PageView] so tabs and pages stay in sync.
///
/// Tap a tab to animate the page; swipe a page to select its tab. Parent keeps
/// [value] as the source of truth (e.g. for title-bar actions that depend on
/// the active tab).
class AppUnderlineTabPager<T> extends StatefulWidget {
  const AppUnderlineTabPager({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    required this.pages,
  }) : assert(options.length == pages.length);

  final List<AppSegmentOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  final List<Widget> pages;

  static const _animDuration = Duration(milliseconds: 220);

  @override
  State<AppUnderlineTabPager<T>> createState() =>
      _AppUnderlineTabPagerState<T>();
}

class _AppUnderlineTabPagerState<T> extends State<AppUnderlineTabPager<T>> {
  late final PageController _controller;
  bool _syncingFromTab = false;

  int get _index {
    final i = widget.options.indexWhere((o) => o.value == widget.value);
    return i < 0 ? 0 : i;
  }

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: _index);
  }

  @override
  void didUpdateWidget(covariant AppUnderlineTabPager<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == oldWidget.value) return;
    final next = _index;
    if (!_controller.hasClients) return;
    final current = _controller.page?.round() ?? _controller.initialPage;
    if (current == next) return;
    _syncingFromTab = true;
    _controller
        .animateToPage(
          next,
          duration: AppUnderlineTabPager._animDuration,
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() {
          if (mounted) _syncingFromTab = false;
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTabSelected(T value) {
    if (value == widget.value) return;
    widget.onChanged(value);
  }

  void _onPageChanged(int index) {
    if (_syncingFromTab) return;
    if (index < 0 || index >= widget.options.length) return;
    final value = widget.options[index].value;
    if (value == widget.value) return;
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppUnderlineTabs<T>(
          options: widget.options,
          value: widget.value,
          onChanged: _onTabSelected,
        ),
        Expanded(
          child: PageView(
            controller: _controller,
            onPageChanged: _onPageChanged,
            children: widget.pages,
          ),
        ),
      ],
    );
  }
}
