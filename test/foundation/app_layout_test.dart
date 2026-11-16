import 'package:anoworld/foundation/layout/app_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compact below rail breakpoint', () {
    expect(AppLayout.useRail(599), isFalse);
    expect(chromeModeForWidth(400), AppChromeMode.compact);
  });

  test('expanded at and above rail breakpoint', () {
    expect(AppLayout.useRail(600), isTrue);
    expect(chromeModeForWidth(1280), AppChromeMode.expanded);
  });

  test('three pane needs secondary and enough width', () {
    expect(
      AppLayout.useThreePane(shellWidth: 900, hasSecondary: false),
      isFalse,
    );
    // Content after rail at 600px is below secondary+detail minimum.
    expect(
      AppLayout.useThreePane(shellWidth: 600, hasSecondary: true),
      isFalse,
    );
    expect(
      AppLayout.useThreePane(shellWidth: 1000, hasSecondary: true),
      isTrue,
    );
  });
}
