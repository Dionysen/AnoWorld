import 'package:flutter/material.dart';

/// Theme-backed on/off control for list rows and compact settings.
///
/// Draws the Material switch at three-quarter size (45×30 instead of the
/// default 60×40) so it stays quiet next to two-line row text. The whole row
/// remains tappable, so the smaller target is still easy to reach.
class AppSwitch extends StatelessWidget {
  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  static const Size _footprint = Size(45, 30);

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: _footprint,
      child: FittedBox(
        child: Switch(
          value: value,
          onChanged: onChanged,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}
